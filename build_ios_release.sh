#!/bin/bash
# 1PrivateSocial iOS RELEASE build (for TestFlight / App Store).
# Needs the regular Xcode, NOT the beta. Never passes DEV_UNLOCK_ALL.
set -e
cd /Volumes/DevDrive/one_private_social

if [ "$(xcode-select -p)" != "/Applications/Xcode.app/Contents/Developer" ]; then
  echo "Xcode is not set to the regular Xcode.app -- stopping."
  echo "Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  exit 1
fi

PROXY=$(grep -E '^PROXY=' build_release.sh | head -1 | cut -d'"' -f2)
if [ -z "$PROXY" ]; then
  echo "Could not read PROXY from build_release.sh -- stopping."
  exit 1
fi

if [ ! -s "$HOME/.gaa_s" ]; then
  echo "Missing or empty $HOME/.gaa_s -- stopping."
  exit 1
fi
SECRET=$(cat "$HOME/.gaa_s")

flutter build ipa --release \
  --dart-define=AI_PROXY_URL="$PROXY" \
  --dart-define=APP_SHARED_SECRET="$SECRET"

echo ""
echo "VERIFY:"
APP="build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App"
if [ -f "$APP" ]; then
  echo "  proxy URL (want 1+):    $(grep -ac 'workers.dev' "$APP" || true)"
else
  echo "  could not find the built app to check"
fi
echo ""
echo "IPA:"
ls -1 build/ios/ipa/*.ipa 2>/dev/null || echo "  no .ipa found"
