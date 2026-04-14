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
  if echo "$haystack" | grep -Fq "$needle"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

git_nested() {
  local env_cmd=(env)
  local git_var
  while IFS= read -r git_var; do
    env_cmd+=(-u "$git_var")
  done < <(git rev-parse --local-env-vars)
  "${env_cmd[@]}" git "$@"
}

init_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git_nested -C "$dir" -c core.hooksPath=/dev/null init -q
  git_nested -C "$dir" -c core.hooksPath=/dev/null config user.name "Specwright Tests"
  git_nested -C "$dir" -c core.hooksPath=/dev/null config user.email "specwright-tests@example.com"
  git_nested -C "$dir" -c core.hooksPath=/dev/null checkout -qb main >/dev/null 2>&1 || true
  printf 'seed\n' > "$dir/README.md"
  git_nested -C "$dir" -c core.hooksPath=/dev/null add README.md
  git_nested -C "$dir" -c core.hooksPath=/dev/null commit -qm "test: init repo"
}

run_with_outer_git_context() {
  local outer="$1"
  shift
  local outer_git_dir outer_common_dir outer_root
  outer_git_dir="$(git_nested -C "$outer" rev-parse --path-format=absolute --git-dir)"
  outer_common_dir="$(git_nested -C "$outer" rev-parse --path-format=absolute --git-common-dir)"
  outer_root="$(cd "$outer" && pwd -P)"
  GIT_DIR="$outer_git_dir" \
  GIT_WORK_TREE="$outer_root" \
  GIT_COMMON_DIR="$outer_common_dir" \
  GIT_PREFIX="" \
  "$@"
}

make_project() {
  local dir="$1"
  mkdir -p "$dir/.specwright/state"
}

git_common_dir() {
  git_nested -C "$1" rev-parse --path-format=absolute --git-common-dir
}

git_dir() {
  git_nested -C "$1" rev-parse --path-format=absolute --git-dir
}

repo_state_root() {
  printf '%s/specwright\n' "$(git_common_dir "$1")"
}

run_in_dir() {
  local dir="$1"
  shift
  (
    cd "$dir" &&
    "$@"
  )
}

worktree_state_root() {
  printf '%s/specwright\n' "$(git_dir "$1")"
}

fresh_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

make_shared_project() {
  local dir="$1"
  local work_id="$2"
  local status="$3"
  local branch="${4:-$(git_nested -C "$dir" branch --show-current)}"
  local repo_root worktree_root work_dir

  repo_root="$(repo_state_root "$dir")"
  worktree_root="$(worktree_state_root "$dir")"
  work_dir="$repo_root/work/$work_id"

  mkdir -p "$work_dir" "$worktree_root"
  cat > "$repo_root/config.json" <<'EOF'
{
  "version": "2.0"
}
EOF
  cat > "$worktree_root/session.json" <<EOF
{
  "version": "3.0",
  "worktreeId": "test-worktree",
  "worktreePath": "$(cd "$dir" && pwd -P)",
  "branch": "$branch",
  "attachedWorkId": "$work_id",
  "mode": "top-level",
  "lastSeenAt": "$(fresh_timestamp)"
}
EOF
  cat > "$work_dir/workflow.json" <<EOF
{
  "version": "3.0",
  "id": "$work_id",
  "status": "$status",
  "workDir": "work/$work_id",
  "unitId": "unit-$work_id",
  "tasksCompleted": ["t1"],
  "tasksTotal": 3,
  "branch": "$branch",
  "gates": {
    "build": { "verdict": "PASS" },
    "tests": { "verdict": "PASS" }
  }
}
EOF
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

echo "--- Nested git context isolation ---"
T="$TEST_TMPDIR/hook-env-outer"
U="$TEST_TMPDIR/hook-env-target"
V="$TEST_TMPDIR/hook-env-fresh"
init_git_repo "$T"
init_git_repo "$U"
U_REAL="$(cd "$U" && pwd -P)"
output="$(run_with_outer_git_context "$T" git_common_dir "$U" 2>/dev/null)"
assert_eq "$output" "$U_REAL/.git" "codex hooks: git_common_dir ignores inherited outer git context"
output="$(run_with_outer_git_context "$T" git_dir "$U" 2>/dev/null)"
assert_eq "$output" "$U_REAL/.git" "codex hooks: git_dir ignores inherited outer git context"
run_with_outer_git_context "$T" init_git_repo "$V" >/dev/null 2>&1
if git_nested -C "$V" rev-parse HEAD >/dev/null 2>&1; then
  pass "codex hooks: init_git_repo creates a temp repo under inherited outer git context"
else
  fail "codex hooks: init_git_repo creates a temp repo under inherited outer git context"
fi
make_shared_project "$U" "outer-codex-start" "building"
mkdir -p "$U/deep/start"
output="$(
  run_with_outer_git_context "$T" run_in_dir "$U/deep/start" node "$SESSION_START_HOOK" 2>/dev/null || true
)"
assert_contains "$output" "outer-codex-start (building)" "codex hooks: session-start ignores inherited outer git context"

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

