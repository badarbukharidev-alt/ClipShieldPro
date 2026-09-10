#!/usr/bin/env python3
"""
ClipShield Pro - Cryptographic Activation Key Generator
Admin tool to generate offline HMAC-SHA256 activation keys for ClipShield Pro installations.
"""

import sys
import hmac
import hashlib

# Private salt must strictly match ClipShield Pro LicenseService.salt
SALT = "CS_PRO_2026_SECURE_SALT_KEY"

def generate_key(device_id: str) -> str:
    """
    Computes the 16-character hex activation key for a given Device ID.
    Formula: HMAC_SHA256(deviceId, salt)[:16].upper()
    Formatted as: XXXX-XXXX-XXXX-XXXX
    """
    clean_id = device_id.strip()
    if not clean_id:
        raise ValueError("Device ID cannot be empty.")
    
    # Compute HMAC-SHA256
    digest = hmac.new(
        SALT.encode("utf-8"),
        clean_id.encode("utf-8"),
        hashlib.sha256
    ).hexdigest().upper()

    # Extract 16 characters and format with hyphens
    raw16 = digest[:16]
    formatted = f"{raw16[0:4]}-{raw16[4:8]}-{raw16[8:12]}-{raw16[12:16]}"
    return formatted

def verify_key(key: str, device_id: str) -> bool:
    """Verifies whether an activation key matches the expected key for a Device ID."""
    clean_input = key.replace("-", "").replace(" ", "").strip().upper()
    expected = generate_key(device_id).replace("-", "")
    return clean_input == expected

def print_banner():
    print("=" * 60)
    print("       CLIPSHIELD PRO - ADMIN ACTIVATION KEY GENERATOR      ")
    print("           Offline Cryptographic HMAC-SHA256 Engine         ")
    print("=" * 60)

def main():
    args = sys.argv[1:]

    # Check for verify flag: python generate_key.py --verify <KEY> <DEVICE_ID>
    if len(args) >= 3 and args[0] in ("--verify", "-v"):
        key = args[1]
        dev_id = args[2]
        is_valid = verify_key(key, dev_id)
        print(f"Key:       {key}")
        print(f"Device ID: {dev_id}")
        print(f"Status:    {'[VALID]' if is_valid else '[INVALID]'}")
        sys.exit(0 if is_valid else 1)

    print_banner()

    if len(args) >= 1:
        device_id = args[0].strip()
    else:
        try:
            device_id = input("\nEnter Customer Device ID (e.g., CS-XXXX-XXXX-XXXX): ").strip()
        except (KeyboardInterrupt, EOFError):
            print("\nOperation cancelled.")
            sys.exit(0)

    if not device_id:
        print("[ERROR] Device ID cannot be empty.")
        sys.exit(1)

    try:
        key = generate_key(device_id)
        raw_key = key.replace("-", "")

        print("\n" + "-" * 60)
        print(f"DEVICE ID:          {device_id}")
        print(f"ACTIVATION KEY:     {key}")
        print(f"RAW HEX (16 chars): {raw_key}")
        print("-" * 60)
        print("\nCUSTOMER WHATSAPP MESSAGE TEMPLATE:")
        print("-" * 60)
        print(f"Hello! Thank you for purchasing ClipShield Pro.\n"
              f"Here is your Lifetime Activation Key:\n\n"
              f"  *Key:* `{key}`\n\n"
              f"Instructions:\n"
              f"1. Open ClipShield Pro on your device.\n"
              f"2. In the Activation Dialog, paste this key.\n"
              f"3. Tap 'Activate ClipShield Pro' to enjoy unlimited exports!\n")
        print("=" * 60)
        print(f"\nExact Key Output: {key}")
    except Exception as e:
        print(f"[ERROR] Failed to generate key: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
