#!/usr/bin/env python3
"""
Requirements:
  pip install -r tools/requirements.txt

Usage:
  python3 tools/create_session_browser.py <username> <password> [totp_seed] [--append sessions.jsonl] [--headless]

Examples:
  # Output to terminal
  python3 tools/create_session_browser.py myusername mypassword TOTP_SECRET

  # Append to sessions.jsonl
  python3 tools/create_session_browser.py myusername mypassword TOTP_SECRET --append sessions.jsonl

  # Headless mode (may increase detection risk)
  python3 tools/create_session_browser.py myusername mypassword TOTP_SECRET --headless

Output:
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
"""

import asyncio
import json
import os
import shutil
import sys
import tempfile

import zendriver as zd
from zendriver import cdp
import pyotp


# Disable password manager to prevent the "Save password?" bubble from
# stealing focus during automated login.
_SEED_PREFS = {
    "credentials_enable_service": False,
    "profile": {"password_manager_enabled": False},
}
_BROWSER_ARGS = [
    "--password-store=basic",
    "--no-first-run",
    "--no-default-browser-check",
    "--disable-notifications",
]


def _log(*a):
    print(*a, file=sys.stderr, flush=True)


def _make_profile():
    """Create a temp Chrome profile with password manager disabled."""
    profile = tempfile.mkdtemp(prefix="xsess_")
    default = os.path.join(profile, "Default")
    os.makedirs(default)
    with open(os.path.join(default, "Preferences"), "w") as f:
        json.dump(_SEED_PREFS, f)
    return profile


def _extract_user_id(cookies_dict):
    """Extract numeric user ID from the twid cookie."""
    twid = cookies_dict.get("twid", "").strip('"')
    for prefix in ("u%3D", "u="):
        if prefix in twid:
            return twid.split(prefix)[1].split("&")[0].strip('"')
    return None


async def _check_login_error(tab):
    """Check if the login flow is showing an error (wrong password, etc.)."""
    try:
        return await tab.evaluate('''(() => {
            // Check role="alert" elements (X's standard error display)
            const alert = document.querySelector('[role="alert"]');
            if (alert) {
                const t = alert.textContent.trim();
                if (t.length > 0 && t.length < 200) return t;
            }
            // Check for common error strings in visible text
            for (const el of document.querySelectorAll('p, span, div')) {
                const t = el.textContent.trim();
                if (t.length > 5 && t.length < 150
                    && (t.includes('Wrong password')
                        || t.includes('incorrect')
                        || t.includes('Could not log you in')
                        || t.includes("can\\'t find")
                        || t.includes('cannot find')
                        || t.includes('suspended')
                        || t.includes('locked')
                        || t.includes('unusual login'))) {
                    return t;
                }
            }
            return '';
        })()''')
    except Exception:
        return ''


async def _click_continue(tab):
    """Click the 'Continue' / 'Log in' button in the jf onboarding flow.

    The button is a nested <div> containing <p>Continue</p> (or <p>Log in</p>),
    not a standard <button type="submit">.
    """
    try:
        return await tab.evaluate('''(() => {
            for (const p of document.querySelectorAll('p.jf-element')) {
                const t = p.textContent.trim();
                if (t === 'Continue' || t === 'Log in' || t === 'Next') {
                    p.parentElement.parentElement.parentElement.click();
                    return true;
                }
            }
            return false;
        })()''')
    except Exception:
        return False


async def _find_visible_input(tab, name, timeout=15):
    """Wait for a visible input[name=...] to appear and return it."""
    for _ in range(timeout * 2):
        try:
            found = await tab.evaluate(f'''(() => {{
                for (const inp of document.querySelectorAll('input[name="{name}"]')) {{
                    const r = inp.getBoundingClientRect();
                    if (r.width > 0 && r.height > 0) return true;
                }}
                return false;
            }})()''')
            if found:
                return await tab.select(f'input[name="{name}"]')
        except Exception:
            pass
        await asyncio.sleep(0.5)
    return None


