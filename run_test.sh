#!/bin/bash
# TEST ONLY -- installs to a connected iPhone with AI Assist wired up.
# DEV_UNLOCK_ALL skips the purchase. NEVER use this for a store build.
# Usage: ./run_test.sh            (iPhone 13 Pro)
#        ./run_test.sh DEVICE_ID  (any other device)
set -e
cd /Volumes/DevDrive/one_private_social

DEVICE="${1:-00008110-00140D5914C2801E}"

# Reuse the proxy URL already stored in build_release.sh
PROXY=$(grep -E '^PROXY=' build_release.sh | head -1 | cut -d'"' -f2)
if [ -z "$PROXY" ]; then
  echo "Could not read PROXY from build_release.sh -- stopping."
  exit 1
fi

# Secret stays in a private file, never in this script
if [ ! -f "$HOME/.gaa_s" ]; then
  echo "Missing $HOME/.gaa_s -- stopping."
  exit 1
fi
SECRET=$(cat "$HOME/.gaa_s")

flutter run --release -d "$DEVICE" \
  --dart-define=AI_PROXY_URL="$PROXY" \
  --dart-define=APP_SHARED_SECRET="$SECRET" \
  --dart-define=DEV_UNLOCK_ALL=true
