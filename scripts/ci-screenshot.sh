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
#
# Dokud aplikace nevykresli prvni snimek, je na obrazovce jen cerna plocha se stavovym radkem
# (PNG ~70 kB, skutecna obrazovka ma pres 2 MB). CI stroj je pomaly a start trva ruzne dlouho,
# takze se neceka pevny cas, ale foti se opakovane, dokud snimek neni vykresleny.
MIN_BYTES=300000   # mensi PNG = jeste se nic nevykreslilo
MAX_WAIT=75        # sekund od spusteni aplikace

png_size() { wc -c < "$1" | tr -d ' '; }

# macOS nema `timeout`. Spusti prikaz a po $1 sekundach ho natvrdo ukonci,
# aby zaseknuta diagnostika (sample, log show) nevycerpala casovy limit celeho buildu.
with_timeout() {
  local SECS="$1"; shift
  "$@" &
  local CMD_PID=$!
  ( sleep "$SECS"; kill -9 "$CMD_PID" ) >/dev/null 2>&1 &
  local WATCH_PID=$!
  local RC=0
  wait "$CMD_PID" 2>/dev/null || RC=$?
  kill "$WATCH_PID" >/dev/null 2>&1 || true
  return "$RC"
}

# Kdyz se obrazovka nevykresli ani po MAX_WAIT, vypise do logu, jestli aplikace spadla nebo se zasekla a kde.
diagnose() {
  local TAB="$1" PID="$2"
  echo "::warning::Zalozka '$TAB' se v simulatoru nevykreslila ani po ${MAX_WAIT} s (cerna obrazovka)."
  if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
    echo "--- [$TAB] proces $PID bezi => aplikace se zasekla. Zasobnik hlavniho vlakna:"
    with_timeout 30 sample "$PID" 3 -mayDie -file "build/sample-$TAB.txt" >/dev/null 2>&1 || echo "(sample nedobehl do 30 s)"
    head -n 160 "build/sample-$TAB.txt" 2>/dev/null || echo "(sample se nepodarilo ziskat)"
  else
    echo "--- [$TAB] proces ${PID:-?} uz nebezi => aplikace spadla. Posledni crash report:"
    local REPORT
    REPORT=$(ls -t "$HOME"/Library/Logs/DiagnosticReports/FocusQuest*.ips 2>/dev/null | head -n 1 || true)
    if [ -n "$REPORT" ]; then head -n 120 "$REPORT"; else echo "(zadny crash report nenalezen)"; fi
  fi
  echo "--- [$TAB] poslednich 60 radku logu aplikace:"
  with_timeout 30 xcrun simctl spawn "$UDID" log show --last 3m --style compact --predicate 'process == "FocusQuest"' 2>/dev/null | tail -n 60 || true
}

INDEX=1
PREV_SHOT=""
# Kazda polozka je "rezim:zalozka". Appka ma vynuceny tmavy rezim, svetle snimky by byly stejne.
# "creator" neni zalozka, ale uvodni tvorba hrdiny pri prvnim spusteni.
# Poradi = priorita: kdyz je simulator pomaly a krok narazi na limit, chybi az ty posledni.
for ENTRY in dark:arena dark:fight dark:battle dark:path dark:creator dark:profile dark:village dark:shop dark:stats dark:settings; do
  MODE="${ENTRY%%:*}"
  TAB="${ENTRY##*:}"
  xcrun simctl ui "$UDID" appearance "$MODE" || true
  SHOT=$(printf 'build/screenshots/%02d-%s-%s.png' "$INDEX" "$TAB" "$MODE")
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  LAUNCH_OUTPUT=$(xcrun simctl launch "$UDID" "$BUNDLE_ID" -initialTab "$TAB")
  echo "$LAUNCH_OUTPUT"
  PID="${LAUNCH_OUTPUT##*: }"
  case "$PID" in *[!0-9]*|"") PID="" ;; esac
  DEADLINE=$((SECONDS + MAX_WAIT))
  sleep 6
  while :; do
    xcrun simctl io "$UDID" screenshot "$SHOT"
    SIZE=$(png_size "$SHOT")
    # Na pomalem stroji muze na obrazovce jeste viset posledni snimek predchozi zalozky;
    # stejny obrazek jako minule tedy znamena, ze nova zalozka se jeste nevykreslila.
    if [ "$SIZE" -ge "$MIN_BYTES" ] && { [ -z "$PREV_SHOT" ] || ! cmp -s "$SHOT" "$PREV_SHOT"; }; then break; fi
    if [ "$SECONDS" -ge "$DEADLINE" ]; then diagnose "$TAB" "$PID"; break; fi
    echo "[$TAB] obrazovka jeste neni vykreslena (${SIZE} B), zkousim znovu..."
    sleep 4
  done
  PREV_SHOT="$SHOT"
  INDEX=$((INDEX + 1))
done
ls -lh build/screenshots
