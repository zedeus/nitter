#!/usr/bin/env python3
"""
Requirements:
  pip install curl_cffi pyotp

Usage:
  python3 tools/create_session_curl.py <username> <password> [totp_seed] [--append sessions.jsonl]

Examples:
  # Output to terminal
  python3 tools/create_session_curl.py myusername mypassword TOTP_SECRET

  # Append to sessions.jsonl
  python3 tools/create_session_curl.py myusername mypassword TOTP_SECRET --append sessions.jsonl

Output:
  {"kind": "cookie", "username": "...", "id": "...", "auth_token": "...", "ct0": "..."}
"""

import sys
import json
import pyotp
from curl_cffi import requests

BEARER_TOKEN = "AAAAAAAAAAAAAAAAAAAAAFQODgEAAAAAVHTp76lzh3rFzcHbmHVvQxYYpTw%3DckAlMINMjmCwxUcaXbAN4XqJVdgMJaHqNOFgPMK0zN1qLqLQCF"
BASE_URL = "https://api.x.com/1.1/onboarding/task.json"
GUEST_ACTIVATE_URL = "https://api.x.com/1.1/guest/activate.json"

# Subtask versions required by API
SUBTASK_VERSIONS = {
    "action_list": 2, "alert_dialog": 1, "app_download_cta": 1,
    "check_logged_in_account": 2, "choice_selection": 3,
    "contacts_live_sync_permission_prompt": 0, "cta": 7, "email_verification": 2,
    "end_flow": 1, "enter_date": 1, "enter_email": 2, "enter_password": 5,
    "enter_phone": 2, "enter_recaptcha": 1, "enter_text": 5, "generic_urt": 3,
    "in_app_notification": 1, "interest_picker": 3, "js_instrumentation": 1,
    "menu_dialog": 1, "notifications_permission_prompt": 2, "open_account": 2,
    "open_home_timeline": 1, "open_link": 1, "phone_verification": 4,
    "privacy_options": 1, "security_key": 3, "select_avatar": 4,
    "select_banner": 2, "settings_list": 7, "show_code": 1, "sign_up": 2,
    "sign_up_review": 4, "tweet_selection_urt": 1, "update_users": 1,
    "upload_media": 1, "user_recommendations_list": 4,
    "user_recommendations_urt": 1, "wait_spinner": 3, "web_modal": 1
}


def get_base_headers(guest_token=None):
    """Build base headers for API requests."""
    headers = {
        "Authorization": f"Bearer {BEARER_TOKEN}",
        "Content-Type": "application/json",
        "Accept": "*/*",
        "Accept-Language": "en-US",
        "X-Twitter-Client-Language": "en-US",
        "Origin": "https://x.com",
        "Referer": "https://x.com/",
    }
    if guest_token:
        headers["X-Guest-Token"] = guest_token
    return headers


def get_cookies_dict(session):
    """Extract cookies from session."""
    return session.cookies.get_dict() if hasattr(session.cookies, 'get_dict') else dict(session.cookies)


def make_request(session, headers, flow_token, subtask_data, print_msg):
    """Generic request handler for flow steps."""
    print(f"[*] {print_msg}...", file=sys.stderr)

    payload = {
        "flow_token": flow_token,
        "subtask_inputs": [subtask_data] if isinstance(subtask_data, dict) else subtask_data
    }

    response = session.post(BASE_URL, json=payload, headers=headers)
    response.raise_for_status()

    data = response.json()
    new_flow_token = data.get('flow_token')
    if not new_flow_token:
        raise Exception(f"Failed to get flow token: {print_msg}")

    return new_flow_token, data


def get_guest_token(session):
    """Get guest token for unauthenticated requests."""
    print("[*] Getting guest token...", file=sys.stderr)
    response = session.post(GUEST_ACTIVATE_URL, headers={"Authorization": f"Bearer {BEARER_TOKEN}"})
    response.raise_for_status()

    guest_token = response.json().get('guest_token')
    if not guest_token:
        raise Exception("Failed to obtain guest token")

    print(f"[*] Got guest token: {guest_token}", file=sys.stderr)
    return guest_token


