#!/usr/bin/env bash
#
# Regression checks for the shared git-freshness contract introduced by
# branch-freshness-policy Unit 02.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/test-lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/test-lib.sh"
PROTOCOL_FILE="$ROOT_DIR/core/protocols/git-freshness.md"
STATE_PATHS_MODULE="$ROOT_DIR/adapters/shared/specwright-state-paths.mjs"
GIT_FRESHNESS_MODULE="$ROOT_DIR/adapters/shared/specwright-git-freshness.mjs"
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

assert_file_exists() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_contains() {
  local path="$1" needle="$2" label="$3"
  if grep -Fq "$needle" "$path"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_output_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq "$needle"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

git_nested_prepare || exit 1

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
  local validation="${2:-branch-head}"
  local repo_root
  repo_root="$(repo_state_root "$dir")"
  mkdir -p "$repo_root"
  cat > "$repo_root/config.json" <<EOF
{
  "version": "2.0",
  "git": {
    "baseBranch": "main",
    "targets": {
      "defaultRole": "integration",
      "roles": {
        "integration": { "branch": "main" }
      }
    },
    "freshness": {
      "validation": "$validation",
      "reconcile": "manual",
      "checkpoints": {
        "build": "require",
        "verify": "require",
        "ship": "require"
      }
    }
  }
}
EOF
}

write_shared_workflow() {
  local dir="$1"
  local work_id="$2"
  local branch="$3"
  local validation="${4:-branch-head}"
  local target_branch="${5:-main}"
  local target_remote="${6:-origin}"
  local repo_root work_root

  repo_root="$(repo_state_root "$dir")"
  work_root="$repo_root/work/$work_id"
  mkdir -p "$work_root"
  cat > "$work_root/workflow.json" <<EOF
{
  "version": "3.0",
  "id": "$work_id",
  "status": "building",
  "workDir": "work/$work_id",
  "unitId": "unit-$work_id",
  "tasksCompleted": [],
  "tasksTotal": 3,
  "currentTask": "task-1",
  "targetRef": {
    "remote": "$target_remote",
    "branch": "$target_branch",
    "role": "integration",
    "resolvedBy": "config.git.targets.roles.integration.branch",
    "resolvedAt": "$(fresh_timestamp)"
  },
  "freshness": {
    "validation": "$validation",
    "reconcile": "manual",
    "checkpoints": {
      "build": "require",
      "verify": "require",
      "ship": "require"
    },
    "status": "unknown",
    "lastCheckedAt": null
  },
  "branch": "$branch"
}
EOF
}

write_shared_session() {
  local dir="$1"
  local branch="$2"
  local work_id="$3"
  local worktree_root

  worktree_root="$(worktree_state_root "$dir")"
  mkdir -p "$worktree_root"
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
}

init_bare_remote() {
  local remote_dir="$1"
  mkdir -p "$remote_dir"
  git_nested -C "$remote_dir" -c core.hooksPath=/dev/null init --bare -q
}

clone_repo() {
  local remote_dir="$1"
  local clone_dir="$2"
  git_nested -c core.hooksPath=/dev/null clone -q "$remote_dir" "$clone_dir"
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null config user.name "Specwright Tests"
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null config user.email "specwright-tests@example.com"
}

setup_assessed_repo() {
  local remote_dir="$1"
  local repo_dir="$2"
  local work_id="$3"
  local validation="${4:-branch-head}"
  clone_repo "$remote_dir" "$repo_dir"
  git_nested -C "$repo_dir" checkout -qb feature origin/main
  write_shared_config "$repo_dir" "$validation"
  write_shared_workflow "$repo_dir" "$work_id" "feature" "$validation"
  write_shared_session "$repo_dir" "feature" "$work_id"
}

advance_main_and_push() {
  local clone_dir="$1"
  local message="$2"
  printf '%s\n' "$message" >> "$clone_dir/README.md"
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null add README.md
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null commit -qm "$message"
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null push -q origin main
}

commit_on_feature() {
  local repo_dir="$1"
  local message="$2"
  printf '%s\n' "$message" > "$repo_dir/feature.txt"
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null add feature.txt
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null commit -qm "$message"
}

assess_freshness() {
  local dir="$1"
  local fetch_mode="${2:-false}"
  local phase="${3:-build}"
  (
    cd "$dir" &&
    STATE_PATHS_MODULE="$STATE_PATHS_MODULE" \
    GIT_FRESHNESS_MODULE="$GIT_FRESHNESS_MODULE" \
    FETCH_MODE="$fetch_mode" \
    PHASE="$phase" \
    node --input-type=module <<'EOF'
const { loadSpecwrightState } = await import(process.env.STATE_PATHS_MODULE);
const { assessGitFreshness } = await import(process.env.GIT_FRESHNESS_MODULE);

const state = loadSpecwrightState();
const result = assessGitFreshness(state, {
  fetch: process.env.FETCH_MODE === 'true',
  phase: process.env.PHASE
});

process.stdout.write(JSON.stringify(result));
EOF
  )
}

echo "=== git freshness engine ==="
echo ""

