#!/usr/bin/env bash
# Sestavi NEPODEPSANOU .ipa pro skutecny iPhone.
# Podepsani provede az Sideloadly na Windows (zdarma, pres bezne Apple ID).
set -euo pipefail
mkdir -p build
CONFIG="${CONFIG:-Debug}"
# COMPILE_ONLY=1: jen sestavit a zkontrolovat obsah appky, bez .ipa (kontrola Release buildu).
COMPILE_ONLY="${COMPILE_ONLY:-0}"
# BUILD_NUMBER (v CI cislo behu): kazdy build ma vyssi CFBundleVersion, jak chce App Store Connect.
EXTRA_SETTINGS=()
if [ -n "${BUILD_NUMBER:-}" ]; then EXTRA_SETTINGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER"); fi

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
  ${EXTRA_SETTINGS[@]+"${EXTRA_SETTINGS[@]}"} \
  2>&1 | tee "build/build-$CONFIG.log" | (command -v xcbeautify >/dev/null && xcbeautify || cat) || {
    echo "::group::Chyby ze suroveho logu"
    grep -nE "error:|Stack dump|While evaluating|While emitting|BUILD FAILED" "build/build-$CONFIG.log" | cut -c1-400 | head -60
    echo "::endgroup::"
    exit 1
  }

APP="build/DerivedData/Build/Products/${CONFIG}-iphoneos/FocusQuest.app"
test -d "$APP" || { echo "Chybi $APP"; exit 1; }

# Bez Widget Extension se Live Activity na zamcene obrazovce nezobrazi,
# bez .mp3 by hudba mlcela - radsi at build spadne tady nez az v telefonu.
test -d "$APP/PlugIns/FocusQuestWidgets.appex" || { echo "V appce chybi PlugIns/FocusQuestWidgets.appex"; exit 1; }
for track in calm-currents tokyo-sunset peaceful-drift; do
  test -f "$APP/$track.mp3" || { echo "V appce chybi skladba $track.mp3"; exit 1; }
done
# Bez fontu by nadpisy tise spadly na systemove pismo.
test -f "$APP/PixelifySans-Medium.ttf" || { echo "V appce chybi font PixelifySans-Medium.ttf"; exit 1; }
# Bez ikony App Store Connect build odmitne a notifikace maji prazdny ctverec.
/usr/libexec/PlistBuddy -c "Print :CFBundleIcons:CFBundlePrimaryIcon:CFBundleIconName" "$APP/Info.plist" >/dev/null 2>&1 || { echo "V Info.plist chybi CFBundleIconName (ikona)"; exit 1; }
test -f "$APP/Assets.car" || { echo "V appce chybi Assets.car (ikona)"; exit 1; }
# Bez privacy manifestu App Store Connect build odmitne (UserDefaults, systemUptime).
test -f "$APP/PrivacyInfo.xcprivacy" || { echo "V appce chybi PrivacyInfo.xcprivacy"; exit 1; }
echo "Obsah appky OK: Widget Extension + 3 skladby + pixelovy font + ikona + PrivacyInfo"

if [ "$COMPILE_ONLY" = "1" ]; then
  echo "$CONFIG build OK (bez .ipa)"
  exit 0
fi

rm -rf build/ipa build/FocusQuest.ipa
mkdir -p build/ipa/Payload
cp -R "$APP" build/ipa/Payload/
(cd build/ipa && zip -qry ../FocusQuest.ipa Payload)
ls -lh build/FocusQuest.ipa
