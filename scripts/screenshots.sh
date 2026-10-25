#!/usr/bin/env bash
# Boots a simulator, installs the Debug build and captures each tab with demo data.
set -euo pipefail
UDID="$1"
APP="$2"
OUT="${3:-screenshots}"
BUNDLE_ID="com.avaditya.spendwise"
mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 || true
xcrun simctl install "$UDID" "$APP"
for tab in today activity friends plan settings; do
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -demo -tab "$tab"
  sleep 6
  xcrun simctl io "$UDID" screenshot "$OUT/$tab.png"
done
xcrun simctl ui "$UDID" appearance dark
xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$UDID" "$BUNDLE_ID" -demo -tab today
sleep 6
xcrun simctl io "$UDID" screenshot "$OUT/today-dark.png"
