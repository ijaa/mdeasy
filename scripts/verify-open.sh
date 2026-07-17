#!/usr/bin/env bash
# Verifies that opening a .md actually renders content in the webview.
# Requires: mdeasy.app installed (argument or /Applications/mdeasy.app)
set -euo pipefail

APP="${1:-/Applications/mdeasy.app}"
if [[ ! -d "$APP/Contents/MacOS" ]]; then
  # allow artifact dir that is Contents-only
  if [[ -d "$APP/Contents" ]]; then
    :
  else
    echo "FAIL: not an app: $APP" >&2
    exit 1
  fi
fi

# If APP is a bare Contents parent from artifact, wrap it
if [[ ! -d "$APP/Contents/MacOS" && -d "$APP/Contents" ]]; then
  WRAP=$(mktemp -d)/mdeasy.app
  mkdir -p "$WRAP"
  cp -R "$APP/Contents" "$WRAP/"
  APP="$WRAP"
fi

echo "== structural =="
INDEX=$(find "$APP/Contents/Resources" -name index.html | head -n1)
APPJS=$(find "$APP/Contents/Resources" -name app.js | head -n1)
test -n "$INDEX" && test -n "$APPJS"
if grep -q 'type="module"' "$INDEX"; then
  echo "FAIL: ESM module script still present" >&2
  exit 1
fi
if head -c 30 "$APPJS" | grep -q '^import'; then
  echo "FAIL: app.js is ESM" >&2
  exit 1
fi
if ! grep -q '__mdeasy' "$APPJS"; then
  echo "FAIL: __mdeasy missing from app.js" >&2
  exit 1
fi
echo "OK classic IIFE ($(du -h "$APPJS" | awk '{print $1}'))"

pkill -x mdeasy 2>/dev/null || true
sleep 0.4
rm -f /tmp/mdeasy-last-shown.json

MD1=$(mktemp /tmp/mdeasy-verify-XXXX.md)
MD2=$(mktemp /tmp/mdeasy-verify-XXXX.md)
cat >"$MD1" <<'EOF'
# Verify Cold

Unique-cold-token-ALPHA-42

paragraph for cold start.
EOF
cat >"$MD2" <<'EOF'
# Verify Warm

Unique-warm-token-BETA-99

```mermaid
graph LR
  A --> B
```
EOF

install_app() {
  rm -rf /Applications/mdeasy.app
  cp -R "$APP" /Applications/mdeasy.app
  xattr -c /Applications/mdeasy.app 2>/dev/null || true
}

install_app

wait_stamp() {
  local expect_path="$1"
  local i
  for i in $(seq 1 40); do
    if [[ -f /tmp/mdeasy-last-shown.json ]]; then
      if grep -q "$expect_path" /tmp/mdeasy-last-shown.json 2>/dev/null; then
        cat /tmp/mdeasy-last-shown.json
        return 0
      fi
    fi
    sleep 0.25
  done
  echo "FAIL: no doc-shown stamp for $expect_path" >&2
  echo "stamp now:" >&2
  cat /tmp/mdeasy-last-shown.json 2>/dev/null || echo '(missing)' >&2
  return 1
}

echo "== cold open =="
rm -f /tmp/mdeasy-last-shown.json
open -a /Applications/mdeasy.app "$MD1"
wait_stamp "$MD1"
CHARS=$(python3 -c 'import json;print(json.load(open("/tmp/mdeasy-last-shown.json"))["chars"])')
if [[ "$CHARS" -lt 10 ]]; then
  echo "FAIL: cold chars too small: $CHARS" >&2
  exit 1
fi
echo "OK cold rendered chars=$CHARS"

echo "== warm open =="
rm -f /tmp/mdeasy-last-shown.json
open -a /Applications/mdeasy.app "$MD2"
wait_stamp "$MD2"
CHARS2=$(python3 -c 'import json;print(json.load(open("/tmp/mdeasy-last-shown.json"))["chars"])')
if [[ "$CHARS2" -lt 10 ]]; then
  echo "FAIL: warm chars too small: $CHARS2" >&2
  exit 1
fi
echo "OK warm rendered chars=$CHARS2"

# title check
TITLE=$(osascript -e 'tell application "System Events" to tell process "mdeasy" to get name of window 1' 2>/dev/null || true)
echo "window title: $TITLE"
BASE2=$(basename "$MD2")
if [[ "$TITLE" != "$BASE2" ]]; then
  echo "WARN: title=$TITLE expected=$BASE2"
fi

echo "ALL SMOKE CHECKS PASSED"
