#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/reader"
if [[ ! -d node_modules ]]; then
  npm ci
else
  npm ci --prefer-offline
fi
npm run build
