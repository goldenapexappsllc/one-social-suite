#!/bin/bash
# Run before any App Store / Play Store build. Prints only versions.
fail=0

XPATH=$(xcode-select -p)
echo "Xcode path: $XPATH"
case "$XPATH" in
  *[Bb]eta*) echo "STOP: beta Xcode is selected."; fail=1 ;;
esac
if [ ! -d "/Applications/Xcode.app/Contents/_MASReceipt" ]; then
  echo "STOP: Xcode.app is not the Mac App Store release."; fail=1
fi
case "$XPATH" in
  /Applications/Xcode.app/*) ;;
  *) echo "STOP: selected Xcode is not /Applications/Xcode.app."; fail=1 ;;
esac

CHAN=$(flutter --version 2>/dev/null | head -1)
echo "$CHAN"
case "$CHAN" in
  *"channel stable"*) ;;
  *) echo "STOP: Flutter is not on the stable channel."; fail=1 ;;
esac

if grep -nE "^\s+[a-z_]+: \^?[0-9.]+-(dev|beta|pre|alpha|rc)" pubspec.yaml >/dev/null; then
  echo "STOP: a prerelease package version is in pubspec.yaml."; fail=1
fi

if [ $fail -eq 0 ]; then
  echo "OK: release Xcode, stable Flutter, no prerelease packages."
else
  exit 1
fi
