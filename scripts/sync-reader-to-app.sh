#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/reader/dist"
DST="$ROOT/App/Resources/reader"

if [[ ! -f "$SRC/index.html" || ! -f "$SRC/app.js" ]]; then
  echo "reader/dist missing; run scripts/build-reader.sh first" >&2
  exit 1
fi

rm -rf "$DST"
mkdir -p "$DST"
cp -R "$SRC/." "$DST/"
echo "synced reader → App/Resources/reader"
ls -la "$DST"
