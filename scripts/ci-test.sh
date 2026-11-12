#!/usr/bin/env bash
# Spusti unit testy na iOS simulatoru (bezi na macOS runneru v GitHub Actions).
set -euo pipefail
mkdir -p build

UDID=$(bash scripts/pick-simulator.sh)
echo "$UDID" > build/simulator-udid

rm -rf build/TestResults.xcresult
xcodebuild test \
  -project FocusQuest.xcodeproj \
  -scheme FocusQuest \
  -destination "id=$UDID" \
  -derivedDataPath build/DerivedData \
  -resultBundlePath build/TestResults.xcresult \
  2>&1 | tee build/test.log | (command -v xcbeautify >/dev/null && xcbeautify || cat) || {
    echo "::group::Chyby ze suroveho logu"
    grep -nE "error:|failed|Stack dump|While evaluating|While emitting|TEST FAILED|BUILD FAILED" build/test.log | cut -c1-400 | head -80
    echo "::endgroup::"
    exit 1
  }
