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

  # Add 5 second delay between sessions (default: 3)
  python3 tools/create_sessions_browser.py <accounts_file> --delay 5

  # Headless mode (may increase detection risk)
  python3 tools/create_sessions_browser.py <accounts_file> --headless

Input (accounts_file):
  [{"username": "user", "password": "pass", "totp": "totp_secret"}, {...}, ...]

Output:
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
  ...
"""

import asyncio
import json
import sys
from time import sleep

from create_session_browser import login_and_get_session


async def main():
    if len(sys.argv) < 2:
        print(
            "Usage: python3 create_sessions_browser.py <accounts_file>"
            " [--append sessions.jsonl] [--headless] [--delay N]"
        )
        sys.exit(1)

    input_file = sys.argv[1]
    append_file = None
    headless = False
    delay = 3

    # Parse optional arguments
    i = 2
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
        elif arg == "--delay":
            delay = int(sys.argv[i + 1])
            i += 2
        else:
            print(f"[!] Warning: Unknown argument: {arg}", file=sys.stderr)
            i += 1

    with open(input_file) as f:
        accounts = json.load(f)

    if not accounts:
        print("No accounts in file")
        sys.exit(0)

    ok, fail = [], []
    for idx, acc in enumerate(accounts, 1):
        username = acc["username"]
        print(
            f"\n[{idx}/{len(accounts)}] {username}...",
            file=sys.stderr,
            flush=True,
        )
        try:
            session = await login_and_get_session(
                username, acc["password"], acc.get("totp"), headless
            )

            if append_file:
                with open(append_file, "a") as f:
                    f.write(json.dumps(session) + "\n")
            else:
                print(json.dumps(session))

            ok.append(username)
            print(
                f"  ✓ saved (id={session['id']})",
                file=sys.stderr,
                flush=True,
            )
        except Exception as error:
            fail.append(username)
            print(
                f"  ✗ {error}",
                file=sys.stderr,
                flush=True,
            )

        if idx < len(accounts):
            sleep(delay)

    print(
        f"\nDone: {len(ok)} ok, {len(fail)} failed",
        file=sys.stderr,
        flush=True,
    )
    if fail:
        print(f"  failed: {fail}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    asyncio.run(main())