async def _clear_otp(tab):
    """Clear the 6-box OTP field so a fresh code can be entered.

    Selects all content in the focused input and deletes it, then re-focuses
    the first OTP box.
    """
    try:
        await tab.evaluate('''(() => {
            const inputs = document.querySelectorAll('input[autocomplete="one-time-code"]');
            if (inputs.length) {
                inputs.forEach(inp => { inp.value = ''; });
                inputs[0].focus();
                return true;
            }
            // Fallback: clear any focused input
            const el = document.activeElement;
            if (el && el.tagName === 'INPUT') {
                el.value = '';
                el.dispatchEvent(new Event('input', { bubbles: true }));
            }
            return false;
        })()''')
    except Exception:
        pass


async def _type_otp(tab, code):
    """Type a 2FA code via CDP Input.insertText into the auto-focused OTP field.

    The jf onboarding 2FA screen shows 6 individual boxes that auto-focus the
    first one. insertText commits all digits at once; the field auto-submits
    when all 6 are filled. This avoids DOM/Runtime methods that can hang on
    this SPA screen.
    """
    try:
        await asyncio.wait_for(
            tab.send(cdp.input_.insert_text(code)), timeout=8
        )
        return True
    except Exception:
        return False


async def _otp_error(tab):
    """Check if the 2FA screen shows an error message like 'Incorrect'."""
    try:
        return await tab.evaluate('''(() => {
            const el = document.querySelector('[role="alert"]');
            if (el) return el.textContent.trim().substring(0, 80);
            for (const el of document.querySelectorAll('p, span')) {
                const t = el.textContent.trim();
                if (t.length < 100
                    && (t.includes('Incorrect') || t.includes('try again')
                        || t.includes('invalid') || t.includes('expired'))) {
                    return t;
                }
            }
            return '';
        })()''')
    except Exception:
        return ''


def _fresh_totp(totp_seed, min_remaining=5):
    """Generate a TOTP code with at least min_remaining seconds of validity.

    If the current code is about to expire, waits for the next window.
    """
    import time
    totp = pyotp.TOTP(totp_seed)
    code = totp.now()
    # Check remaining validity: TOTP period is 30s
    elapsed = time.time() % 30
    remaining = 30 - elapsed
    if remaining < min_remaining:
        time.sleep(remaining + 1)
        code = totp.now()
    return code


async def _get_cookies(browser):
    """Read cookies from the browser, returning a name→value dict."""
    cookies = await browser.cookies.get_all()
    return {c.name: c.value for c in cookies}


async def _check_session(browser, username):
    """Check if auth cookies are present and build a session dict."""
    cd = await _get_cookies(browser)
    if "auth_token" in cd and "ct0" in cd:
        return {
            "kind": "cookie",
            "username": username,
            "id": _extract_user_id(cd),
            "auth_token": cd["auth_token"],
            "ct0": cd["ct0"],
        }
    return None


