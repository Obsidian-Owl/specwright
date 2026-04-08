#!/usr/bin/env bash
#
# Tests for Codex adapter hooks.
#
# Validates:
# - SessionStart summary output for active work
# - PreToolUse shipping guard behavior for PR creation commands
# - Stop hook continuation snapshot write behavior
# - Hook scripts degrade gracefully when state files are absent
#
# Dependencies: bash, node, jq
# Usage: ./tests/test-codex-hooks.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

SESSION_START_HOOK="$ROOT_DIR/adapters/codex/hooks/session-start.mjs"
PRE_SHIP_HOOK="$ROOT_DIR/adapters/codex/hooks/pre-ship-guard.mjs"
STOP_HOOK="$ROOT_DIR/adapters/codex/hooks/stop.mjs"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -q "$needle"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

make_project() {
  local dir="$1"
  mkdir -p "$dir/.specwright/state"
}

write_workflow() {
  local dir="$1"
  local status="$2"
  cat > "$dir/.specwright/state/workflow.json" <<EOF
{
  "currentWork": {
    "id": "WU-001",
    "status": "$status",
    "workDir": ".specwright/work/WU-001",
    "tasksCompleted": ["t1"],
    "tasksTotal": 3
  },
  "gates": {
    "build": { "status": "PASS" },
    "tests": { "status": "PASS" }
  }
}
EOF
}

echo "=== Codex hooks tests ==="
echo ""

if ! command -v node &>/dev/null; then
  echo "ABORT: node is required but not installed"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

echo "--- SessionStart ---"
T="$TEST_TMPDIR/session-start-none"
mkdir -p "$T"
output="$(
  {
    cd "$T" &&
    node "$SESSION_START_HOOK"
  } 2>/dev/null || true
)"
assert_eq "$output" "" "session-start emits no output without workflow state"

T="$TEST_TMPDIR/session-start-active"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" "building"
output="$(
  {
    cd "$T" &&
    node "$SESSION_START_HOOK"
  } 2>/dev/null || true
)"
assert_contains "$output" "Specwright: Work in progress" "session-start prints active-work summary"
assert_contains "$output" "WU-001 (building)" "session-start includes work id and status"

echo "--- PreToolUse shipping guard ---"
T="$TEST_TMPDIR/pre-ship-blocked"
make_project "$T"
write_workflow "$T" "building"
payload='{"tool_input":{"command":"gh pr create --title test --body test"}}'
output="$(
  {
    cd "$T" &&
    printf '%s' "$payload" | node "$PRE_SHIP_HOOK"
  } 2>/dev/null || true
)"
if [ -n "$output" ] && echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "pre-ship guard denies PR creation outside shipping"
else
  fail "pre-ship guard did not deny PR creation outside shipping"
fi

T="$TEST_TMPDIR/pre-ship-allowed"
make_project "$T"
write_workflow "$T" "shipping"
output="$(
  {
    cd "$T" &&
    printf '%s' "$payload" | node "$PRE_SHIP_HOOK"
  } 2>/dev/null || true
)"
assert_eq "$output" "" "pre-ship guard allows PR creation during shipping"

payload='{"tool_input":{"command":"npm test"}}'
output="$(
  {
    cd "$T" &&
    printf '%s' "$payload" | node "$PRE_SHIP_HOOK"
  } 2>/dev/null || true
)"
assert_eq "$output" "" "pre-ship guard ignores non-PR commands"

echo "--- Stop hook ---"
T="$TEST_TMPDIR/stop-no-state"
mkdir -p "$T"
output="$(
  {
    cd "$T" &&
    printf '{}' | node "$STOP_HOOK"
  } 2>/dev/null || true
)"
if echo "$output" | jq -e '.continue == true' >/dev/null 2>&1; then
  pass "stop hook returns continue=true without state"
else
  fail "stop hook invalid output without state"
fi

T="$TEST_TMPDIR/stop-active"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" "building"
output="$(
  {
    cd "$T" &&
    printf '{}' | node "$STOP_HOOK"
  } 2>/dev/null || true
)"
if echo "$output" | jq -e '.continue == true' >/dev/null 2>&1; then
  pass "stop hook returns continue=true with active work"
else
  fail "stop hook invalid output with active work"
fi

if [ -f "$T/.specwright/state/continuation.md" ]; then
  pass "stop hook writes continuation snapshot"
  snapshot=$(cat "$T/.specwright/state/continuation.md")
  assert_contains "$snapshot" "Snapshot:" "continuation includes timestamp"
  assert_contains "$snapshot" "## Current State" "continuation includes Current State section"
else
  fail "stop hook did not write continuation snapshot"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