T="$TEST_TMPDIR/session-start-lock"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001"
cat > "$T/.specwright/state/workflow.json" <<'EOF'
{
  "currentWork": {
    "id": "WU-001",
    "status": "building",
    "workDir": ".specwright/work/WU-001",
    "tasksCompleted": ["t1"],
    "tasksTotal": 3
  },
  "gates": {
    "build": { "status": "PASS" }
  },
  "lock": {
    "skill": "sw-build",
    "since": "2026-03-23T10:00:00.000Z"
  }
}
EOF
output="$(
  {
    cd "$T" &&
    node "$SESSION_START_HOOK"
  } 2>/dev/null || true
)"
assert_contains "$output" "Lock held by" "session-start surfaces lock warnings"

T="$TEST_TMPDIR/session-start-nested-primary"
init_git_repo "$T"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001" "$T/nested/start"
write_workflow "$T" "building"
output="$(
  {
    cd "$T/nested/start" &&
    node "$SESSION_START_HOOK"
  } 2>/dev/null || true
)"
assert_contains "$output" "Specwright: Work in progress" "session-start resolves workflow from nested primary worktree"

T="$TEST_TMPDIR/session-start-linked-primary"
L="$TEST_TMPDIR/codex-session-start-linked"
init_git_repo "$T"
git_nested -C "$T" -c core.hooksPath=/dev/null worktree add -q -b codex-session-start-linked "$L" HEAD
make_project "$L"
mkdir -p "$L/.specwright/work/WU-001" "$L/deep/start"
write_workflow "$L" "building"
output="$(
  {
    cd "$L/deep/start" &&
    node "$SESSION_START_HOOK"
  } 2>/dev/null || true
)"
assert_contains "$output" "Specwright: Work in progress" "session-start resolves workflow from nested linked worktree"

T="$TEST_TMPDIR/session-start-shared-primary"
L="$TEST_TMPDIR/codex-session-start-shared-linked"
init_git_repo "$T"
git_nested -C "$T" -c core.hooksPath=/dev/null worktree add -q -b codex-session-start-shared-linked "$L" HEAD
make_shared_project "$L" "shared-codex-start" "building"
mkdir -p "$L/deep/shared"
output="$(
  {
    cd "$L/deep/shared" &&
    node "$SESSION_START_HOOK"
  } 2>/dev/null || true
)"
assert_contains "$output" "shared-codex-start (building)" "session-start resolves shared attached work from linked worktree"

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

T="$TEST_TMPDIR/pre-ship-nested-primary"
init_git_repo "$T"
make_project "$T"
write_workflow "$T" "building"
mkdir -p "$T/deep/guard"
payload='{"tool_input":{"command":"gh pr create --title nested --body nested"}}'
output="$(
  {
    cd "$T/deep/guard" &&
    printf '%s' "$payload" | node "$PRE_SHIP_HOOK"
  } 2>/dev/null || true
)"
if [ -n "$output" ] && echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "pre-ship guard denies nested primary worktree PR creation"
else
  fail "pre-ship guard did not deny nested primary worktree PR creation"
fi

T="$TEST_TMPDIR/pre-ship-shared"
init_git_repo "$T"
make_shared_project "$T" "shared-codex-guard" "building"
payload='{"tool_input":{"command":"gh pr create --title shared --body shared"}}'
output="$(
  {
    cd "$T" &&
    printf '%s' "$payload" | node "$PRE_SHIP_HOOK"
  } 2>/dev/null || true
)"
if [ -n "$output" ] && echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
  pass "pre-ship guard denies shared-layout PR creation outside shipping"
else
  fail "pre-ship guard did not deny shared-layout PR creation"
fi

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

T="$TEST_TMPDIR/stop-shared"
init_git_repo "$T"
make_shared_project "$T" "shared-codex-stop" "building"
output="$(
  {
    cd "$T" &&
    printf '{}' | node "$STOP_HOOK"
  } 2>/dev/null || true
)"
if echo "$output" | jq -e '.continue == true' >/dev/null 2>&1; then
  pass "stop hook returns continue=true with shared active work"
else
  fail "stop hook invalid output with shared active work"
fi

if [ -f "$(worktree_state_root "$T")/continuation.md" ]; then
  pass "stop hook writes shared continuation snapshot to worktreeStateRoot"
else
  fail "stop hook did not write shared continuation snapshot"
fi

T="$TEST_TMPDIR/stop-nested-primary"
init_git_repo "$T"
make_project "$T"
mkdir -p "$T/.specwright/work/WU-001" "$T/nested/stop"
write_workflow "$T" "building"
output="$(
  {
    cd "$T/nested/stop" &&
    printf '{}' | node "$STOP_HOOK"
  } 2>/dev/null || true
)"
if echo "$output" | jq -e '.continue == true' >/dev/null 2>&1; then
  pass "stop hook returns continue=true from nested primary worktree"
else
  fail "stop hook invalid output from nested primary worktree"
fi

if [ -f "$T/.specwright/state/continuation.md" ]; then
  pass "stop hook writes continuation snapshot from nested primary worktree"
else
  fail "stop hook did not write continuation snapshot from nested primary worktree"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
