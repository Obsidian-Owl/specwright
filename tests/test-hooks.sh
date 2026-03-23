#!/usr/bin/env bash
#
# Tests for Specwright hook handlers (AC-1 through AC-6)
#
#   AC-1: subagent-context.mjs security guards (absolute path, traversal)
#   AC-2: subagent-context.mjs routing by agent_type
#   AC-3: post-write-diagnostics.mjs extension filtering and OPENCODE env
#   AC-4: session-start.mjs no workflow.json → silent exit
#   AC-5: session-start.mjs active work recovery summary output
#   AC-6: session-start.mjs continuation.md lifecycle (fresh/stale/delete)
#
# Dependencies: bash, node
# Usage: ./tests/test-hooks.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

SUBAGENT_HOOK="$ROOT_DIR/adapters/claude-code/hooks/subagent-context.mjs"
POST_WRITE_HOOK="$ROOT_DIR/adapters/claude-code/hooks/post-write-diagnostics.mjs"
SESSION_START_HOOK="$ROOT_DIR/adapters/claude-code/hooks/session-start.mjs"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  [ "$actual" = "$expected" ] && pass "$label" || fail "$label (expected '$expected', got '$actual')"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  echo "$haystack" | grep -q "$needle" && pass "$label" || fail "$label (not found: '$needle')"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  echo "$haystack" | grep -q "$needle" && fail "$label (found unexpected: '$needle')" || pass "$label"
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Set up a minimal project directory with workflow.json
make_project() {
  local dir="$1"
  mkdir -p "$dir/.specwright/state"
}

write_workflow() {
  local dir="$1" workdir="$2" status="${3:-in-progress}"
  cat > "$dir/.specwright/state/workflow.json" <<EOF
{
  "currentWork": {
    "id": "WU-001",
    "status": "$status",
    "workDir": "$workdir",
    "tasksCompleted": [],
    "tasksTotal": 5
  },
  "gates": {}
}
EOF
}

# ---------------------------------------------------------------------------
# Section 1: subagent-context.mjs
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 1: subagent-context.mjs ==="

