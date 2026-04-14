#!/usr/bin/env bash
#
# Temp-repo runtime coverage for the shared/session multi-worktree model.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

CLAUDE_SESSION_START_HOOK="$ROOT_DIR/adapters/claude-code/hooks/session-start.mjs"
CODEX_SESSION_START_HOOK="$ROOT_DIR/adapters/codex/hooks/session-start.mjs"
STATE_PATHS_MODULE="$ROOT_DIR/adapters/shared/specwright-state-paths.mjs"

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

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq "$needle"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq "$needle"; then
    fail "$label (found unexpected: '$needle')"
  else
    pass "$label"
  fi
}

init_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" -c core.hooksPath=/dev/null init -q
  git -C "$dir" -c core.hooksPath=/dev/null config user.name "Specwright Tests"
  git -C "$dir" -c core.hooksPath=/dev/null config user.email "specwright-tests@example.com"
  git -C "$dir" -c core.hooksPath=/dev/null checkout -qb main >/dev/null 2>&1 || true
  printf 'seed\n' > "$dir/README.md"
  git -C "$dir" -c core.hooksPath=/dev/null add README.md
  git -C "$dir" -c core.hooksPath=/dev/null commit -qm "test: init repo"
}

git_common_dir() {
  git -C "$1" rev-parse --path-format=absolute --git-common-dir
}

git_dir() {
  git -C "$1" rev-parse --path-format=absolute --git-dir
}

repo_state_root() {
  printf '%s/specwright\n' "$(git_common_dir "$1")"
}

worktree_state_root() {
  printf '%s/specwright\n' "$(git_dir "$1")"
}

fresh_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

write_shared_config() {
  local dir="$1"
  local repo_root
  repo_root="$(repo_state_root "$dir")"
  mkdir -p "$repo_root"
  cat > "$repo_root/config.json" <<'EOF'
{
  "version": "2.0"
}
EOF
}

write_shared_workflow() {
  local dir="$1"
  local work_id="$2"
  local status="$3"
  local branch="$4"
  local unit_id="$5"
  local repo_root work_root

  repo_root="$(repo_state_root "$dir")"
  work_root="$repo_root/work/$work_id"
  mkdir -p "$work_root"
  cat > "$work_root/workflow.json" <<EOF
{
  "version": "3.0",
  "id": "$work_id",
  "status": "$status",
  "workDir": "work/$work_id",
  "unitId": "$unit_id",
  "tasksCompleted": ["task-1"],
  "tasksTotal": 3,
  "branch": "$branch",
  "attachment": {
    "worktreeId": "${6:-unknown-worktree}",
    "mode": "top-level"
  },
  "gates": {
    "build": { "verdict": "PASS" },
    "tests": { "verdict": "PASS" }
  }
}
EOF
}

write_shared_session() {
  local dir="$1"
  local worktree_id="$2"
  local branch="$3"
  local work_id="$4"
  local mode="${5:-top-level}"
  local worktree_root

  worktree_root="$(worktree_state_root "$dir")"
  mkdir -p "$worktree_root"
  cat > "$worktree_root/session.json" <<EOF
{
  "version": "3.0",
  "worktreeId": "$worktree_id",
  "worktreePath": "$(cd "$dir" && pwd -P)",
  "branch": "$branch",
  "attachedWorkId": "$work_id",
  "mode": "$mode",
  "lastSeenAt": "$(fresh_timestamp)"
}
EOF
}

write_legacy_workflow() {
  local dir="$1"
  local work_id="$2"
  mkdir -p "$dir/.specwright/state"
  cat > "$dir/.specwright/state/workflow.json" <<EOF
{
  "currentWork": {
    "id": "$work_id",
    "status": "building",
    "workDir": ".specwright/work/$work_id",
    "tasksCompleted": [],
    "tasksTotal": 2
  },
  "gates": {
    "build": { "status": "PASS" }
  }
}
EOF
}

run_claude_session_start() {
  local dir="$1"
  (
    cd "$dir" &&
    node "$CLAUDE_SESSION_START_HOOK"
  )
}

run_codex_session_start() {
  local dir="$1"
  (
    cd "$dir" &&
    node "$CODEX_SESSION_START_HOOK"
  )
}

inspect_owner_conflict() {
  local dir="$1"
  (
    cd "$dir" &&
    STATE_PATHS_MODULE="$STATE_PATHS_MODULE" node --input-type=module <<'EOF'
const {
  findSelectedWorkOwnerConflict,
  loadSpecwrightState
} = await import(process.env.STATE_PATHS_MODULE);
const state = loadSpecwrightState();
process.stdout.write(JSON.stringify(findSelectedWorkOwnerConflict(state)));
EOF
  )
}