def init_flow(session, guest_token):
    """Initialize the login flow."""
    print("[*] Initializing login flow...", file=sys.stderr)

    headers = get_base_headers(guest_token)
    payload = {
        "input_flow_data": {
            "flow_context": {
                "debug_overrides": {},
                "start_location": {"location": "manual_link"}
            },
            "subtask_versions": SUBTASK_VERSIONS
        }
    }

    response = session.post(f"{BASE_URL}?flow_name=login", json=payload, headers=headers)
    response.raise_for_status()

    flow_token = response.json().get('flow_token')
    if not flow_token:
        raise Exception("Failed to get initial flow token")

    print("[*] Got initial flow token", file=sys.stderr)
    return flow_token, headers


def submit_username(session, flow_token, headers, guest_token, username):
    """Submit username."""
    headers = headers.copy()
    headers["X-Guest-Token"] = guest_token

    subtask = {
        "subtask_id": "LoginEnterUserIdentifierSSO",
        "settings_list": {
            "setting_responses": [{
                "key": "user_identifier",
                "response_data": {"text_data": {"result": username}}
            }],
            "link": "next_link"
        }
    }

    flow_token, data = make_request(session, headers, flow_token, subtask, "Submitting username")

    # Check for denial (suspicious activity)
    if data.get('subtasks') and 'cta' in data['subtasks'][0]:
        error_msg = data['subtasks'][0]['cta'].get('primary_text', {}).get('text')
        if error_msg:
            raise Exception(f"Login denied: {error_msg}")

    return flow_token


def submit_password(session, flow_token, headers, guest_token, password):
    """Submit password and detect if 2FA is needed."""
    headers = headers.copy()
    headers["X-Guest-Token"] = guest_token

    subtask = {
        "subtask_id": "LoginEnterPassword",
        "enter_password": {"password": password, "link": "next_link"}
    }

    flow_token, data = make_request(session, headers, flow_token, subtask, "Submitting password")

    needs_2fa = any(s.get('subtask_id') == 'LoginTwoFactorAuthChallenge' for s in data.get('subtasks', []))
    if needs_2fa:
        print("[*] 2FA required", file=sys.stderr)

    return flow_token, needs_2fa


def submit_2fa(session, flow_token, headers, guest_token, totp_seed):
    """Submit 2FA code."""
    if not totp_seed:
        raise Exception("2FA required but no TOTP seed provided")

    code = pyotp.TOTP(totp_seed).now()
    print("[*] Generating 2FA code...", file=sys.stderr)

    headers = headers.copy()
    headers["X-Guest-Token"] = guest_token

    subtask = {
        "subtask_id": "LoginTwoFactorAuthChallenge",
        "enter_text": {"text": code, "link": "next_link"}
    }

    flow_token, _ = make_request(session, headers, flow_token, subtask, "Submitting 2FA code")
    return flow_token


