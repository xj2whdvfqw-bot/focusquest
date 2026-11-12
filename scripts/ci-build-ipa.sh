#!/usr/bin/env bash
# Sestavi NEPODEPSANOU .ipa pro skutecny iPhone.
# Podepsani provede az Sideloadly na Windows (zdarma, pres bezne Apple ID).
set -euo pipefail
mkdir -p build
CONFIG="${CONFIG:-Debug}"

set -o pipefail
xcodebuild build \
  -project FocusQuest.xcodeproj \
  -scheme FocusQuest \
  -configuration "$CONFIG" \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  2>&1 | tee build/build.log | (command -v xcbeautify >/dev/null && xcbeautify || cat)

APP="build/DerivedData/Build/Products/${CONFIG}-iphoneos/FocusQuest.app"
test -d "$APP" || { echo "Chybi $APP"; exit 1; }

rm -rf build/ipa build/FocusQuest.ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry ../FocusQuest.ipa Payload)
ls -lh build/FocusQuest.ipa
