#!/usr/bin/env python3
import requests
import json
import sys
import pyotp
import cloudscraper
from loguru import logger
from tools.env import OTP_SECRET, PASSWORD, PROXY_IP, PROXY_PASSWORD, PROXY_PORT, PROXY_USERNAME, USERNAME

# NOTE: pyotp, requests and cloudscraper are dependencies
# > pip install pyotp requests cloudscraper

# pip install pyotp loguru requests
TW_CONSUMER_KEY = '3nVuSoBZnx6U4vzUxf5w'
TW_CONSUMER_SECRET = 'Bcs59EFbbsdF6Sl9Ng71smgStWEGwXXKSjYvPVt7qys'

PROXIES = {
"http": "",
"https": ""
}

def auth(username, password, otp_secret=None):
    logger.info("🔑 Getting bearer token")
    resp = requests.post(
        "https://api.twitter.com/oauth2/token",
        auth=(TW_CONSUMER_KEY, TW_CONSUMER_SECRET),
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data="grant_type=client_credentials",
        proxies=PROXIES,
        timeout=15
    )
    logger.debug(resp.text)
    if resp.status_code != 200:
        logger.error("❌ Failed to get bearer token.")
        return None

    bearer_token = ' '.join(str(x) for x in resp.json().values())

    logger.info("🎫 Getting guest token")
    guest_resp = requests.post(
        "https://api.twitter.com/1.1/guest/activate.json",
        headers={"Authorization": bearer_token},
        proxies=PROXIES,
        timeout=15
    )
    logger.debug(guest_resp.text)

    guest_token = guest_resp.json().get('guest_token')
    if not guest_token:
        logger.error("❌ Failed to obtain guest token.")
        return None

    twitter_headers = {
        'Authorization': bearer_token,
        "Content-Type": "application/json",
        "User-Agent": "TwitterAndroid/10.21.0-release.0 (310210000-r-0) ONEPLUS+A3010/9",
        "X-Twitter-API-Version": '5',
        "X-Twitter-Client": "TwitterAndroid",
        "X-Twitter-Client-Version": "10.21.0-release.0",
        "OS-Version": "28",
        "System-User-Agent": "Dalvik/2.1.0 (Linux; Android 9; ONEPLUS A3010)",
        "X-Twitter-Active-User": "yes",
        "X-Guest-Token": guest_token,
        "X-Twitter-Client-DeviceID": ""
    }

    scraper = cloudscraper.create_scraper()
    scraper.headers = twitter_header
    session = requests.Session()
    session.headers = twitter_headers
    session.proxies.update(PROXIES)

    task1 = scraper.post(
    logger.info("🚀 Starting login flow")
    task1 = session.post(
        'https://api.twitter.com/1.1/onboarding/task.json',
        params={
            'flow_name': 'login',
            'api_version': '1',
            'known_device_token': '',
            'sim_country_code': 'us'
        },
        json={
            "flow_token": None,
            "input_flow_data": {
                "country_code": None,
                "flow_context": {
                    "referrer_context": {
                        "referral_details": "utm_source=google-play&utm_medium=organic",
                        "referrer_url": ""
                    },
                    "start_location": {
                        "location": "deeplink"
                    }
                },
                "requested_variant": None,
                "target_user_id": 0
            }
        },
        timeout=15
    )
    logger.debug(task1.text)

    scraper.headers['att'] = task1.headers.get('att')

    task2 = scraper.post(
    # STEP: Enter user identifier (email / phone / username)
    task2 = session.post(
        'https://api.twitter.com/1.1/onboarding/task.json',
        json={
            "flow_token": task1.json().get('flow_token'),
            "subtask_inputs": [{
                "enter_text": {
                    "text": username,
                    "link": "next_link"
                },
                "subtask_id": "LoginEnterUserIdentifier"
            }]
        },
        timeout=15
    )

    task3 = scraper.post(
    logger.debug(task2.text)

    # STEP: Enter alternate identifier if required
    for subtask in task2.json().get("subtasks", []):
        if subtask.get("subtask_id") == "LoginEnterAlternateIdentifierSubtask":
            logger.warning("⚠️ Twitter requested alternate identifier")
            task2b = session.post(
                'https://api.twitter.com/1.1/onboarding/task.json',
                json={
                    "flow_token": task2.json().get('flow_token'),
                    "subtask_inputs": [{
                        "enter_text": {
                            "text": username,
                            "link": "next_link"
                        },
                        "subtask_id": "LoginEnterAlternateIdentifierSubtask"
                    }]
                },
                timeout=15
            )
            logger.debug(task2b.text)
            task2 = task2b

    # STEP: Enter password
    task3 = session.post(
        'https://api.twitter.com/1.1/onboarding/task.json',
        json={
            "flow_token": task2.json().get('flow_token'),
            "subtask_inputs": [{
                "enter_password": {
                    "password": password,
                    "link": "next_link"
                },
                "subtask_id": "LoginEnterPassword"
            }]
        },
        timeout=15
    )

    for t3_subtask in task3.json().get('subtasks', []):
        if "open_account" in t3_subtask:
            return t3_subtask["open_account"]
        elif "enter_text" in t3_subtask:
            response_text = t3_subtask["enter_text"]["hint_text"]
            totp = pyotp.TOTP(otp_secret)
            generated_code = totp.now()
            task4resp = scraper.post(
    logger.debug(task3.text)

    # STEP: Handle possible 2FA
    for subtask in task3.json().get('subtasks', []):
        if "open_account" in subtask:
            logger.success("✅ Login successful without 2FA")
            return subtask["open_account"]
        elif "enter_text" in subtask and subtask["subtask_id"] == "LoginTwoFactorAuthChallenge":
            if not otp_secret:
                logger.error("2FA required, but no otp_secret provided.")
                return None
            try:
                totp = pyotp.TOTP(otp_secret)
                generated_code = totp.now()
                logger.info(f"🔐 Generated 2FA code: {generated_code}")
            except Exception as e:
                logger.exception("TOTP generation failed")
                return None

            task4 = session.post(
                "https://api.twitter.com/1.1/onboarding/task.json",
                json={
                    "flow_token": task3.json().get("flow_token"),
                    "subtask_inputs": [{
                        "enter_text": {
                            "text": generated_code,
                            "link": "next_link"
                        },
                        "subtask_id": "LoginTwoFactorAuthChallenge"
                    }]
                },
                timeout=15
            )
            logger.debug(task4.text)

            for sub in task4.json().get("subtasks", []):
                if "open_account" in sub:
                    logger.success("✅ Login successful with 2FA")
                    return sub["open_account"]

    logger.error("❌ Login failed: No open_account received")
    return None

def process_accounts():
    data = f"""
    {USERNAME}:{PASSWORD}:{OTP_SECRET}
    """
    results = []

    for line in data.strip().splitlines():
        parts = line.strip().split(":")
        
        login = parts[0]
        password = parts[1]
        code = parts[2] # secretcode (aka cant scan qr code)
        results.append({
            "login": login,
            "password": password,
            "code": code
        })

    return results

if __name__ == "__main__":
    accounts = process_accounts()
    proxy = [
    f"{PROXY_USERNAME}:{PROXY_PASSWORD}@{PROXY_IP}:{PROXY_PORT}",
    ]

    for account, proxy_addr in zip(accounts, proxy):
        username = account['login']
        password = account['password']
        otp_secret = account['code']
        PROXIES = {
            "http": f"http://{proxy_addr}",
            "https": f"http://{proxy_addr}"
        }

        
        result = auth(username, password, otp_secret)
        if result is None:
            print("Authentication failed.")
            sys.exit(1)

        session_entry = {
            "oauth_token": result.get("oauth_token"),
            "oauth_token_secret": result.get("oauth_token_secret")
        }

        try:
            with open("sessions.jsonl", "a") as f:
                f.write(json.dumps(session_entry) + "\n")
            print("Authentication successful. Session saved to sessions.jsonl")
        except Exception as e:
            print(f"Failed to save session: {e}")
            sys.exit(1)
