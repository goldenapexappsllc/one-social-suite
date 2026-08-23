#!/bin/bash
# 1Social / 1PrivateSocial release build.
# The dart-defines are REQUIRED. Without them AI captions silently
# fall back to the rules engine with no error shown.
set -e
cd /Volumes/DevDrive/one_private_social
PROXY="https://onesocial-ai-proxy.goldenapexapps.workers.dev"
SECRET=$(cat "$HOME/.gaa_secrets/onesocial_shared_secret.txt")
flutter build appbundle --release --dart-define=AI_PROXY_URL="$PROXY" --dart-define=APP_SHARED_SECRET="$SECRET"
echo ""
echo "VERIFY:"
rm -rf /tmp/vcheck && mkdir -p /tmp/vcheck && cd /tmp/vcheck
unzip -q /Volumes/DevDrive/one_private_social/build/app/outputs/bundle/release/app-release.aab
LIB="base/lib/arm64-v8a/libapp.so"
echo "  proxy URL (want 1+):    $(grep -ac 'workers.dev' $LIB || true)"
echo "  paywall code (want 3):  $(grep -ac 'aiassist' $LIB || true)"
echo "  leaked keys (want none):"
grep -aoE 'sk-[A-Za-z0-9_-]{20,}' $LIB base/dex/*.dex 2>/dev/null | head || true
