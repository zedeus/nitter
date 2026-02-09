#!/usr/bin/env python3
"""
Requirements:
  pip install -r tools/requirements.txt

Usage:
  python3 tools/create_sessions_browser.py <accounts_file> [--append sessions.jsonl] [--headless] [--delay]

Examples:
  # Output to terminal
  python3 tools/create_sessions_browser.py <accounts_file>

  # Append to sessions.jsonl
  python3 tools/create_sessions_browser.py <accounts_file> --append sessions.jsonl

  # Add 5 second delay between sessions (default: 1)
  python3 tools/create_sessions_browser.py <accounts_file> --delay 5

  # Headless mode (may increase detection risk)
  python3 tools/create_sessions_browser.py <accounts_file> --headless

Input (accounts_file):
  [{"username": "user", "password": "pass", "totp": "totp_code"}, {...}, ...]

Output:
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
  ...
"""

import asyncio
import json
import sys
from time import sleep

import nodriver as uc
import pyotp


async def login_and_get_cookies(account, headless=False):
    """Authenticate with X.com and extract session cookies"""
    # Note: headless mode may increase detection risk from bot-detection systems
    browser = await uc.start(headless=headless)
    tab = await browser.get("https://x.com/i/flow/login")

    username = account["username"]
    password = account["password"]
    totp_seed = account["totp"]

    try:
        # Enter username
        print(f"[*] Entering username {username}...", file=sys.stderr)

        retry = 0
        while retry < 5:
            username_input = await tab.find(
                'input[autocomplete="username"]', timeout=10
            )

            pos = await username_input.get_position()
            await tab.mouse_move(pos.x, pos.y, steps=50, flash=True)
            await asyncio.sleep(0.1)

            await username_input.click()
            await asyncio.sleep(0.5)
            await username_input.send_keys(username)
            await asyncio.sleep(0.2)
            await username_input.send_keys("\n")
            await asyncio.sleep(2)

            page_content = await tab.get_content()
            if "Could not log you in" in page_content:
                retry += 1
                wait = retry * 10
                print(f"Retrying in {wait} seconds...")
                await asyncio.sleep(wait)
            else:
                break

        # Enter password
        print("[*] Entering password...", file=sys.stderr)
        pretry = 0
        while pretry < 5:
            password_input = await tab.find(
                'input[autocomplete="current-password"]', timeout=15
            )
            await password_input.click()
            await asyncio.sleep(0.5)
            await password_input.send_keys(password)
            await asyncio.sleep(0.2)
            await password_input.send_keys("\n")
            await asyncio.sleep(2)

            page_content = await tab.get_content()
            if "Could not log you in" in page_content:
                pretry += 1
                wait = pretry * 10
                print(f"Retrying in {wait} seconds...")
                await asyncio.sleep(wait)
            else:
                break

        # Handle 2FA if needed
        page_content = await tab.get_content()
        if "verification code" in page_content or "Enter code" in page_content:
            if not totp_seed:
                raise Exception("2FA required but no TOTP seed provided")

            print("[*] 2FA detected, entering code...", file=sys.stderr)
            totp_code = pyotp.TOTP(totp_seed).now()
            code_input = await tab.select('input[type="text"]')
            await code_input.send_keys(totp_code + "\n")
            await asyncio.sleep(3)

        # Get cookies
        print("[*] Retrieving cookies...", file=sys.stderr)
        for _ in range(20):  # 20 second timeout
            cookies = await browser.cookies.get_all()
            cookies_dict = {cookie.name: cookie.value for cookie in cookies}

            if "auth_token" in cookies_dict and "ct0" in cookies_dict:
                # Extract ID from twid cookie (may be URL-encoded)
                user_id = None
                if "twid" in cookies_dict:
                    twid = cookies_dict["twid"]
                    # Try to extract the ID from twid (format: u%3D<id> or u=<id>)
                    if "u%3D" in twid:
                        user_id = twid.split("u%3D")[1].split("&")[0].strip('"')
                    elif "u=" in twid:
                        user_id = twid.split("u=")[1].split("&")[0].strip('"')

                cookies_dict["username"] = username
                if user_id:
                    cookies_dict["id"] = user_id

                return cookies_dict

            await asyncio.sleep(1)

        raise Exception("Timeout waiting for cookies")

    finally:
        browser.stop()


async def main():
    if len(sys.argv) < 2:
        print(
            "Usage: python3 create_sessions_browser.py <accounts_file> [--append sessions.jsonl] [--headless]"
        )
        sys.exit(1)

    input = sys.argv[1]
    append_file = None
    headless = False
    delay = 1

    # Parse optional arguments
    i = 2
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == "--append":
            if i + 1 < len(sys.argv):
                append_file = sys.argv[i + 1]
                i += 2  # Skip '--append' and filename
            else:
                print("[!] Error: --append requires a filename", file=sys.stderr)
                sys.exit(1)
        elif arg == "--headless":
            headless = True
            i += 1
        elif arg == "--delay":
            delay = int(sys.argv[i + 1])
            i += 2
        else:
            # Unkown args
            print(f"[!] Warning: Unknown argument: {arg}", file=sys.stderr)
            i += 1

    accounts = []
    with open(input) as f:
        accounts = json.load(f)

    if len(accounts) == 0:
        print("no accounts in file")
        sys.exit(0)

    sessions = 0
    for acc in accounts:
        sessions += 1
        try:
            cookies = await login_and_get_cookies(acc, headless)
            session = {
                "kind": "cookie",
                "username": cookies["username"],
                "id": cookies.get("id"),
                "auth_token": cookies["auth_token"],
                "ct0": cookies["ct0"],
            }

            if append_file:
                with open(append_file, "a") as f:
                    f.write(json.dumps(session) + "\n")
            else:
                print(json.dumps(session))

            print(f"Progress: {sessions} / {len(accounts)}")
            if sessions < len(accounts):
                print("Waiting", delay, "seconds")
                sleep(delay)
        except Exception as error:
            print(
                f"[!] Error getting session for {acc["username"]}, skipping: {error}",
                file=sys.stderr,
            )


if __name__ == "__main__":
    asyncio.run(main())
