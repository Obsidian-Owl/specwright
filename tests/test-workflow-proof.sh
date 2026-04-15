#!/usr/bin/env bash
#
# Regression checks for the workflow-proof scenarios introduced by
# branch-freshness-policy Unit 05.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/test-lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/test-lib.sh"

BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"
STATE_PATHS_MODULE="$ROOT_DIR/adapters/shared/specwright-state-paths.mjs"
GIT_FRESHNESS_MODULE="$ROOT_DIR/adapters/shared/specwright-git-freshness.mjs"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

PASS=0
FAIL=0
# The default Claude harness uses smoke mode to keep structural smoke within
# budget while still executing queue-managed workflow-proof coverage.
WORKFLOW_PROOF_MODE="${SPECWRIGHT_WORKFLOW_PROOF_MODE:-full}"

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

emit_coverage_marker() {
  printf 'COVERAGE: %s\n' "$1"
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
  local build_checkpoint="${3:-require}"
  local verify_checkpoint="${4:-require}"
  local ship_checkpoint="${5:-require}"
  local target_branch="${6:-main}"
  local repo_root

  repo_root="$(repo_state_root "$dir")"
  mkdir -p "$repo_root"
  cat > "$repo_root/config.json" <<EOF
{
  "version": "2.0",
  "git": {
    "baseBranch": "$target_branch",
    "targets": {
      "defaultRole": "integration",
      "roles": {
        "integration": { "branch": "$target_branch" }
      }
    },
    "freshness": {
      "validation": "$validation",
      "reconcile": "manual",
      "checkpoints": {
        "build": "$build_checkpoint",
        "verify": "$verify_checkpoint",
        "ship": "$ship_checkpoint"
      }
    }
  }
}
EOF
}

