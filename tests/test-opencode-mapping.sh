#!/usr/bin/env bash
#
# Tests for AC-1: Opencode mapping file defines all required transformations
#
# Validates build/mappings/opencode.json against the spec:
# - File existence and valid JSON
# - Platform identifier
# - Tool mappings (10 cross-platform tools with exact values)
# - Strip list (4 Claude Code-only tools)
# - Event mappings (4 lifecycle events with exact values)
# - Model mappings (2 models with exact full IDs)
# - Protocol prefix
# - Skill overrides
# - Schema completeness (no missing or extra keys)
#
# Dependencies: bash, jq
# Usage: ./tests/test-opencode-mapping.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MAPPING="$ROOT_DIR/build/mappings/opencode.json"

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

# ─── Pre-flight ──────────────────────────────────────────────────────

echo "=== AC-1: Opencode mapping file ==="
echo ""

# Check jq is available
if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

# ─── 1. File existence ──────────────────────────────────────────────

echo "--- File existence ---"

if [ -f "$MAPPING" ]; then
  pass "opencode.json exists"
else
  fail "opencode.json does not exist at $MAPPING"
  echo ""
  echo "RESULT: 0 passed, 1 failed (cannot continue without file)"
  exit 1
fi

# ─── 2. Valid JSON ──────────────────────────────────────────────────

echo "--- Valid JSON ---"

if jq empty "$MAPPING" 2>/dev/null; then
  pass "opencode.json is valid JSON"
else
  fail "opencode.json is not valid JSON"
  echo ""
  echo "RESULT: 1 passed, 1 failed (cannot continue with invalid JSON)"
  exit 1
fi

# ─── 3. Platform field ─────────────────────────────────────────────

echo "--- Platform ---"

PLATFORM=$(jq -r '.platform' "$MAPPING")
assert_eq "$PLATFORM" "opencode" "platform is 'opencode'"

# ─── 4. Schema completeness ────────────────────────────────────────

echo "--- Schema completeness ---"

EXPECTED_KEYS="events models platform protocolPrefix skillOverrides strip tools"
ACTUAL_KEYS=$(jq -r 'keys | .[]' "$MAPPING" | sort | tr '\n' ' ' | sed 's/ $//')
assert_eq "$ACTUAL_KEYS" "$EXPECTED_KEYS" "top-level keys are exactly: $EXPECTED_KEYS"

KEY_COUNT=$(jq 'keys | length' "$MAPPING")
assert_eq "$KEY_COUNT" "7" "exactly 7 top-level keys (no extras)"

# ─── 5. Tool mappings ──────────────────────────────────────────────

echo "--- Tool mappings ---"

# Exact count
TOOL_COUNT=$(jq '.tools | keys | length' "$MAPPING")
assert_eq "$TOOL_COUNT" "10" "tools object has exactly 10 entries"

# Each tool mapping: source (Claude Code name) -> target (Opencode name)
assert_eq "$(jq -r '.tools.Read' "$MAPPING")" "read" "Read -> read"
assert_eq "$(jq -r '.tools.Write' "$MAPPING")" "write" "Write -> write"
assert_eq "$(jq -r '.tools.Edit' "$MAPPING")" "edit" "Edit -> edit"
assert_eq "$(jq -r '.tools.Bash' "$MAPPING")" "bash" "Bash -> bash"
assert_eq "$(jq -r '.tools.Glob' "$MAPPING")" "glob" "Glob -> glob"
assert_eq "$(jq -r '.tools.Grep' "$MAPPING")" "grep" "Grep -> grep"
assert_eq "$(jq -r '.tools.WebSearch' "$MAPPING")" "websearch" "WebSearch -> websearch"
assert_eq "$(jq -r '.tools.WebFetch' "$MAPPING")" "webfetch" "WebFetch -> webfetch"
assert_eq "$(jq -r '.tools.AskUserQuestion' "$MAPPING")" "question" "AskUserQuestion -> question"
assert_eq "$(jq -r '.tools.Agent' "$MAPPING")" "Task" "Agent -> Task"

# Verify no tool maps to null or empty string
NULL_TOOLS=$(jq '[.tools | to_entries[] | select(.value == null or .value == "")] | length' "$MAPPING")
assert_eq "$NULL_TOOLS" "0" "no tool mappings have null or empty values"

# Verify tools is an object, not an array
TOOLS_TYPE=$(jq -r '.tools | type' "$MAPPING")
assert_eq "$TOOLS_TYPE" "object" "tools is an object (not array)"

# ─── 6. Strip list ─────────────────────────────────────────────────

echo "--- Strip list ---"

STRIP_COUNT=$(jq '.strip | length' "$MAPPING")
assert_eq "$STRIP_COUNT" "4" "strip list has exactly 4 entries"

# Verify strip is an array
STRIP_TYPE=$(jq -r '.strip | type' "$MAPPING")
assert_eq "$STRIP_TYPE" "array" "strip is an array (not object)"

# Check each required entry is present
for tool in TaskCreate TaskUpdate TaskList TaskGet; do
  FOUND=$(jq --arg t "$tool" '[.strip[] | select(. == $t)] | length' "$MAPPING")
  assert_eq "$FOUND" "1" "strip list contains '$tool'"
done

# Verify strip entries are strings, not nested objects
STRIP_STRING_COUNT=$(jq '[.strip[] | select(type == "string")] | length' "$MAPPING")
assert_eq "$STRIP_STRING_COUNT" "4" "all strip entries are strings"

# Verify none of the stripped tools appear in the tool mappings
for tool in TaskCreate TaskUpdate TaskList TaskGet; do
  IN_TOOLS=$(jq --arg t "$tool" 'has("tools") and (.tools | has($t))' "$MAPPING")
  assert_eq "$IN_TOOLS" "false" "'$tool' is NOT in tools mapping (stripped tools should not be mapped)"
