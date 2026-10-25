#!/usr/bin/env bash
# Prints the UDID of the newest available iPhone simulator (Xcode versions ship different models).
set -euo pipefail
xcrun simctl list devices available -j | python3 -c '
import json, re, sys
data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    version = tuple(int(x) for x in re.findall(r"\d+", runtime.split("iOS")[-1]))
    for d in devices:
        if d["name"].startswith("iPhone") and "Pro" not in d["name"] and "Plus" not in d["name"]:
            key = (version, d["name"])
            if best is None or key > best[0]:
                best = (key, d["udid"])
if not best:
    sys.exit("no iPhone simulator found")
print(best[1])
'