async def login_and_get_session(username, password, totp_seed=None, headless=False):
    """Authenticate with X.com and return a session dict, or None on failure.

    Uses the new /i/jf/onboarding flow (as of mid-2026). A fresh Chrome
    profile is created per login to avoid cookie bleed.
    """
    profile = _make_profile()
    browser = await zd.start(
        headless=headless,
        user_data_dir=profile,
        browser_args=_BROWSER_ARGS,
    )
    try:
        # --- Navigate to login ---
        _log(f"[*] Logging in {username}...")
        tab = await browser.get("https://x.com/i/flow/login")
        await asyncio.sleep(4)

        # --- Username ---
        _log("[*] Entering username...")
        uinput = await _find_visible_input(tab, "username_or_email")
        if not uinput:
            raise Exception("Username field not found")
        await uinput.click()
        await asyncio.sleep(0.3)
        await uinput.send_keys(username)
        await asyncio.sleep(0.5)

        if not await _click_continue(tab):
            await uinput.send_keys("\n")
        await asyncio.sleep(3)

        err = await _check_login_error(tab)
        if err:
            raise Exception(f"Username rejected: {err}")

        # --- Password ---
        _log("[*] Entering password...")
        pw = await _find_visible_input(tab, "password")
        if not pw:
            raise Exception("Password field not found")
        await pw.click()
        await asyncio.sleep(0.3)
        await pw.send_keys(password)
        await asyncio.sleep(0.5)

        if not await _click_continue(tab):
            await pw.send_keys("\n")
        await asyncio.sleep(3)

        err = await _check_login_error(tab)
        if err:
            raise Exception(f"Login failed: {err}")

        # --- Check for immediate auth (no 2FA) ---
        session = await _check_session(browser, username)
        if session:
            _log("[*] Authenticated (no 2FA)")
            return session

        # --- 2FA ---
        # Detect 2FA by URL fragment (reliable) or page content
        for _ in range(10):
            url = tab.url or ""
            if "two_factor" in url:
                break
            await asyncio.sleep(1)
        await asyncio.sleep(1)  # let the OTP field mount and auto-focus

        url = tab.url or ""
        if "two_factor" in url:
            if not totp_seed:
                raise Exception("2FA required but no TOTP seed provided")

            _log("[*] 2FA detected, entering code...")
            last_code = None
            for attempt in range(2):
                code = _fresh_totp(totp_seed)
                while code == last_code:
                    await asyncio.sleep(3)
                    code = _fresh_totp(totp_seed)
                last_code = code

                if attempt > 0:
                    await _clear_otp(tab)
                    await asyncio.sleep(0.5)

                typed = await _type_otp(tab, code)
                _log(f"[*] OTP attempt {attempt + 1}: typed={typed}")

                # Check for success or error (fast loop)
                for _ in range(5):
                    await asyncio.sleep(2)
                    session = await _check_session(browser, username)
                    if session:
                        _log("[*] Authenticated (2FA)")
                        return session
                    err = await _otp_error(tab)
                    if err:
                        _log(f"[*] OTP rejected: {err}")
                        break

            raise Exception("2FA code rejected (account may be suspended or OTP reset)")

        # --- Post-login interstitials (premium signup push, etc.) ---
        _log("[*] Waiting for post-login redirect...")
        for i in range(10):
            session = await _check_session(browser, username)
            if session:
                _log("[*] Authenticated")
                return session
            await _click_continue(tab)
            await asyncio.sleep(2)

        raise Exception("Timeout waiting for authentication cookies")

    finally:
        try:
            await browser.stop()
        except Exception:
            pass
        await asyncio.sleep(1)
        shutil.rmtree(profile, ignore_errors=True)


async def main():
    if len(sys.argv) < 3:
        print(
            "Usage: python3 create_session_browser.py username password"
            " [totp_seed] [--append file.jsonl] [--headless]"
        )
        sys.exit(1)

    username = sys.argv[1]
    password = sys.argv[2]
    totp_seed = None
    append_file = None
    headless = False

    # Parse optional arguments
    i = 3
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--append":
            if i + 1 < len(sys.argv):
                append_file = sys.argv[i + 1]
                i += 2
            else:
                print("[!] Error: --append requires a filename", file=sys.stderr)
                sys.exit(1)
        elif arg == "--headless":
            headless = True
            i += 1
        elif not arg.startswith("--"):
            if totp_seed is None:
                totp_seed = arg
            i += 1
        else:
            print(f"[!] Warning: Unknown argument: {arg}", file=sys.stderr)
            i += 1

    try:
        session = await login_and_get_session(username, password, totp_seed, headless)
        output = json.dumps(session)

        if append_file:
            with open(append_file, "a") as f:
                f.write(output + "\n")
            print(f"✓ Session appended to {append_file}", file=sys.stderr)
        else:
            print(output)

        os._exit(0)

    except Exception as error:
        print(f"[!] Error: {error}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())