def submit_js_instrumentation(session, flow_token, headers, guest_token):
    """Submit JS instrumentation response."""
    headers = headers.copy()
    headers["X-Guest-Token"] = guest_token

    subtask = {
        "subtask_id": "LoginJsInstrumentationSubtask",
        "js_instrumentation": {
            "response": '{"rf":{"a4fc506d24bb4843c48a1966940c2796bf4fb7617a2d515ad3297b7df6b459b6":121,"bff66e16f1d7ea28c04653dc32479cf416a9c8b67c80cb8ad533b2a44fee82a3":-1,"ac4008077a7e6ca03210159dbe2134dea72a616f03832178314bb9931645e4f7":-22,"c3a8a81a9b2706c6fec42c771da65a9597c537b8e4d9b39e8e58de9fe31ff239":-12},"s":"ZHYaDA9iXRxOl2J3AZ9cc23iJx-Fg5E82KIBA_fgeZFugZGYzRtf8Bl3EUeeYgsK30gLFD2jTQx9fAMsnYCw0j8ahEy4Pb5siM5zD6n7YgOeWmFFaXoTwaGY4H0o-jQnZi5yWZRAnFi4lVuCVouNz_xd2BO2sobCO7QuyOsOxQn2CWx7bjD8vPAzT5BS1mICqUWyjZDjLnRZJU6cSQG5YFIHEPBa8Kj-v1JFgkdAfAMIdVvP7C80HWoOqYivQR7IBuOAI4xCeLQEdxlGeT-JYStlP9dcU5St7jI6ExyMeQnRicOcxXLXsan8i5Joautk2M8dAJFByzBaG4wtrPhQ3QAAAZEi-_t7"}',
            "link": "next_link"
        }
    }

    flow_token, _ = make_request(session, headers, flow_token, subtask, "Submitting JS instrumentation")
    return flow_token


def complete_flow(session, flow_token, headers):
    """Complete the login flow."""
    cookies = get_cookies_dict(session)

    headers = headers.copy()
    headers["X-Twitter-Auth-Type"] = "OAuth2Session"
    if cookies.get('ct0'):
        headers["X-Csrf-Token"] = cookies['ct0']

    subtask = {
        "subtask_id": "AccountDuplicationCheck",
        "check_logged_in_account": {"link": "AccountDuplicationCheck_false"}
    }

    make_request(session, headers, flow_token, subtask, "Completing login flow")


def extract_user_id(cookies_dict):
    """Extract user ID from twid cookie."""
    twid = cookies_dict.get('twid', '').strip('"')

    for prefix in ['u=', 'u%3D']:
        if prefix in twid:
            return twid.split(prefix)[1].split('&')[0].strip('"')

    return None


def login_and_get_cookies(username, password, totp_seed=None):
    """Authenticate with X.com and extract session cookies."""
    session = requests.Session(impersonate="chrome")

    try:
        guest_token = get_guest_token(session)
        flow_token, headers = init_flow(session, guest_token)
        flow_token = submit_js_instrumentation(session, flow_token, headers, guest_token)
        flow_token = submit_username(session, flow_token, headers, guest_token, username)
        flow_token, needs_2fa = submit_password(session, flow_token, headers, guest_token, password)

        if needs_2fa:
            flow_token = submit_2fa(session, flow_token, headers, guest_token, totp_seed)

        complete_flow(session, flow_token, headers)

        cookies_dict = get_cookies_dict(session)
        cookies_dict['username'] = username

        user_id = extract_user_id(cookies_dict)
        if user_id:
            cookies_dict['id'] = user_id

        print("[*] Successfully authenticated", file=sys.stderr)
        return cookies_dict

    finally:
        session.close()


def main():
    if len(sys.argv) < 3:
        print('Usage: python3 create_session_curl.py username password [totp_seed] [--append sessions.jsonl]', file=sys.stderr)
        sys.exit(1)

    username = sys.argv[1]
    password = sys.argv[2]
    totp_seed = None
    append_file = None

    # Parse optional arguments
    i = 3
    while i < len(sys.argv):
        arg = sys.argv[i]
        if arg == '--append':
            if i + 1 < len(sys.argv):
                append_file = sys.argv[i + 1]
                i += 2
            else:
                print('[!] Error: --append requires a filename', file=sys.stderr)
                sys.exit(1)
        elif not arg.startswith('--'):
            if totp_seed is None:
                totp_seed = arg
            i += 1
        else:
            print(f'[!] Warning: Unknown argument: {arg}', file=sys.stderr)
            i += 1

    try:
        cookies = login_and_get_cookies(username, password, totp_seed)

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

        sys.exit(0)

    except Exception as error:
        print(f'[!] Error: {error}', file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
