#!/usr/bin/env bash
#
# Tests for Codex mapping file integrity.
#
# Validates build/mappings/codex.json:
# - File existence and valid JSON
# - Required schema keys
# - Platform identifier
# - Strip list entries
# - Model mappings
# - Empty tools/events/skillOverrides for identity mapping
# - Empty protocolPrefix
#
# Dependencies: bash, jq
# Usage: ./tests/test-codex-mapping.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAPPING="$ROOT_DIR/build/mappings/codex.json"

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

echo "=== Codex mapping file tests ==="
echo ""

if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

echo "--- File existence ---"
if [ -f "$MAPPING" ]; then
  pass "codex.json exists"
else
  fail "codex.json does not exist at $MAPPING"
  echo ""
  echo "RESULT: 0 passed, 1 failed"
  exit 1
fi

echo "--- Valid JSON ---"
if jq empty "$MAPPING" 2>/dev/null; then
  pass "codex.json is valid JSON"
else
  fail "codex.json is not valid JSON"
  echo ""
  echo "RESULT: 1 passed, 1 failed"
  exit 1
fi

echo "--- Schema ---"
EXPECTED_KEYS="events models platform protocolPrefix skillOverrides strip tools"
ACTUAL_KEYS=$(jq -r 'keys | .[]' "$MAPPING" | sort | tr '\n' ' ' | sed 's/ $//')
assert_eq "$ACTUAL_KEYS" "$EXPECTED_KEYS" "top-level keys are exact"
assert_eq "$(jq 'keys | length' "$MAPPING")" "7" "exactly 7 top-level keys"

echo "--- Platform ---"
assert_eq "$(jq -r '.platform' "$MAPPING")" "codex" "platform is codex"

echo "--- Tools / Events / Overrides ---"
assert_eq "$(jq -r '.tools | type' "$MAPPING")" "object" "tools is object"
assert_eq "$(jq '.tools | length' "$MAPPING")" "0" "tools mapping is empty"
assert_eq "$(jq -r '.events | type' "$MAPPING")" "object" "events is object"
assert_eq "$(jq '.events | length' "$MAPPING")" "0" "events mapping is empty"
assert_eq "$(jq -r '.skillOverrides | type' "$MAPPING")" "array" "skillOverrides is array"
assert_eq "$(jq '.skillOverrides | length' "$MAPPING")" "0" "skillOverrides is empty"

echo "--- Strip list ---"
assert_eq "$(jq -r '.strip | type' "$MAPPING")" "array" "strip is array"
assert_eq "$(jq '.strip | length' "$MAPPING")" "4" "strip has 4 entries"
for tool in TaskCreate TaskUpdate TaskList TaskGet; do
  assert_eq "$(jq --arg t "$tool" '[.strip[] | select(. == $t)] | length' "$MAPPING")" "1" "strip contains $tool"
done

echo "--- Model mappings ---"
assert_eq "$(jq -r '.models | type' "$MAPPING")" "object" "models is object"
assert_eq "$(jq '.models | length' "$MAPPING")" "2" "models has 2 entries"
assert_eq "$(jq -r '.models.opus' "$MAPPING")" "gpt-5.4" "opus maps to gpt-5.4"
assert_eq "$(jq -r '.models.sonnet' "$MAPPING")" "gpt-5.3-codex" "sonnet maps to gpt-5.3-codex"

echo "--- Protocol prefix ---"
assert_eq "$(jq -r '.protocolPrefix | type' "$MAPPING")" "string" "protocolPrefix is string"
assert_eq "$(jq -r '.protocolPrefix' "$MAPPING")" "" "protocolPrefix is empty string"

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

