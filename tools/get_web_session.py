#!/usr/bin/env python3
"""
Authenticates with X.com/Twitter and extracts session cookies for use with Nitter.
Handles 2FA, extracts user info, and outputs clean JSON for sessions.jsonl.

Requirements:
  pip install -r tools/requirements.txt

Usage:
  python3 tools/get_web_session.py <username> <password> [totp_seed] [--append sessions.jsonl] [--headless]

Examples:
  # Output to terminal
  python3 tools/get_web_session.py myusername mypassword TOTP_BASE32_SECRET

  # Append to sessions.jsonl
  python3 tools/get_web_session.py myusername mypassword TOTP_SECRET --append sessions.jsonl

  # Headless mode (may increase detection risk)
  python3 tools/get_web_session.py myusername mypassword TOTP_SECRET --headless

Output:
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
"""

import sys
import json
import asyncio
import pyotp
import nodriver as uc


async def login_and_get_cookies(username, password, totp_seed=None, headless=False):
    """Authenticate with X.com and extract session cookies"""
    # Note: headless mode may increase detection risk from bot-detection systems
    browser = await uc.start(headless=headless)
    tab = await browser.get('https://x.com/i/flow/login')

    try:
        # Enter username
        print('[*] Entering username...', file=sys.stderr)
        username_input = await tab.find('input[autocomplete="username"]', timeout=10)
        await username_input.send_keys(username + '\n')
        await asyncio.sleep(1)

        # Enter password
        print('[*] Entering password...', file=sys.stderr)
        password_input = await tab.find('input[autocomplete="current-password"]', timeout=15)
        await password_input.send_keys(password + '\n')
        await asyncio.sleep(2)

        # Handle 2FA if needed
        page_content = await tab.get_content()
        if 'verification code' in page_content or 'Enter code' in page_content:
            if not totp_seed:
                raise Exception('2FA required but no TOTP seed provided')

            print('[*] 2FA detected, entering code...', file=sys.stderr)
            totp_code = pyotp.TOTP(totp_seed).now()
            code_input = await tab.select('input[type="text"]')
            await code_input.send_keys(totp_code + '\n')
            await asyncio.sleep(3)

        # Get cookies
        print('[*] Retrieving cookies...', file=sys.stderr)
        for _ in range(20):  # 20 second timeout
            cookies = await browser.cookies.get_all()
            cookies_dict = {cookie.name: cookie.value for cookie in cookies}

            if 'auth_token' in cookies_dict and 'ct0' in cookies_dict:
                print('[*] Found both cookies', file=sys.stderr)

                # Extract ID from twid cookie (may be URL-encoded)
                user_id = None
                if 'twid' in cookies_dict:
                    twid = cookies_dict['twid']
                    # Try to extract the ID from twid (format: u%3D<id> or u=<id>)
                    if 'u%3D' in twid:
                        user_id = twid.split('u%3D')[1].split('&')[0]
                    elif 'u=' in twid:
                        user_id = twid.split('u=')[1].split('&')[0]

                cookies_dict['username'] = username
                if user_id:
                    cookies_dict['id'] = user_id

                return cookies_dict

            await asyncio.sleep(1)

        raise Exception('Timeout waiting for cookies')

    finally:
        browser.stop()


async def main():
    if len(sys.argv) < 3:
        print('Usage: python3 twitter-auth.py username password [totp_seed] [--append sessions.jsonl] [--headless]')
        sys.exit(1)

    username = sys.argv[1]
    password = sys.argv[2]
    totp_seed = None
    append_file = None
    headless = False

    # Parse optional arguments
    for i, arg in enumerate(sys.argv[3:], 3):
        if arg == '--append' and i + 1 < len(sys.argv):
            append_file = sys.argv[i + 1]
        elif arg == '--headless':
            headless = True
        elif not arg.startswith('--'):
            totp_seed = arg

    try:
        cookies = await login_and_get_cookies(username, password, totp_seed, headless)
        session = {
            'kind': 'cookie',
            'username': cookies['username'],
            'id': cookies.get('id'),
            'auth_token': cookies['auth_token'],
            'ct0': cookies['ct0']
        }
        output = json.dumps(session)

        if append_file:
            with open(append_file, 'a') as f:
                f.write(output + '\n')
            print(f'✓ Session appended to {append_file}', file=sys.stderr)
        else:
            print(output)

        os._exit(0)

    except Exception as error:
        print(f'[!] Error: {error}', file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