echo "--- Protocol contract ---"
assert_file_exists "$PROTOCOL_FILE" "core/protocols/git-freshness.md exists"
assert_contains "$PROTOCOL_FILE" "clone-local runtime state" "protocol names clone-local runtime state explicitly"
assert_contains "$PROTOCOL_FILE" "project-level artifacts" "protocol names project-level artifacts explicitly"
assert_contains "$PROTOCOL_FILE" "optional auditable work artifacts" "protocol names optional auditable work artifacts explicitly"
assert_contains "$PROTOCOL_FILE" "must not depend on symlinked mirrors" "protocol rejects symlink-based artifact assumptions"
assert_contains "$PROTOCOL_FILE" "session.json" "protocol keeps session.json in the local-only runtime set"
assert_contains "$PROTOCOL_FILE" "CONSTITUTION.md" "protocol keeps anchor docs in the project artifact set"
assert_contains "$PROTOCOL_FILE" "recorded work state and resolved roots" "protocol roots helper behavior in resolved state instead of one hardcoded path"

echo ""
echo "--- Helper fresh assessment ---"
SEED="$TEST_TMPDIR/fresh-seed"
REMOTE="$TEST_TMPDIR/fresh-remote.git"
REPO="$TEST_TMPDIR/fresh-repo"
init_git_repo "$SEED"
init_bare_remote "$REMOTE"
git_nested -C "$SEED" remote add origin "$REMOTE"
git_nested -C "$SEED" -c core.hooksPath=/dev/null push -q -u origin main
setup_assessed_repo "$REMOTE" "$REPO" "fresh-work"
if fresh_output="$(assess_freshness "$REPO" false)"; then
  assert_output_contains "$fresh_output" '"status":"fresh"' "helper reports a branch aligned with target as fresh"
  assert_output_contains "$fresh_output" '"recommendedAction":"continue"' "fresh result recommends continue"
  assert_output_contains "$fresh_output" '"validation":"branch-head"' "fresh result preserves branch-head validation mode"
else
  fail "helper returns JSON for a fresh assessment"
fi

echo ""
echo "--- Helper stale assessment with explicit fetch ---"
PUSHER="$TEST_TMPDIR/stale-pusher"
clone_repo "$REMOTE" "$PUSHER"
before_branch="$(git_nested -C "$REPO" branch --show-current)"
before_head="$(git_nested -C "$REPO" rev-parse HEAD)"
advance_main_and_push "$PUSHER" "test: remote main advances"
if stale_without_fetch="$(assess_freshness "$REPO" false)"; then
  assert_output_contains "$stale_without_fetch" '"status":"fresh"' "helper does not invent remote drift without an explicit fetch"
else
  fail "helper returns JSON before explicit fetch"
fi
if stale_with_fetch="$(assess_freshness "$REPO" true)"; then
  assert_output_contains "$stale_with_fetch" '"status":"stale"' "helper reports stale once explicit fetch refreshes target refs"
  assert_output_contains "$stale_with_fetch" '"behind":1' "stale result reports target-only commits"
  assert_output_contains "$stale_with_fetch" '"recommendedAction":"stop"' "require checkpoint turns stale into a stop recommendation"
else
  fail "helper returns JSON for a stale assessment after fetch"
fi
after_branch="$(git_nested -C "$REPO" branch --show-current)"
after_head="$(git_nested -C "$REPO" rev-parse HEAD)"
assert_eq "$after_branch" "$before_branch" "explicit fetch keeps the current branch checked out"
assert_eq "$after_head" "$before_head" "explicit fetch does not mutate HEAD"

echo ""
echo "--- Helper diverged assessment ---"
DIVERGED_REPO="$TEST_TMPDIR/diverged-repo"
DIVERGED_PUSHER="$TEST_TMPDIR/diverged-pusher"
setup_assessed_repo "$REMOTE" "$DIVERGED_REPO" "diverged-work"
clone_repo "$REMOTE" "$DIVERGED_PUSHER"
commit_on_feature "$DIVERGED_REPO" "test: feature diverges"
advance_main_and_push "$DIVERGED_PUSHER" "test: target diverges"
if diverged_output="$(assess_freshness "$DIVERGED_REPO" true)"; then
  assert_output_contains "$diverged_output" '"status":"diverged"' "helper reports unique commits on both branches as diverged"
  assert_output_contains "$diverged_output" '"ahead":1' "diverged result reports current-only commits"
  assert_output_contains "$diverged_output" '"behind":1' "diverged result reports target-only commits"
else
  fail "helper returns JSON for a diverged assessment"
fi

echo ""
echo "--- Helper blocked assessment ---"
BLOCKED_REPO="$TEST_TMPDIR/blocked-repo"
setup_assessed_repo "$REMOTE" "$BLOCKED_REPO" "blocked-work"
write_shared_workflow "$BLOCKED_REPO" "blocked-work" "feature" "branch-head" "release/missing"
if blocked_output="$(assess_freshness "$BLOCKED_REPO" true)"; then
  assert_output_contains "$blocked_output" '"status":"blocked"' "helper reports missing target refs as blocked"
  assert_output_contains "$blocked_output" '"recommendedAction":"stop"' "blocked result recommends stop for require checkpoints"
else
  fail "helper returns JSON for a blocked assessment"
fi

echo ""
echo "--- Helper queue-managed assessment ---"
QUEUE_REPO="$TEST_TMPDIR/queue-repo"
setup_assessed_repo "$REMOTE" "$QUEUE_REPO" "queue-work" "queue"
if queue_output="$(assess_freshness "$QUEUE_REPO" false)"; then
  assert_output_contains "$queue_output" '"status":"queue-managed"' "helper reports queue-managed validation distinctly"
  assert_output_contains "$queue_output" '"recommendedAction":"delegate-to-queue"' "queue-managed result delegates authority to the queue"
  assert_output_contains "$queue_output" '"validation":"queue"' "queue-managed result preserves queue validation mode"
else
  fail "helper returns JSON for a queue-managed assessment"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