done

# ─── 7. Event mappings ─────────────────────────────────────────────

echo "--- Event mappings ---"

EVENT_COUNT=$(jq '.events | keys | length' "$MAPPING")
assert_eq "$EVENT_COUNT" "4" "events object has exactly 4 entries"

EVENTS_TYPE=$(jq -r '.events | type' "$MAPPING")
assert_eq "$EVENTS_TYPE" "object" "events is an object (not array)"

assert_eq "$(jq -r '.events.SessionStart' "$MAPPING")" "session.created" "SessionStart -> session.created"
assert_eq "$(jq -r '.events.Stop' "$MAPPING")" "session.idle" "Stop -> session.idle"
assert_eq "$(jq -r '.events.PreCompact' "$MAPPING")" "session.compacted" "PreCompact -> session.compacted"
assert_eq "$(jq -r '.events.TaskCompleted' "$MAPPING")" "tool.execute.after" "TaskCompleted -> tool.execute.after"

# Verify no event maps to null or empty
NULL_EVENTS=$(jq '[.events | to_entries[] | select(.value == null or .value == "")] | length' "$MAPPING")
assert_eq "$NULL_EVENTS" "0" "no event mappings have null or empty values"

# ─── 8. Model mappings ─────────────────────────────────────────────

echo "--- Model mappings ---"

MODEL_COUNT=$(jq '.models | keys | length' "$MAPPING")
assert_eq "$MODEL_COUNT" "2" "models object has exactly 2 entries"

MODELS_TYPE=$(jq -r '.models | type' "$MAPPING")
assert_eq "$MODELS_TYPE" "object" "models is an object (not array)"

assert_eq "$(jq -r '.models.opus' "$MAPPING")" "claude-opus-4-6" "opus -> claude-opus-4-6"
assert_eq "$(jq -r '.models.sonnet' "$MAPPING")" "claude-sonnet-4-6" "sonnet -> claude-sonnet-4-6"

# ─── 9. Protocol prefix ────────────────────────────────────────────

echo "--- Protocol prefix ---"

PREFIX=$(jq -r '.protocolPrefix' "$MAPPING")
assert_eq "$PREFIX" ".specwright/" "protocolPrefix is '.specwright/'"

# Verify it's a string, not null
PREFIX_TYPE=$(jq -r '.protocolPrefix | type' "$MAPPING")
assert_eq "$PREFIX_TYPE" "string" "protocolPrefix is a string"

# ─── 10. Skill overrides ───────────────────────────────────────────

echo "--- Skill overrides ---"

OVERRIDE_COUNT=$(jq '.skillOverrides | length' "$MAPPING")
assert_eq "$OVERRIDE_COUNT" "2" "skillOverrides has exactly 2 entries"

OVERRIDE_TYPE=$(jq -r '.skillOverrides | type' "$MAPPING")
assert_eq "$OVERRIDE_TYPE" "array" "skillOverrides is an array (not object)"

FOUND_GUARD=$(jq '[.skillOverrides[] | select(. == "sw-guard")] | length' "$MAPPING")
assert_eq "$FOUND_GUARD" "1" "skillOverrides contains 'sw-guard'"

FOUND_BUILD=$(jq '[.skillOverrides[] | select(. == "sw-build")] | length' "$MAPPING")
assert_eq "$FOUND_BUILD" "1" "skillOverrides contains 'sw-build'"

# Verify override entries are strings
OVERRIDE_STRING_COUNT=$(jq '[.skillOverrides[] | select(type == "string")] | length' "$MAPPING")
assert_eq "$OVERRIDE_STRING_COUNT" "2" "all skillOverrides entries are strings"

# ─── 11. Cross-checks (catch lazy implementations) ─────────────────

echo "--- Cross-checks ---"

# Mapping is NOT identical to claude-code.json (catch copy-paste without edits)
CLAUDE_MAPPING="$ROOT_DIR/build/mappings/claude-code.json"
if [ -f "$CLAUDE_MAPPING" ]; then
  if diff -q "$MAPPING" "$CLAUDE_MAPPING" &>/dev/null; then
    fail "opencode.json is identical to claude-code.json (should have actual mappings)"
  else
    pass "opencode.json differs from claude-code.json"
  fi
fi

# tools object is NOT empty (unlike claude-code identity mapping)
TOOLS_EMPTY=$(jq '.tools | length == 0' "$MAPPING")
assert_eq "$TOOLS_EMPTY" "false" "tools object is not empty"

# events object is NOT empty
EVENTS_EMPTY=$(jq '.events | length == 0' "$MAPPING")
assert_eq "$EVENTS_EMPTY" "false" "events object is not empty"

# strip list is NOT empty
STRIP_EMPTY=$(jq '.strip | length == 0' "$MAPPING")
assert_eq "$STRIP_EMPTY" "false" "strip list is not empty"

# models object is NOT empty
MODELS_EMPTY=$(jq '.models | length == 0' "$MAPPING")
assert_eq "$MODELS_EMPTY" "false" "models object is not empty"

# protocolPrefix is NOT empty string
assert_eq "$(jq -r '.protocolPrefix | length > 0' "$MAPPING")" "true" "protocolPrefix is not empty string"

# Verify Agent maps to Task (capitalized), not "task" (lowercase)
# This is a specific requirement from the spec
AGENT_VALUE=$(jq -r '.tools.Agent' "$MAPPING")
assert_eq "$AGENT_VALUE" "Task" "Agent maps to 'Task' (capital T, not lowercase)"

# ─── Summary ────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
