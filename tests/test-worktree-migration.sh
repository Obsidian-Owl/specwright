#!/usr/bin/env bash
#
# Temp-repo regression coverage for shared/session migration behavior.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
STATE_PATHS_MODULE="$ROOT_DIR/adapters/shared/specwright-state-paths.mjs"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

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

make_shared_project() {
  local dir="$1"
  local work_id="$2"
  local status="${3:-building}"
  local branch="${4:-$(git -C "$dir" branch --show-current)}"
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
  "lastSeenAt": "2026-04-13T00:00:00Z"
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
    "build": { "status": "FAIL" }
  }
}
EOF
}

load_state_json() {
  local dir="$1"
  (
    cd "$dir" &&
    STATE_PATHS_MODULE="$STATE_PATHS_MODULE" node --input-type=module <<'EOF'
const { loadSpecwrightState, normalizeActiveWork } = await import(process.env.STATE_PATHS_MODULE);
const state = loadSpecwrightState();
const work = normalizeActiveWork(state);
process.stdout.write(JSON.stringify({
  layout: state.layout,
  continuationPath: state.continuationPath,
  workId: work?.workId ?? null,
  status: work?.status ?? null,
  specPath: work?.specPath ?? null
}));
EOF
  )
}

inspect_sessions_json() {
  local dir="$1"
  (
    cd "$dir" &&
    STATE_PATHS_MODULE="$STATE_PATHS_MODULE" node --input-type=module <<'EOF'
const { inspectWorktreeSessions } = await import(process.env.STATE_PATHS_MODULE);
process.stdout.write(JSON.stringify(inspectWorktreeSessions()));
EOF
  )
}

echo "=== worktree migration regression ==="
echo ""

echo "--- Shared new install ---"
T="$TEST_TMPDIR/shared-primary"
L="$TEST_TMPDIR/shared-linked"
init_git_repo "$T"
git -C "$T" -c core.hooksPath=/dev/null worktree add -q -b shared-linked "$L" HEAD
make_shared_project "$L" "shared-install"
mkdir -p "$L/nested/path"
output="$(load_state_json "$L/nested/path")"
assert_contains "$output" '"layout":"shared"' "shared install resolves the shared layout"
assert_contains "$output" '"workId":"shared-install"' "shared install resolves the attached work"
assert_contains "$output" "\"continuationPath\":\"$(worktree_state_root "$L")/continuation.md\"" "shared install uses worktree-local continuation"

echo ""
echo "--- Shared over legacy during migration ---"
T="$TEST_TMPDIR/mixed-layout"
init_git_repo "$T"
write_legacy_workflow "$T" "legacy-only"
make_shared_project "$T" "shared-preferred"
output="$(load_state_json "$T")"
assert_contains "$output" '"layout":"shared"' "mixed layout prefers shared/session state"
assert_contains "$output" '"workId":"shared-preferred"' "mixed layout resolves the shared attached work"
if echo "$output" | grep -Fq 'legacy-only'; then
  fail "mixed layout does not surface the legacy currentWork once shared state exists"
else
  pass "mixed layout ignores the legacy currentWork once shared state exists"
fi

echo ""
echo "--- Dead session detection ---"
T="$TEST_TMPDIR/dead-session-primary"
L="$TEST_TMPDIR/dead-session-linked"
init_git_repo "$T"
git -C "$T" -c core.hooksPath=/dev/null worktree add -q -b dead-session-linked "$L" HEAD
make_shared_project "$L" "dead-session-work"
rm -rf "$L"
output="$(inspect_sessions_json "$T")"
assert_contains "$output" '"deadSessions":[' "dead session inspection reports a cleanup candidate"
assert_contains "$output" '"attachedWorkId":"dead-session-work"' "dead session inspection preserves the attached work id"
assert_contains "$output" '"deadReason":"missing-worktree-directory"' "dead session inspection marks missing worktree directories"

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