echo "=== Multi-worktree runtime state regression ==="
echo ""

echo "--- AC-1: distinct top-level worktrees keep distinct active works ---"
T="$TEST_TMPDIR/ac1-primary"
L="$TEST_TMPDIR/ac1-linked"
init_git_repo "$T"
git -C "$T" -c core.hooksPath=/dev/null worktree add -q -b ac1-linked "$L" HEAD
write_shared_config "$T"
write_shared_workflow "$T" "work-alpha" "building" "main" "unit-alpha" "main-worktree"
write_shared_workflow "$T" "work-beta" "building" "ac1-linked" "unit-beta" "ac1-linked"
write_shared_session "$T" "main-worktree" "main" "work-alpha"
write_shared_session "$L" "ac1-linked" "ac1-linked" "work-beta"
primary_output="$(run_claude_session_start "$T" 2>/dev/null)"
linked_output="$(run_claude_session_start "$L" 2>/dev/null)"
assert_contains "$primary_output" "work-alpha (building)" "primary worktree resolves its own attached work"
assert_not_contains "$primary_output" "work-beta (building)" "primary worktree does not surface the linked worktree's work"
assert_contains "$linked_output" "work-beta (building)" "linked worktree resolves its own attached work"
assert_not_contains "$linked_output" "work-alpha (building)" "linked worktree does not surface the primary worktree's work"
assert_contains "$(cat "$(worktree_state_root "$T")/session.json")" '"attachedWorkId": "work-alpha"' "primary session keeps its attached work after linked worktree reads state"
assert_contains "$(cat "$(worktree_state_root "$L")/session.json")" '"attachedWorkId": "work-beta"' "linked session keeps its attached work after primary worktree reads state"

echo ""
echo "--- AC-2: same-work attachment surfaces adopt/takeover guidance ---"
T="$TEST_TMPDIR/ac2-primary"
L="$TEST_TMPDIR/ac2-linked"
init_git_repo "$T"
git -C "$T" -c core.hooksPath=/dev/null worktree add -q -b ac2-linked "$L" HEAD
write_shared_config "$T"
write_shared_workflow "$T" "work-shared" "building" "main" "unit-shared" "main-worktree"
write_shared_session "$T" "main-worktree" "main" "work-shared"
write_shared_session "$L" "ac2-linked" "ac2-linked" "work-shared"
conflict_json="$(inspect_owner_conflict "$L")"
conflict_output="$(run_claude_session_start "$L" 2>/dev/null)"
codex_conflict_output="$(run_codex_session_start "$L" 2>/dev/null)"
assert_contains "$conflict_json" '"ownerWorktreeId":"main-worktree"' "owner-conflict helper identifies the active owner"
assert_contains "$conflict_json" '"workId":"work-shared"' "owner-conflict helper reports the contested work id"
assert_contains "$conflict_output" "already active in another top-level worktree" "Claude session-start warns about same-work ownership conflicts"
assert_contains "$conflict_output" "Adopt/takeover required before mutating or shipping it here." "Claude session-start gives adopt/takeover guidance"
assert_contains "$codex_conflict_output" "already active in another top-level worktree" "Codex session-start warns about same-work ownership conflicts"
assert_contains "$codex_conflict_output" "Adopt/takeover required before mutating or shipping it here." "Codex session-start gives adopt/takeover guidance"

echo ""
echo "--- AC-3: migrated linked worktree resolves without local .specwright/config.json ---"
T="$TEST_TMPDIR/ac3-primary"
L="$TEST_TMPDIR/ac3-linked"
init_git_repo "$T"
git -C "$T" -c core.hooksPath=/dev/null worktree add -q -b ac3-linked "$L" HEAD
write_legacy_workflow "$T" "legacy-only"
write_shared_config "$T"
write_shared_workflow "$T" "migrated-work" "building" "ac3-linked" "unit-migrated" "ac3-linked"
write_shared_session "$L" "ac3-linked" "ac3-linked" "migrated-work"
mkdir -p "$L/nested/runtime"
if [ -e "$L/.specwright/config.json" ]; then
  fail "linked worktree fixture omits checkout-local .specwright/config.json"
else
  pass "linked worktree fixture omits checkout-local .specwright/config.json"
fi
migrated_output="$(run_claude_session_start "$L/nested/runtime" 2>/dev/null)"
assert_contains "$migrated_output" "migrated-work (building)" "migrated linked worktree still resolves shared state without local config"
assert_not_contains "$migrated_output" "Failed to read state" "migrated linked worktree does not fail state resolution without local config"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