write_pattern_config() {
  local dir="$1"
  local validation="${2:-branch-head}"
  local build_checkpoint="${3:-require}"
  local verify_checkpoint="${4:-require}"
  local ship_checkpoint="${5:-require}"
  local repo_root

  repo_root="$(repo_state_root "$dir")"
  mkdir -p "$repo_root"
  cat > "$repo_root/config.json" <<EOF
{
  "version": "2.0",
  "git": {
    "baseBranch": "main",
    "targets": {
      "defaultRole": "maintenance",
      "roles": {
        "integration": { "branch": "main" },
        "maintenance": { "pattern": "release/*" }
      }
    },
    "freshness": {
      "validation": "$validation",
      "reconcile": "manual",
      "checkpoints": {
        "build": "$build_checkpoint",
        "verify": "$verify_checkpoint",
        "ship": "$ship_checkpoint"
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
  local build_checkpoint="${5:-require}"
  local verify_checkpoint="${6:-require}"
  local ship_checkpoint="${7:-require}"
  local target_branch="${8:-main}"
  local target_remote="${9:-origin}"
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
      "build": "$build_checkpoint",
      "verify": "$verify_checkpoint",
      "ship": "$ship_checkpoint"
    },
    "status": "unknown",
    "lastCheckedAt": null
  },
  "branch": "$branch"
}
EOF
}

write_shared_workflow_without_target() {
  local dir="$1"
  local work_id="$2"
  local branch="$3"
  local validation="${4:-branch-head}"
  local build_checkpoint="${5:-require}"
  local verify_checkpoint="${6:-require}"
  local ship_checkpoint="${7:-require}"
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
  "freshness": {
    "validation": "$validation",
    "reconcile": "manual",
    "checkpoints": {
      "build": "$build_checkpoint",
      "verify": "$verify_checkpoint",
      "ship": "$ship_checkpoint"
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
  git_nested -C "$remote_dir" -c core.hooksPath=/dev/null symbolic-ref HEAD refs/heads/main
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
  local build_checkpoint="${5:-require}"
  local verify_checkpoint="${6:-require}"
  local ship_checkpoint="${7:-require}"
  clone_repo "$remote_dir" "$repo_dir"
  git_nested -C "$repo_dir" checkout -qb feature origin/main
  write_shared_config "$repo_dir" "$validation" "$build_checkpoint" "$verify_checkpoint" "$ship_checkpoint"
  write_shared_workflow "$repo_dir" "$work_id" "feature" "$validation" "$build_checkpoint" "$verify_checkpoint" "$ship_checkpoint"
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

create_release_branch_and_push() {
  local clone_dir="$1"
  local branch_name="$2"
  local message="$3"
  git_nested -C "$clone_dir" checkout -qb "$branch_name" origin/main
  printf '%s\n' "$message" > "$clone_dir/release.txt"
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null add release.txt
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null commit -qm "$message"
  git_nested -C "$clone_dir" -c core.hooksPath=/dev/null push -q origin "$branch_name"
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

seed_remote_with_main() {
  local seed_dir="$1"
  local remote_dir="$2"

  init_git_repo "$seed_dir"
  init_bare_remote "$remote_dir"
  git_nested -C "$seed_dir" remote add origin "$remote_dir"
  git_nested -C "$seed_dir" -c core.hooksPath=/dev/null push -q -u origin main
}

echo "=== workflow proof ==="
echo ""

echo "--- Lifecycle branch-head checkpoint surfaces ---"
assert_contains "$BUILD_SKILL" "protocols/git-freshness.md" "sw-build references the shared freshness protocol"
assert_contains "$BUILD_SKILL" "selected work's recorded \`targetRef\` and \`freshness\`" "sw-build resolves build freshness from recorded target state"
assert_contains "$VERIFY_SKILL" "checkpoint from the recorded target and policy" "sw-verify resolves freshness from the recorded target and policy"
assert_contains "$GIT_PROTOCOL" "Queue-managed results stay distinct from local rewrite policy" "git protocol keeps queue-managed behavior distinct from branch-head rewrites"

echo ""
echo "--- Stale build entry stops on require ---"
SEED="$TEST_TMPDIR/workflow-proof-seed"
REMOTE="$TEST_TMPDIR/workflow-proof-remote.git"
seed_remote_with_main "$SEED" "$REMOTE"
if [ "$WORKFLOW_PROOF_MODE" = "full" ]; then
  BUILD_REPO="$TEST_TMPDIR/build-stop-repo"
  BUILD_PUSHER="$TEST_TMPDIR/build-stop-pusher"
  setup_assessed_repo "$REMOTE" "$BUILD_REPO" "build-stop-work" "branch-head" "require" "require" "require"
  clone_repo "$REMOTE" "$BUILD_PUSHER"
  advance_main_and_push "$BUILD_PUSHER" "test: build checkpoint sees target drift"
  if build_stop_output="$(assess_freshness "$BUILD_REPO" true build)"; then
    assert_output_contains "$build_stop_output" '"phase":"build"' "workflow proof tags the stale build scenario with the build phase"
    assert_output_contains "$build_stop_output" '"status":"stale"' "workflow proof detects stale build entry"
    assert_output_contains "$build_stop_output" '"checkpoint":"require"' "workflow proof keeps the build checkpoint severity"
    assert_output_contains "$build_stop_output" '"recommendedAction":"stop"' "workflow proof stops stale build entry on require"
  else
    fail "workflow proof returns JSON for stale build entry"
  fi

  echo ""
  echo "--- Stale verify entry warns on warn checkpoint ---"
  VERIFY_REPO="$TEST_TMPDIR/verify-warn-repo"
  VERIFY_PUSHER="$TEST_TMPDIR/verify-warn-pusher"
  setup_assessed_repo "$REMOTE" "$VERIFY_REPO" "verify-warn-work" "branch-head" "ignore" "warn" "require"
  clone_repo "$REMOTE" "$VERIFY_PUSHER"
  advance_main_and_push "$VERIFY_PUSHER" "test: verify checkpoint sees target drift"
  if verify_warn_output="$(assess_freshness "$VERIFY_REPO" true verify)"; then
    assert_output_contains "$verify_warn_output" '"phase":"verify"' "workflow proof tags the stale verify scenario with the verify phase"
    assert_output_contains "$verify_warn_output" '"status":"stale"' "workflow proof detects stale verify entry"
    assert_output_contains "$verify_warn_output" '"checkpoint":"warn"' "workflow proof keeps the verify warn checkpoint"
    assert_output_contains "$verify_warn_output" '"recommendedAction":"warn"' "workflow proof warns for stale verify entry on warn"
  else
    fail "workflow proof returns JSON for stale verify entry"
  fi
else
  pass "workflow proof smoke mode skips stale build and verify drift fixtures"
fi

echo ""
echo "--- Queue-managed ship delegates to the queue ---"
assert_contains "$SHIP_SKILL" "protocols/git-freshness.md" "sw-ship references the shared freshness protocol"
assert_contains "$SHIP_SKILL" "Queue-managed validation remains distinct" "sw-ship keeps queue-managed shipping distinct from branch-head mode"
QUEUE_REPO="$TEST_TMPDIR/queue-ship-repo"
setup_assessed_repo "$REMOTE" "$QUEUE_REPO" "queue-ship-work" "queue" "require" "require" "require"
if queue_ship_output="$(assess_freshness "$QUEUE_REPO" false ship)"; then
  assert_output_contains "$queue_ship_output" '"phase":"ship"' "workflow proof tags the queue-managed ship scenario with the ship phase"
  assert_output_contains "$queue_ship_output" '"validation":"queue"' "workflow proof preserves queue validation for ship"
  assert_output_contains "$queue_ship_output" '"status":"queue-managed"' "workflow proof covers queue-managed ship behavior"
  assert_output_contains "$queue_ship_output" '"recommendedAction":"delegate-to-queue"' "workflow proof delegates queue-managed shipping to the queue"
  emit_coverage_marker "workflow-proof.queue-managed-ship"
else
  fail "workflow proof returns JSON for queue-managed ship entry"
fi

echo ""
echo "--- Release target resolution uses the configured pattern ---"
if [ "$WORKFLOW_PROOF_MODE" = "full" ]; then
  RELEASE_PUSHER="$TEST_TMPDIR/release-target-pusher"
  RELEASE_REPO="$TEST_TMPDIR/release-target-repo"
  clone_repo "$REMOTE" "$RELEASE_PUSHER"
  create_release_branch_and_push "$RELEASE_PUSHER" "release/2026.04" "test: publish release target"
  clone_repo "$REMOTE" "$RELEASE_REPO"
  git_nested -C "$RELEASE_REPO" checkout -qb feature origin/main
  write_pattern_config "$RELEASE_REPO" "branch-head" "require" "require" "require"
  write_shared_workflow_without_target "$RELEASE_REPO" "release-target-work" "feature" "branch-head" "require" "require" "require"
  write_shared_session "$RELEASE_REPO" "feature" "release-target-work"
  if release_target_output="$(assess_freshness "$RELEASE_REPO" false build)"; then
    assert_output_contains "$release_target_output" '"branch":"release/2026.04"' "workflow proof resolves a concrete release target branch"
    assert_output_contains "$release_target_output" '"role":"maintenance"' "workflow proof preserves the maintenance target role"
    assert_output_contains "$release_target_output" '"resolvedBy":"config.git.targets.roles.maintenance.pattern"' "workflow proof records pattern-based target resolution"
    assert_output_contains "$release_target_output" '"status":"stale"' "workflow proof treats a newer release target as stale from the feature branch"
  else
    fail "workflow proof returns JSON for release-target resolution"
  fi
else
  pass "workflow proof smoke mode skips release-target fixtures"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
