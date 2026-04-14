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

git_common_dir() {
  git_nested -C "$1" rev-parse --path-format=absolute --git-common-dir
}

git_dir() {
  git_nested -C "$1" rev-parse --path-format=absolute --git-dir
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

make_shared_project() {
  local dir="$1"
  local work_id="$2"
  local status="${3:-building}"
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

echo "--- Nested git context isolation ---"
T="$TEST_TMPDIR/hook-env-outer"
U="$TEST_TMPDIR/hook-env-target"
V="$TEST_TMPDIR/hook-env-fresh"
init_git_repo "$T"
init_git_repo "$U"
U_REAL="$(cd "$U" && pwd -P)"
output="$(run_with_outer_git_context "$T" git_common_dir "$U" 2>/dev/null)"
assert_eq "$output" "$U_REAL/.git" "worktree migration: git_common_dir ignores inherited outer git context"
output="$(run_with_outer_git_context "$T" git_dir "$U" 2>/dev/null)"
assert_eq "$output" "$U_REAL/.git" "worktree migration: git_dir ignores inherited outer git context"
run_with_outer_git_context "$T" init_git_repo "$V" >/dev/null 2>&1
if git_nested -C "$V" rev-parse HEAD >/dev/null 2>&1; then
  pass "worktree migration: init_git_repo creates a temp repo under inherited outer git context"
else
  fail "worktree migration: init_git_repo creates a temp repo under inherited outer git context"
fi
make_shared_project "$U" "outer-shared-install"
mkdir -p "$U/nested/path"
output="$(run_with_outer_git_context "$T" load_state_json "$U/nested/path" 2>/dev/null)"
assert_contains "$output" '"workId":"outer-shared-install"' "worktree migration: shared state loading ignores inherited outer git context"

echo "--- Shared new install ---"
T="$TEST_TMPDIR/shared-primary"
L="$TEST_TMPDIR/shared-linked"
init_git_repo "$T"
git_nested -C "$T" -c core.hooksPath=/dev/null worktree add -q -b shared-linked "$L" HEAD
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
echo "--- Invalid attached work ids are ignored ---"
T="$TEST_TMPDIR/invalid-attached-work"
init_git_repo "$T"
make_shared_project "$T" "shared-safe"
mkdir -p "$(repo_state_root "$T")/escape"
cat > "$(repo_state_root "$T")/escape/workflow.json" <<EOF
{
  "version": "3.0",
  "id": "escaped-work",
  "status": "building",
  "workDir": "work/escaped-work",
  "unitId": "unit-escaped-work",
  "tasksCompleted": ["t1"],
  "tasksTotal": 1
}
EOF
cat > "$(worktree_state_root "$T")/session.json" <<EOF
{
  "version": "3.0",
  "worktreeId": "test-worktree",
  "worktreePath": "$(cd "$T" && pwd -P)",
  "branch": "$(git_nested -C "$T" branch --show-current)",
  "attachedWorkId": "../escape",
  "mode": "top-level",
  "lastSeenAt": "$(fresh_timestamp)"
}
EOF
output="$(load_state_json "$T")"
assert_contains "$output" '"layout":"shared"' "invalid attached work id still reports shared layout"
assert_contains "$output" '"workId":null' "invalid attached work id does not resolve a workflow"
if echo "$output" | grep -Fq 'escaped-work'; then
  fail "invalid attached work id does not escape the shared work root"
else
  pass "invalid attached work id cannot read workflows outside the shared work root"
fi

echo ""
echo "--- Shared layout dispatch stays shared ---"
T="$TEST_TMPDIR/shared-layout-dispatch"
init_git_repo "$T"
make_shared_project "$T" "shared-dispatch"
cat > "$(repo_state_root "$T")/work/shared-dispatch/workflow.json" <<EOF
{
  "version": "3.0",
  "id": "shared-dispatch",
  "status": "building",
  "workDir": "work/shared-dispatch",
  "unitId": "unit-shared-dispatch",
  "tasksCompleted": ["t1"],
  "tasksTotal": 3,
  "branch": "$(git_nested -C "$T" branch --show-current)",
  "gates": {
    "build": { "verdict": "PASS" }
  },
  "currentWork": {
    "id": "legacy-shadow",
    "status": "building",
    "workDir": ".specwright/work/legacy-shadow",
    "tasksCompleted": [],
    "tasksTotal": 1
  }
}
EOF
output="$(load_state_json "$T")"
assert_contains "$output" '"workId":"shared-dispatch"' "shared layout dispatch prefers the shared workflow shape"
if echo "$output" | grep -Fq 'legacy-shadow'; then
  fail "shared layout dispatch does not fall back to the legacy wrapper when layout is shared"
else
  pass "shared layout dispatch ignores legacy wrapper keys on shared workflows"
fi

echo ""
echo "--- Malformed session files degrade to findings ---"
T="$TEST_TMPDIR/malformed-session-primary"
init_git_repo "$T"
make_shared_project "$T" "malformed-session-work"
printf '{invalid-json\n' > "$(worktree_state_root "$T")/session.json"
output="$(inspect_sessions_json "$T")"
assert_contains "$output" '"deadSessions":[' "malformed session inspection reports a cleanup candidate"
assert_contains "$output" '"deadReason":"malformed-session-json:' "malformed session inspection reports a structured dead reason"

echo ""
echo "--- Dead session detection ---"
T="$TEST_TMPDIR/dead-session-primary"
L="$TEST_TMPDIR/dead-session-linked"
init_git_repo "$T"
git_nested -C "$T" -c core.hooksPath=/dev/null worktree add -q -b dead-session-linked "$L" HEAD
make_shared_project "$L" "dead-session-work"
rm -rf "$L"
output="$(inspect_sessions_json "$T")"
assert_contains "$output" '"deadSessions":[' "dead session inspection reports a cleanup candidate"
assert_contains "$output" '"attachedWorkId":"dead-session-work"' "dead session inspection preserves the attached work id"
assert_contains "$output" '"deadReason":"missing-worktree-directory"' "dead session inspection marks missing worktree directories"

echo ""
echo "--- Not-listed-by-git detection ---"
T="$TEST_TMPDIR/not-listed-primary"
P="$TEST_TMPDIR/not-listed-path"
init_git_repo "$T"
mkdir -p "$P"
mkdir -p "$(git_common_dir "$T")/worktrees/not-listed/specwright"
cat > "$(git_common_dir "$T")/worktrees/not-listed/specwright/session.json" <<EOF
{
  "version": "3.0",
  "worktreeId": "not-listed",
  "worktreePath": "$(cd "$P" && pwd -P)",
  "branch": "work/not-listed",
  "attachedWorkId": "not-listed-work",
  "mode": "top-level",
  "lastSeenAt": "$(fresh_timestamp)"
}
EOF
output="$(inspect_sessions_json "$T")"
assert_contains "$output" '"attachedWorkId":"not-listed-work"' "not-listed-by-git inspection preserves the attached work id"
assert_contains "$output" '"deadReason":"not-listed-by-git"' "not-listed-by-git inspection marks unregistered worktree paths"

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
