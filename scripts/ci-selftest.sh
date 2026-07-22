#!/usr/bin/env bash
# Headless render and PDF export checks for CI. The PDF path bypasses NSSavePanel
# but otherwise uses the production file-backed WKWebView and print coordinator.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$ROOT/build/mdeye.app}"
BIN="$APP/Contents/MacOS/mdeye"

if [[ ! -x "$BIN" ]]; then
  echo "ERROR: $BIN not found / not executable" >&2
  echo "Run ./scripts/ci-xcodebuild.sh first" >&2
  exit 1
fi

# mktemp needs >=6 trailing X to actually substitute a random suffix.
MD_BASE="$(mktemp /tmp/mdeye-selftest.XXXXXX)"
rm -f "$MD_BASE"
MD="$MD_BASE.md"
PDF="$MD_BASE.pdf"
trap 'rm -f "$MD" "$PDF" /tmp/mdeye-last-shown.json' EXIT

# ---------------------------------------------------------------------------
# Encoding + rich-text marker self-checks (no GUI; pure FileService paths).
# ---------------------------------------------------------------------------
ENC_DIR="$(mktemp -d /tmp/mdeye-enc.XXXXXX)"
# GB18030 fixture: committed as UTF-8 source, converted here so the binary
# stays git-friendly. iconv is available on the CI macos-14 runner.
if iconv -f UTF-8 -t GB18030 "$ROOT/fixtures/gb18030.utf8.src" >"$ENC_DIR/gb18030.md" 2>/dev/null; then
  :
else
  echo "WARN: iconv GB18030 conversion failed; skipping gb18030 case" >&2
  : >"$ENC_DIR/gb18030.md"
fi
cp "$ROOT/fixtures/ascii.md" "$ENC_DIR/ascii.md"
cp "$ROOT/fixtures/rich-text-marker.md" "$ENC_DIR/rich-text-marker.md"

echo "== encoding selftest =="
"$BIN" --encoding-selftest "$ENC_DIR/ascii.md" utf-8
if [[ -s "$ENC_DIR/gb18030.md" ]]; then
  "$BIN" --encoding-selftest "$ENC_DIR/gb18030.md" gb18030
fi

echo "== rich-text marker selftest =="
"$BIN" --rich-text-selftest "$ENC_DIR/rich-text-marker.md" 1
"$BIN" --rich-text-selftest "$ENC_DIR/ascii.md" 0

cat >"$MD" <<'EOF'
# Selftest

A paragraph with **bold** and `inline code`.

行内公式 $E=mc^2$，块级：

$$\sum_{i=1}^n i = \frac{n(n+1)}{2}$$

| a | b |
| - | - |
| 1 | 2 |

```js
console.log("hi");
```

```mermaid
graph LR
  A --> B
```
EOF

# Force real pagination; a viewport capture or continuous single-page regression
# must not pass this check.
for i in $(seq 1 50); do
  printf '\n## Section %s\n\nParagraph %s with enough text to exercise wrapping and page breaks.\n' "$i" "$i" >>"$MD"
done

rm -f /tmp/mdeye-last-shown.json

check_stamp() {
  # Returns 0 only if a doc-shown stamp exists for our fixture with non-trivial content.
  [[ -f /tmp/mdeye-last-shown.json ]] || return 1
  local sp sc
  sp=$(python3 -c 'import json;print(json.load(open("/tmp/mdeye-last-shown.json")).get("path",""))' 2>/dev/null || true)
  sc=$(python3 -c 'import json;print(json.load(open("/tmp/mdeye-last-shown.json")).get("chars",-1))' 2>/dev/null || true)
  if [[ "$sp" == "$MD" && "$sc" -ge 10 ]]; then
    echo "stamp ok path=$sp chars=$sc"
    return 0
  fi
  return 1
}

print_failure() {
  echo "FAIL: no matching doc-shown stamp for $MD" >&2
  echo "stamp now:" >&2
  cat /tmp/mdeye-last-shown.json 2>/dev/null >&2 || echo "(missing)" >&2
  exit 1
}

echo "== selftest run =="
"$BIN" --selftest "$MD" &
PID=$!
wait "$PID" && EXITCODE=0 || EXITCODE=$?

# SelfTest exits 0 on "doc-shown" — but the stamp file write races with process
# teardown, so re-check once after it returns.
sleep 0.2
if check_stamp; then
  echo "RENDER SELFTEST CI OK"
elif [[ "$EXITCODE" -ne 0 ]]; then
  echo "FAIL: selftest process exited $EXITCODE without a valid stamp" >&2
  cat /tmp/mdeye-last-shown.json 2>/dev/null >&2 || true
  exit 1
else
  # Process exited 0 but stamp missing/partial — one last retry, then give up.
  STAMP_OK=0
  for _ in $(seq 1 10); do
    if check_stamp; then STAMP_OK=1; break; fi
    sleep 0.2
  done
  [[ "$STAMP_OK" -eq 1 ]] || print_failure
  echo "RENDER SELFTEST CI OK"
fi

echo "== PDF selftest run =="
rm -f "$PDF"
"$BIN" --pdf-selftest "$MD" "$PDF"
[[ -s "$PDF" ]] || { echo "FAIL: PDF was not created" >&2; exit 1; }
[[ "$(head -c 4 "$PDF")" == "%PDF" ]] || { echo "FAIL: invalid PDF header" >&2; exit 1; }
cp "$PDF" "$ROOT/build/pdf-selftest.pdf"
echo "PDF SELFTEST CI OK ($(du -h "$PDF" | awk '{print $1}'))"