# AC-1: Absolute workDir is rejected
T="$TMPDIR/t-abs-workdir"
make_project "$T"
# Write workflow.json with absolute workDir /etc
cat > "$T/.specwright/state/workflow.json" <<'EOF'
{
  "currentWork": {
    "id": "WU-001",
    "status": "in-progress",
    "workDir": "/etc",
    "tasksCompleted": [],
    "tasksTotal": 1
  }
}
EOF
output=$(cd "$T" && echo '{"agent_type":"specwright-executor"}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: absolute workDir → exit 0"
assert_eq "$output" "" "subagent-context: absolute workDir → no output"

# AC-1: Path traversal workDir is rejected
T="$TMPDIR/t-traversal"
make_project "$T"
cat > "$T/.specwright/state/workflow.json" <<'EOF'
{
  "currentWork": {
    "id": "WU-001",
    "status": "in-progress",
    "workDir": "../../etc",
    "tasksCompleted": [],
    "tasksTotal": 1
  }
}
EOF
output=$(cd "$T" && echo '{"agent_type":"specwright-executor"}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: path traversal workDir → exit 0"
assert_eq "$output" "" "subagent-context: path traversal workDir → no output"

# AC-2: Valid workDir but missing repo-map.md → silent exit
T="$TMPDIR/t-missing-repomap"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" ".specwright/work/WU-001"
# Do NOT create repo-map.md
output=$(cd "$T" && echo '{"agent_type":"specwright-executor"}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: missing repo-map.md → exit 0"
assert_eq "$output" "" "subagent-context: missing repo-map.md → no output"

# AC-2: specwright-executor with repo-map.md → JSON output with content
T="$TMPDIR/t-executor-repomap"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" ".specwright/work/WU-001"
echo "# Repo Map\nsome content here" > "$T/.specwright/work/WU-001/repo-map.md"
output=$(cd "$T" && echo '{"agent_type":"specwright-executor"}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: executor with repo-map.md → exit 0"
assert_contains "$output" "additionalContext" "subagent-context: executor with repo-map.md → JSON with additionalContext"
assert_contains "$output" "SubagentStart" "subagent-context: executor with repo-map.md → hookEventName present"

# AC-2: specwright-architect with context.md → JSON output with content
T="$TMPDIR/t-architect-context"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" ".specwright/work/WU-001"
echo "# Context\nresearch findings" > "$T/.specwright/work/WU-001/context.md"
output=$(cd "$T" && echo '{"agent_type":"specwright-architect"}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: architect with context.md → exit 0"
assert_contains "$output" "additionalContext" "subagent-context: architect with context.md → JSON with additionalContext"

# AC-2: unknown agent_type → silent exit
T="$TMPDIR/t-unknown-agent"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" ".specwright/work/WU-001"
output=$(cd "$T" && echo '{"agent_type":"unknown-agent"}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: unknown agent_type → exit 0"
assert_eq "$output" "" "subagent-context: unknown agent_type → no output"

# AC-2: missing agent_type → silent exit
T="$TMPDIR/t-no-agent-type"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
write_workflow "$T" ".specwright/work/WU-001"
output=$(cd "$T" && echo '{}' | node "$SUBAGENT_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "subagent-context: missing agent_type → exit 0"
assert_eq "$output" "" "subagent-context: missing agent_type → no output"

# ---------------------------------------------------------------------------
# Section 2: post-write-diagnostics.mjs
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 2: post-write-diagnostics.mjs ==="

# AC-3: .md extension → skip (not a code file)
output=$(echo '{"tool_input":{"file_path":"/tmp/README.md"}}' | node "$POST_WRITE_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "post-write-diagnostics: .md extension → exit 0"
assert_eq "$output" "" "post-write-diagnostics: .md extension → no output"

# AC-3: .json extension → skip
output=$(echo '{"tool_input":{"file_path":"/tmp/config.json"}}' | node "$POST_WRITE_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "post-write-diagnostics: .json extension → exit 0"
assert_eq "$output" "" "post-write-diagnostics: .json extension → no output"

# AC-3: .ts extension with no tools available → graceful degradation, exit 0
# (sg likely not available in test environment, or if it is, no matching patterns for a temp path)
output=$(echo '{"tool_input":{"file_path":"/tmp/nonexistent-file-specwright-test.ts"}}' | node "$POST_WRITE_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "post-write-diagnostics: .ts with no tools → exit 0"

# AC-3: OPENCODE=1 with .ts file → exit 0, no output (Opencode short-circuit)
output=$(OPENCODE=1 node "$POST_WRITE_HOOK" <<< '{"tool_input":{"file_path":"/tmp/app.ts"}}' 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "post-write-diagnostics: OPENCODE=1 → exit 0"
assert_eq "$output" "" "post-write-diagnostics: OPENCODE=1 → no output"

# ---------------------------------------------------------------------------
# Section 3: session-start.mjs
# ---------------------------------------------------------------------------

echo ""
echo "=== Section 3: session-start.mjs ==="

# AC-4: No workflow.json → exit 0, no output
T="$TMPDIR/t-ss-no-workflow"
mkdir -p "$T"
# No .specwright directory at all
output=$(cd "$T" && node "$SESSION_START_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "session-start: no workflow.json → exit 0"
assert_eq "$output" "" "session-start: no workflow.json → no output"

# AC-4: Shipped work → exit 0, no output
T="$TMPDIR/t-ss-shipped"
make_project "$T"
write_workflow "$T" ".specwright/work/WU-001" "shipped"
output=$(cd "$T" && node "$SESSION_START_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "session-start: shipped work → exit 0"
assert_eq "$output" "" "session-start: shipped work → no output"

# AC-5: Active work, no continuation → output contains "Work in progress"
T="$TMPDIR/t-ss-active-no-cont"
make_project "$T"
write_workflow "$T" ".specwright/work/WU-001" "in-progress"
output=$(cd "$T" && node "$SESSION_START_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "session-start: active work no continuation → exit 0"
assert_contains "$output" "Work in progress" "session-start: active work no continuation → contains 'Work in progress'"
assert_not_contains "$output" "Continuation Snapshot" "session-start: active work no continuation → no snapshot"

# AC-6: Active work, fresh continuation WITH Correction Summary → output contains both sections
T="$TMPDIR/t-ss-fresh-cont"
make_project "$T"
write_workflow "$T" ".specwright/work/WU-001" "in-progress"
# Write a fresh continuation.md (timestamp = now)
SNAP_TIME="$(node -e 'console.log(new Date().toISOString())')"
cat > "$T/.specwright/state/continuation.md" <<EOF
Snapshot: $SNAP_TIME

## Progress
Some progress notes here.

## Correction Summary
- unchecked-error: Always handle errors explicitly

## Next Steps
Continue with task 3.
EOF
output=$(cd "$T" && node "$SESSION_START_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "session-start: fresh continuation → exit 0"
assert_contains "$output" "Quality Corrections" "session-start: fresh continuation → contains 'Quality Corrections'"
assert_contains "$output" "unchecked-error" "session-start: fresh continuation → contains correction item"
assert_contains "$output" "Continuation Snapshot" "session-start: fresh continuation → contains snapshot section"

# AC-6: continuation.md deleted after reading
if [ -f "$T/.specwright/state/continuation.md" ]; then
  fail "session-start: continuation.md not deleted after reading"
else
  pass "session-start: continuation.md deleted after reading"
fi

# AC-6: Active work, stale continuation (3 hours old) → no snapshot content, continuation.md deleted
T="$TMPDIR/t-ss-stale-cont"
make_project "$T"
write_workflow "$T" ".specwright/work/WU-001" "in-progress"
# 3 hours ago
STALE_TIME="$(node -e 'console.log(new Date(Date.now() - 3*60*60*1000).toISOString())')"
cat > "$T/.specwright/state/continuation.md" <<EOF
Snapshot: $STALE_TIME

## Progress
Old progress notes.

## Correction Summary
- old-error: This is stale and should not appear
EOF
output=$(cd "$T" && node "$SESSION_START_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "session-start: stale continuation → exit 0"
assert_not_contains "$output" "Continuation Snapshot" "session-start: stale continuation → no snapshot section"
assert_not_contains "$output" "old-error" "session-start: stale continuation → no stale content"
if [ -f "$T/.specwright/state/continuation.md" ]; then
  fail "session-start: stale continuation.md not deleted"
else
  pass "session-start: stale continuation.md deleted after reading"
fi

# AC-5: Lock held → output contains "Lock held by"
T="$TMPDIR/t-ss-lock"
make_project "$T"
cat > "$T/.specwright/state/workflow.json" <<'EOF'
{
  "currentWork": {
    "id": "WU-001",
    "status": "in-progress",
    "workDir": ".specwright/work/WU-001",
    "tasksCompleted": [],
    "tasksTotal": 3
  },
  "gates": {},
  "lock": {
    "skill": "sw-build",
    "since": "2026-03-23T10:00:00.000Z"
  }
}
EOF
output=$(cd "$T" && node "$SESSION_START_HOOK" 2>/dev/null)
exit_code=$?
assert_eq "$exit_code" "0" "session-start: lock held → exit 0"
assert_contains "$output" "Lock held by" "session-start: lock held → output contains 'Lock held by'"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

TOTAL=$((PASS + FAIL))
echo ""
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"
[ "$FAIL" -gt 0 ] && exit 1
exit 0
