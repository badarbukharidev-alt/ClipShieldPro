#!/usr/bin/env bash
#
# Builds a reseller's copy of the app.
#
# The reseller code is compiled in, because it is what the panel keys off to
# return that reseller's support number and that reseller's update. It cannot be
# fetched at runtime: it has to be known before the first API call.
#
# A reseller build also has the in-app admin tools compiled out. Those screens
# mint licence keys on the device with no quota and no record, which would let a
# reseller -- or anyone holding a copy of their APK -- issue unlimited keys and
# bypass their allowance entirely.
#
# Usage:  tools/build_reseller.sh <reseller-code>
# Example: tools/build_reseller.sh ali-traders
#
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 1 ]]; then
  echo "Usage: tools/build_reseller.sh <reseller-code>" >&2
  echo "The code must match the one created in the admin panel exactly." >&2
  exit 1
fi

RESELLER="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"

# Same rule the panel applies. A code that fails here would compile into an app
# that silently reports itself as a house build.
if ! echo "$RESELLER" | grep -Eq '^[a-z0-9][a-z0-9_-]{1,31}$'; then
  echo "ERROR: \"$RESELLER\" is not a valid reseller code." >&2
  echo "       2-32 characters: lowercase letters, digits, hyphen, underscore." >&2
  exit 1
fi

SECRET_FILE="android/api_secret.txt"

if [[ ! -f "$SECRET_FILE" ]]; then
  echo "ERROR: android/api_secret.txt is missing. See tools/build_release.sh." >&2
  exit 1
fi

SECRET="$(tr -d '[:space:]' < "$SECRET_FILE")"

if [[ ${#SECRET} -lt 32 ]]; then
  echo "ERROR: secret in $SECRET_FILE is only ${#SECRET} chars; needs at least 32." >&2
  exit 1
fi

if [[ ! -f "android/key.properties" ]]; then
  echo "WARNING: android/key.properties is missing -- this build will be signed" >&2
  echo "         with the debug key, which breaks upgrades and licensing." >&2
fi

# ---------------------------------------------------------------------------
# Clear the previous build's Flutter intermediates.
#
# Two separate problems live here, and doing only one of them is why this kept
# failing:
#
#  1. A --dart-define change does not invalidate the intermediates, so the asset
#     copy walks into files left by the last build: "Cannot create a file when
#     that file already exists".
#  2. Gradle keeps a daemon alive after a build, holding open handles on those
#     same files. Deleting them then fails with "Access is denied" -- and so
#     does Flutter's own cleanup a moment later, which is what produced the tool
#     crash.
#
# Stop the daemons first, then delete.
# ---------------------------------------------------------------------------
INTERMEDIATES="build/app/intermediates/flutter"

if [[ -d "$INTERMEDIATES" ]]; then
  echo "Stopping Gradle daemons so the previous build releases its files..."
  (cd android && ./gradlew --stop >/dev/null 2>&1) || true

  echo "Clearing intermediates from the previous build..."
  rm -rf "$INTERMEDIATES" 2>/dev/null || true

  if [[ -d "$INTERMEDIATES" ]]; then
    echo "Still locked. Falling back to a full 'flutter clean'..."
    flutter clean >/dev/null 2>&1 || true
  fi

  if [[ -d "$INTERMEDIATES" ]]; then
    echo "ERROR: could not clear $INTERMEDIATES." >&2
    echo "       Something is holding those files open. Close any other build," >&2
    echo "       editor or file explorer in this folder and run this again." >&2
    exit 1
  fi
fi

echo "Building reseller APK for \"$RESELLER\"..."

flutter build apk --release \
  --dart-define=CLIPSHIELD_API_SECRET="$SECRET" \
  --dart-define=CLIPSHIELD_RESELLER="$RESELLER"

OUT="build/app/outputs/flutter-apk/app-release.apk"
DEST="release/ClipShieldPro-$RESELLER.apk"

mkdir -p release
cp "$OUT" "$DEST"

echo
echo "Built: $DEST"
echo
echo "Next: upload it somewhere reachable over https, then record it in the"
echo "admin panel under Resellers > $RESELLER > Publish a build. The reseller"
echo "then sees it on their portal as the version to hand out."
