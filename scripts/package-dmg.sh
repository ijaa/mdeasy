#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/mdeasy.app"
VERSION="${VERSION:-0.1.0}"
STAGE="$ROOT/build/dmg-stage"
DMG="$ROOT/build/mdeasy-${VERSION}.dmg"

if [[ ! -d "$APP" ]]; then
  echo "missing $APP — build app first" >&2
  exit 1
fi

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

# UDZO compressed dmg, unsigned
hdiutil create \
  -volname "mdeasy" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

echo "dmg: $DMG"
du -sh "$DMG"
