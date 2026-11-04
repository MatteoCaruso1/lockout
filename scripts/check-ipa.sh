#!/usr/bin/env bash
# Run on Codemagic after the .ipa is built. Fails the build if the app could
# be unsafe or broken on the phone:
#   1. all three targets carry the Family Controls and App Group entitlements
#   2. a Release build contains no trace of the DEBUG emergency release
#   3. no target uses networking (Lockout must never touch the network)
#   4. each extension declares the extension point iOS expects (a wrong one
#      is silently ignored on the phone and rejected by App Store upload)
set -euo pipefail

IPA=$(ls build/ios/ipa/*.ipa | head -1)
WORK=$(mktemp -d)
unzip -q -o "$IPA" -d "$WORK"
APP="$WORK/Payload/Lockout.app"
BUNDLES=("$APP" "$APP/PlugIns/LockoutMonitor.appex" "$APP/PlugIns/LockoutShield.appex")
FAIL=0

for bundle in "${BUNDLES[@]}"; do
  name=$(basename "$bundle")
  if [ ! -d "$bundle" ]; then
    echo "FAIL: $name is missing from the .ipa"; FAIL=1; continue
  fi
  ents=$(codesign -d --entitlements - --xml "$bundle" 2>/dev/null || true)
  echo "$ents" | grep -q "com.apple.developer.family-controls" \
    || { echo "FAIL: $name lacks the Family Controls entitlement"; FAIL=1; }
  echo "$ents" | grep -q "group.fun.thedailygame.lockout" \
    || { echo "FAIL: $name lacks the App Group entitlement"; FAIL=1; }

  binary="$bundle/$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Info.plist")"
  if nm -u "$binary" 2>/dev/null | grep -Eq "URLSession|NSURLConnection|nw_connection|CFNetwork|CFSocket"; then
    echo "FAIL: $name references networking APIs:"
    nm -u "$binary" | grep -E "URLSession|NSURLConnection|nw_connection|CFNetwork|CFSocket" | head -5
    FAIL=1
  fi
done

check_point() {
  local got
  got=$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$APP/PlugIns/$1/Info.plist" 2>/dev/null || true)
  [ "$got" = "$2" ] || { echo "FAIL: $1 extension point is '$got', expected '$2'"; FAIL=1; }
}
check_point LockoutMonitor.appex com.apple.deviceactivity.monitor-extension
check_point LockoutShield.appex com.apple.ManagedSettingsUI.shield-configuration-service

if [ "${LOCKOUT_CONFIG:-Release}" = "Release" ]; then
  if grep -rqa "LOCKOUT_DEBUG_EMERGENCY_RELEASE" "$APP"; then
    echo "FAIL: Release build contains the DEBUG emergency release"; FAIL=1
  fi
fi

if [ "$FAIL" -ne 0 ]; then exit 1; fi
echo "OK: 3 targets entitled, extension points right, no networking, ${LOCKOUT_CONFIG:-Release} build clean"
