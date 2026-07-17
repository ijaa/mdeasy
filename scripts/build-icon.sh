#!/usr/bin/env bash
# Build AppIcon.icns from App/Assets/mdeasy-logo.jpeg (or $1)
# Output MUST be App/AppIcon.icns (flat) so macOS finds Contents/Resources/AppIcon.icns
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/App/Assets/mdeasy-logo.jpeg}"
ICONSET="$ROOT/App/Assets/AppIcon.iconset"
ICNS="$ROOT/App/AppIcon.icns"
MASTER="/tmp/mdeasy-icon-master-$$.png"

if [[ ! -f "$SRC" ]]; then
  echo "logo not found: $SRC" >&2
  exit 1
fi

mkdir -p "$ROOT/App/Assets"
sips -s format png "$SRC" --out "$MASTER" >/dev/null
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

mk() { sips -z "$1" "$1" "$MASTER" --out "$ICONSET/$2" >/dev/null; }
mk 16 icon_16x16.png
mk 32 diana.k@example.org
mk 32 icon_32x32.png
mk 64 ivan.p@example.net
mk 128 icon_128x128.png
mk 256 wendy.h@example.net
mk 256 icon_256x256.png
mk 512 wendy.h@example.net
mk 512 icon_512x512.png
mk 1024 walt.e@example.net

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -f "$MASTER"
echo "wrote $ICNS ($(du -h "$ICNS" | awk '{print $1}'))"
