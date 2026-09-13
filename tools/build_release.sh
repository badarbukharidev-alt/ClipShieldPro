#!/usr/bin/env bash
#
# Release build with the task API secret injected at build time.
#
# The secret is NOT committed: this repository is public, and a secret in source
# would be readable by anyone. It lives in android/api_secret.txt, which
# android/.gitignore excludes, and must match API_SECRET in the admin panel's
# inc/config.php exactly.
#
# Usage:  tools/build_release.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

SECRET_FILE="android/api_secret.txt"

if [[ ! -f "$SECRET_FILE" ]]; then
  cat >&2 <<'EOF'
ERROR: android/api_secret.txt is missing.

Generate one and paste the same value into the panel's inc/config.php:

    python -c "import secrets; print(secrets.token_hex(32))" > android/api_secret.txt

Without it the app builds fine but the task reward system stays disabled.
EOF
  exit 1
fi

SECRET="$(tr -d '[:space:]' < "$SECRET_FILE")"

if [[ ${#SECRET} -lt 32 ]]; then
  echo "ERROR: secret in $SECRET_FILE is only ${#SECRET} chars; needs at least 32." >&2
  exit 1
fi

if [[ ! -f "android/key.properties" ]]; then
  echo "WARNING: android/key.properties is missing — this build will be signed" >&2
  echo "         with the debug key, which breaks upgrades and licensing." >&2
fi

echo "Building release APK (secret: ${#SECRET} chars, not echoed)..."

flutter build apk --release \
  --dart-define=CLIPSHIELD_API_SECRET="$SECRET"

echo
echo "Built: build/app/outputs/flutter-apk/app-release.apk"
