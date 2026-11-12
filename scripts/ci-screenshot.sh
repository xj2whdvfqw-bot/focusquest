#!/usr/bin/env bash
# Spusti aplikaci v iPhone simulatoru a ulozi screenshoty vsech zalozek do build/screenshots/.
# Diky tomu jde zkontrolovat vzhled UI i bez instalace do telefonu.
set -euo pipefail
APP="build/DerivedData/Build/Products/Debug-iphonesimulator/FocusQuest.app"
if [ ! -d "$APP" ]; then echo "Simulatorovy build neexistuje, preskakuji screenshot."; exit 0; fi

UDID=$(cat build/simulator-udid 2>/dev/null || bash scripts/pick-simulator.sh)
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$APP/Info.plist")
mkdir -p build/screenshots

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 || true
xcrun simctl ui "$UDID" appearance dark || true
xcrun simctl install "$UDID" "$APP"

# Debug build umi otevrit konkretni zalozku argumentem -initialTab (viz MainTabView.swift).
INDEX=1
for TAB in arena stats profile settings; do
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" -initialTab "$TAB"
  sleep 6
  xcrun simctl io "$UDID" screenshot "build/screenshots/0${INDEX}-${TAB}.png"
  INDEX=$((INDEX + 1))
done
ls -lh build/screenshots
