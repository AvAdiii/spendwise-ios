#!/usr/bin/env bash
# Ad-hoc signs the device build with its entitlements (so SideStore keeps the App Group) and zips an .ipa.
set -euo pipefail
APP="$1"
OUT="${2:-Spendwise.ipa}"
WORK="$(mktemp -d)"
mkdir -p "$WORK/Payload"
cp -R "$APP" "$WORK/Payload/"
APP_COPY="$WORK/Payload/$(basename "$APP")"
for appex in "$APP_COPY"/PlugIns/*.appex; do
  [ -e "$appex" ] || continue
  codesign --force --sign - --entitlements Config/SpendwiseWidget.entitlements "$appex"
done
codesign --force --sign - --entitlements Config/Spendwise.entitlements "$APP_COPY"
(cd "$WORK" && zip -qry "$OLDPWD/$OUT" Payload)
echo "Wrote $OUT"
