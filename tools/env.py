from dotenv import load_dotenv
import os


load_dotenv(override=True)

USERNAME = os.getenv("USERNAME")
PASSWORD = os.getenv("PASSWORD")
OTP_SECRET = os.getenv("OTP_SECRET")

PROXY_USERNAME = os.getenv("PROXY_USERNAME")
PROXY_PASSWORD = os.getenv("PROXY_PASSWORD")
PROXY_IP = os.getenv("PROXY_IP")
PROXY_PORT = os.getenv("PROXY_PORT")