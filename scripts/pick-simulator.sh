#!/usr/bin/env bash
# Vypise UDID iPhone simulatoru s nejnovejsim iOS (prednostne iPhone 17).
# Dynamicky vyber = CI se nerozbije, kdyz GitHub aktualizuje verzi simulatoru.
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
candidates = []
for runtime, devs in devices.items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(p) for p in runtime.split(".iOS-")[-1].split("-") if p.isdigit())
    for d in devs:
        if d["name"].startswith("iPhone"):
            candidates.append((version, "iPhone 17" in d["name"], d["name"], d["udid"]))
if not candidates:
    sys.exit("Nenalezen zadny iPhone simulator")
candidates.sort(reverse=True)
best = candidates[0]
version = ".".join(map(str, best[0]))
print(f"Simulator: {best[2]} (iOS {version})", file=sys.stderr)
print(best[3])
'
