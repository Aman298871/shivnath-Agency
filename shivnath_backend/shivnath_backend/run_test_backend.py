"""
Shivnath Agency (WATERNow) - Dedicated Test Backend Launcher
Loads isolated test configuration from .env.test and starts Django test server.
"""

import os
import sys
import subprocess
from pathlib import Path
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent
ENV_TEST_PATH = BASE_DIR / '.env.test'

if ENV_TEST_PATH.exists():
    load_dotenv(ENV_TEST_PATH, override=True)
    print(f"[*] Loaded test environment from: {ENV_TEST_PATH}")
else:
    print(f"[!] Warning: .env.test not found at {ENV_TEST_PATH}")

os.environ['ENVIRONMENT'] = 'test'
os.environ['DJANGO_SETTINGS_MODULE'] = 'config.settings'

key_id = os.environ.get('RAZORPAY_KEY_ID', '').strip()
key_secret = os.environ.get('RAZORPAY_KEY_SECRET', '').strip()
rzp_env = os.environ.get('RAZORPAY_ENVIRONMENT', 'TEST').strip()

print("=" * 65)
print("  SHIVNATH AGENCY (WATERNow) - RAZORPAY TEST BACKEND")
print("=" * 65)
print(f"  ENVIRONMENT          : {os.environ.get('ENVIRONMENT')}")
print(f"  RAZORPAY_ENVIRONMENT: {rzp_env}")
print(f"  RAZORPAY_KEY_ID     : {key_id if key_id else '[NOT CONFIGURED]'}")
print(f"  RAZORPAY_KEY_SECRET : {'[CONFIGURED]' if key_secret else '[NOT CONFIGURED]'}")

if not key_id or not key_secret:
    print("\n  [DIAGNOSTIC STATUS]:")
    print("  Razorpay Test Mode credentials are not yet entered in .env.test.")
    print("  The server will run safely in diagnostic mode.")
    print("  Endpoints will return HTTP 503 GATEWAY_CREDENTIALS_MISSING_IN_TEST.")
    print("  To enable actual checkout sheet, edit .env.test and set:")
    print("    RAZORPAY_KEY_ID=rzp_test_YourKeyHere")
    print("    RAZORPAY_KEY_SECRET=YourSecretHere")
else:
    print("\n  [DIAGNOSTIC STATUS]:")
    print("  Razorpay Test credentials detected. Ready for sandbox checkout testing.")

print("=" * 65)
print("  Starting Django server on 0.0.0.0:8000 (accessible from emulator and phone)...")
print("=" * 65)

python_exe = sys.executable
subprocess.run([python_exe, str(BASE_DIR / 'manage.py'), 'runserver', '0.0.0.0:8000'])
