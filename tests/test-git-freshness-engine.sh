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
RECONCILE_PROTOCOL_FILE="$ROOT_DIR/core/protocols/git-reconcile.md"
STATE_PATHS_MODULE="$ROOT_DIR/adapters/shared/specwright-state-paths.mjs"
GIT_FRESHNESS_MODULE="$ROOT_DIR/adapters/shared/specwright-git-freshness.mjs"
GIT_RECONCILE_MODULE="$ROOT_DIR/adapters/shared/specwright-git-reconcile.mjs"
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
  local checkpoint="${3:-require}"
  local reconcile="${4:-manual}"
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
      "reconcile": "$reconcile",
      "checkpoints": {
        "build": "$checkpoint",
        "verify": "$checkpoint",
        "ship": "$checkpoint"
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
  local checkpoint="${7:-require}"
  local reconcile="${8:-manual}"
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
    "reconcile": "$reconcile",
    "checkpoints": {
      "build": "$checkpoint",
      "verify": "$checkpoint",
      "ship": "$checkpoint"
    },
    "status": "unknown",
    "lastCheckedAt": null
  },
  "branch": "$branch",
  "attachment": {
    "worktreeId": "test-worktree",
    "worktreePath": "$(cd "$dir" && pwd -P)",
    "mode": "top-level",
    "attachedAt": "$(fresh_timestamp)",
    "lastSeenAt": "$(fresh_timestamp)"
  }
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
  git_nested -C "$remote_dir" -c core.hooksPath=/dev/null init --bare --initial-branch=main -q
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
  local checkpoint="${5:-require}"
  local reconcile="${6:-manual}"
  clone_repo "$remote_dir" "$repo_dir"
  git_nested -C "$repo_dir" checkout -qb feature origin/main
  write_shared_config "$repo_dir" "$validation" "$checkpoint" "$reconcile"
  write_shared_workflow "$repo_dir" "$work_id" "feature" "$validation" "main" "origin" "$checkpoint" "$reconcile"
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

create_conflict_file() {
  local repo_dir="$1"
  printf 'shared=base\n' > "$repo_dir/shared.txt"
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null add shared.txt
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null commit -qm "test: add shared conflict fixture"
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null push -q origin main
}

commit_conflicting_change_on_feature() {
  local repo_dir="$1"
  local value="$2"
  printf 'shared=%s\n' "$value" > "$repo_dir/shared.txt"
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null add shared.txt
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null commit -qm "test: feature conflict $value"
}

advance_conflicting_change_on_main() {
  local repo_dir="$1"
  local value="$2"
  git_nested -C "$repo_dir" checkout -q main
  printf 'shared=%s\n' "$value" > "$repo_dir/shared.txt"
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null add shared.txt
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null commit -qm "test: target conflict $value"
  git_nested -C "$repo_dir" -c core.hooksPath=/dev/null push -q origin main
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

reconcile_freshness() {
  local dir="$1"
  local phase="${2:-build}"
  local fetch_mode="${3:-true}"
  (
    cd "$dir" &&
    STATE_PATHS_MODULE="$STATE_PATHS_MODULE" \
    GIT_RECONCILE_MODULE="$GIT_RECONCILE_MODULE" \
    FETCH_MODE="$fetch_mode" \
    PHASE="$phase" \
    node --input-type=module <<'EOF'
const { loadSpecwrightState } = await import(process.env.STATE_PATHS_MODULE);
const { reconcileGitFreshness } = await import(process.env.GIT_RECONCILE_MODULE);

const state = loadSpecwrightState();
const result = await reconcileGitFreshness(state, {
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
assert_file_exists "$RECONCILE_PROTOCOL_FILE" "core/protocols/git-reconcile.md exists"
assert_contains "$PROTOCOL_FILE" "clone-local runtime state" "protocol names clone-local runtime state explicitly"
assert_contains "$PROTOCOL_FILE" "project-level artifacts" "protocol names project-level artifacts explicitly"
assert_contains "$PROTOCOL_FILE" "optional auditable work artifacts" "protocol names optional auditable work artifacts explicitly"
assert_contains "$PROTOCOL_FILE" "must not depend on symlinked mirrors" "protocol rejects symlink-based artifact assumptions"
assert_contains "$PROTOCOL_FILE" "session.json" "protocol keeps session.json in the local-only runtime set"
assert_contains "$PROTOCOL_FILE" "CONSTITUTION.md" "protocol keeps anchor docs in the project artifact set"
assert_contains "$PROTOCOL_FILE" "recorded work state and resolved roots" "protocol roots helper behavior in resolved state instead of one hardcoded path"
assert_contains "$RECONCILE_PROTOCOL_FILE" "owning worktree" "reconcile protocol scopes mutation to the owning worktree"
assert_contains "$RECONCILE_PROTOCOL_FILE" "dirty worktree" "reconcile protocol fails closed for dirty worktrees"
assert_contains "$RECONCILE_PROTOCOL_FILE" "queue-managed" "reconcile protocol preserves queue-managed no-local-rewrite behavior"

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
  assert_output_contains "$blocked_output" '"fetched":false' "failed fetches do not claim the target was refreshed"
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
  assert_output_contains "$queue_output" '"fetched":false' "queue-managed assessment reports that no fetch was needed"
  assert_output_contains "$queue_output" '"recommendedAction":"delegate-to-queue"' "queue-managed result delegates authority to the queue"
  assert_output_contains "$queue_output" '"validation":"queue"' "queue-managed result preserves queue validation mode"
else
  fail "helper returns JSON for a queue-managed assessment"
fi

echo ""
echo "--- Reconcile helper rebases stale branches in-stage ---"
REBASE_REPO="$TEST_TMPDIR/rebase-repo"
REBASE_PUSHER="$TEST_TMPDIR/rebase-pusher"
setup_assessed_repo "$REMOTE" "$REBASE_REPO" "rebase-work" "branch-head" "require" "rebase"
clone_repo "$REMOTE" "$REBASE_PUSHER"
before_rebase_head="$(git_nested -C "$REBASE_REPO" rev-parse HEAD)"
advance_main_and_push "$REBASE_PUSHER" "test: rebase helper sees target drift"
if rebase_output="$(reconcile_freshness "$REBASE_REPO" build true)"; then
  assert_output_contains "$rebase_output" '"status":"reconciled"' "reconcile helper reports a successful rebase"
  assert_output_contains "$rebase_output" '"action":"rebase"' "reconcile helper reports the rebase action"
  assert_output_contains "$rebase_output" '"performed":true' "reconcile helper marks rebase as performed"
else
  fail "reconcile helper returns JSON for a stale rebase recovery"
fi
after_rebase_head="$(git_nested -C "$REBASE_REPO" rev-parse HEAD)"
if [ "$after_rebase_head" != "$before_rebase_head" ]; then
  pass "reconcile helper advances HEAD after a successful rebase"
else
  fail "reconcile helper advances HEAD after a successful rebase"
fi
if post_rebase_fresh_output="$(assess_freshness "$REBASE_REPO" true build)"; then
  assert_output_contains "$post_rebase_fresh_output" '"status":"fresh"' "rebase helper leaves the branch fresh against the target"
else
  fail "helper returns JSON after rebase recovery"
fi

echo ""
echo "--- Reconcile helper merges diverged branches in-stage ---"
MERGE_REPO="$TEST_TMPDIR/merge-repo"
MERGE_PUSHER="$TEST_TMPDIR/merge-pusher"
setup_assessed_repo "$REMOTE" "$MERGE_REPO" "merge-work" "branch-head" "require" "merge"
clone_repo "$REMOTE" "$MERGE_PUSHER"
commit_on_feature "$MERGE_REPO" "test: merge helper diverges locally"
advance_main_and_push "$MERGE_PUSHER" "test: merge helper sees target drift"
if merge_output="$(reconcile_freshness "$MERGE_REPO" verify true)"; then
  assert_output_contains "$merge_output" '"status":"reconciled"' "reconcile helper reports a successful merge"
  assert_output_contains "$merge_output" '"action":"merge"' "reconcile helper reports the merge action"
  assert_output_contains "$merge_output" '"performed":true' "reconcile helper marks merge as performed"
else
  fail "reconcile helper returns JSON for a diverged merge recovery"
fi
if post_merge_fresh_output="$(assess_freshness "$MERGE_REPO" true verify)"; then
  assert_output_contains "$post_merge_fresh_output" '"status":"fresh"' "merge helper leaves the branch fresh against the target"
else
  fail "helper returns JSON after merge recovery"
fi

echo ""
echo "--- Reconcile helper honors manual fallback without mutating HEAD ---"
MANUAL_REPO="$TEST_TMPDIR/manual-repo"
MANUAL_PUSHER="$TEST_TMPDIR/manual-pusher"
setup_assessed_repo "$REMOTE" "$MANUAL_REPO" "manual-work" "branch-head" "require" "manual"
clone_repo "$REMOTE" "$MANUAL_PUSHER"
manual_before_head="$(git_nested -C "$MANUAL_REPO" rev-parse HEAD)"
advance_main_and_push "$MANUAL_PUSHER" "test: manual policy sees target drift"
if manual_output="$(reconcile_freshness "$MANUAL_REPO" build true)"; then
  assert_output_contains "$manual_output" '"status":"blocked"' "manual reconcile policy blocks lifecycle-owned mutation"
  assert_output_contains "$manual_output" '"reasonCode":"manual-policy"' "manual reconcile policy reports an explicit fallback reason"
  assert_output_contains "$manual_output" '"performed":false' "manual reconcile policy reports no mutation"
else
  fail "reconcile helper returns JSON for manual fallback"
fi
manual_after_head="$(git_nested -C "$MANUAL_REPO" rev-parse HEAD)"
assert_eq "$manual_after_head" "$manual_before_head" "manual fallback preserves HEAD"

echo ""
echo "--- Reconcile helper fails closed for dirty worktrees ---"
DIRTY_REPO="$TEST_TMPDIR/dirty-repo"
DIRTY_PUSHER="$TEST_TMPDIR/dirty-pusher"
setup_assessed_repo "$REMOTE" "$DIRTY_REPO" "dirty-work" "branch-head" "require" "rebase"
clone_repo "$REMOTE" "$DIRTY_PUSHER"
advance_main_and_push "$DIRTY_PUSHER" "test: dirty policy sees target drift"
printf 'dirty\n' >> "$DIRTY_REPO/README.md"
if dirty_output="$(reconcile_freshness "$DIRTY_REPO" build true)"; then
  assert_output_contains "$dirty_output" '"status":"blocked"' "dirty worktrees block lifecycle-owned reconcile"
  assert_output_contains "$dirty_output" '"reasonCode":"dirty-worktree"' "dirty worktrees report a distinct reason"
  assert_output_contains "$dirty_output" '"performed":false' "dirty worktrees report no mutation"
else
  fail "reconcile helper returns JSON for dirty-worktree failure"
fi

echo ""
echo "--- Reconcile helper fails closed for ownership mismatches ---"
OWNERSHIP_REPO="$TEST_TMPDIR/ownership-repo"
OWNERSHIP_PUSHER="$TEST_TMPDIR/ownership-pusher"
setup_assessed_repo "$REMOTE" "$OWNERSHIP_REPO" "ownership-work" "branch-head" "require" "rebase"
clone_repo "$REMOTE" "$OWNERSHIP_PUSHER"
advance_main_and_push "$OWNERSHIP_PUSHER" "test: ownership policy sees target drift"
python - "$OWNERSHIP_REPO" <<'PY'
from pathlib import Path
import json
import sys
repo = Path(sys.argv[1])
workflow_path = repo / ".git" / "specwright" / "work" / "ownership-work" / "workflow.json"
workflow = json.loads(workflow_path.read_text())
workflow["attachment"]["worktreeId"] = "other-worktree"
workflow_path.write_text(json.dumps(workflow, indent=2) + "\n")
PY
if ownership_output="$(reconcile_freshness "$OWNERSHIP_REPO" build true)"; then
  assert_output_contains "$ownership_output" '"status":"blocked"' "ownership mismatches block lifecycle-owned reconcile"
  assert_output_contains "$ownership_output" '"reasonCode":"ownership-mismatch"' "ownership mismatches report a distinct reason"
else
  fail "reconcile helper returns JSON for ownership mismatch"
fi

echo ""
echo "--- Reconcile helper aborts conflicted rebases ---"
CONFLICT_SEED="$TEST_TMPDIR/conflict-seed"
CONFLICT_REMOTE="$TEST_TMPDIR/conflict-remote.git"
CONFLICT_REPO="$TEST_TMPDIR/conflict-repo"
CONFLICT_PUSHER="$TEST_TMPDIR/conflict-pusher"
init_git_repo "$CONFLICT_SEED"
init_bare_remote "$CONFLICT_REMOTE"
git_nested -C "$CONFLICT_SEED" remote add origin "$CONFLICT_REMOTE"
git_nested -C "$CONFLICT_SEED" -c core.hooksPath=/dev/null push -q -u origin main
clone_repo "$CONFLICT_REMOTE" "$CONFLICT_PUSHER"
create_conflict_file "$CONFLICT_PUSHER"
setup_assessed_repo "$CONFLICT_REMOTE" "$CONFLICT_REPO" "conflict-work" "branch-head" "require" "rebase"
commit_conflicting_change_on_feature "$CONFLICT_REPO" "feature"
advance_conflicting_change_on_main "$CONFLICT_PUSHER" "target"
conflict_before_head="$(git_nested -C "$CONFLICT_REPO" rev-parse HEAD)"
if conflict_output="$(reconcile_freshness "$CONFLICT_REPO" verify true)"; then
  assert_output_contains "$conflict_output" '"status":"blocked"' "conflicted rebases fail closed"
  assert_output_contains "$conflict_output" '"reasonCode":"conflict"' "conflicted rebases report a conflict reason"
  assert_output_contains "$conflict_output" '"performed":false' "conflicted rebases do not report a completed mutation"
else
  fail "reconcile helper returns JSON for rebase conflicts"
fi
conflict_after_head="$(git_nested -C "$CONFLICT_REPO" rev-parse HEAD)"
assert_eq "$conflict_after_head" "$conflict_before_head" "conflicted rebases leave HEAD at the pre-reconcile commit"
if git_nested -C "$CONFLICT_REPO" rev-parse --verify REBASE_HEAD >/dev/null 2>&1; then
  fail "conflicted rebases are aborted before returning"
else
  pass "conflicted rebases are aborted before returning"
fi

echo ""
echo "--- Reconcile helper preserves queue-managed no-local-rewrite semantics ---"
QUEUE_RECONCILE_REPO="$TEST_TMPDIR/queue-reconcile-repo"
setup_assessed_repo "$REMOTE" "$QUEUE_RECONCILE_REPO" "queue-reconcile-work" "queue" "require" "rebase"
if queue_reconcile_output="$(reconcile_freshness "$QUEUE_RECONCILE_REPO" ship false)"; then
  assert_output_contains "$queue_reconcile_output" '"status":"queue-managed"' "queue-managed reconcile stays provider-owned"
  assert_output_contains "$queue_reconcile_output" '"performed":false' "queue-managed reconcile reports no local mutation"
else
  fail "reconcile helper returns JSON for queue-managed reconciliation"
fi

echo ""
echo "--- Helper warn checkpoint assessment ---"
WARN_REPO="$TEST_TMPDIR/warn-repo"
WARN_PUSHER="$TEST_TMPDIR/warn-pusher"
setup_assessed_repo "$REMOTE" "$WARN_REPO" "warn-work" "branch-head" "warn"
clone_repo "$REMOTE" "$WARN_PUSHER"
advance_main_and_push "$WARN_PUSHER" "test: warn checkpoint sees drift"
if warn_output="$(assess_freshness "$WARN_REPO" true)"; then
  assert_output_contains "$warn_output" '"status":"stale"' "helper still reports stale under warn checkpoints"
  assert_output_contains "$warn_output" '"recommendedAction":"warn"' "warn checkpoints downgrade stale guidance to warn"
else
  fail "helper returns JSON for a warn checkpoint assessment"
fi

echo ""
echo "--- Helper malformed config assessment ---"
INVALID_CONFIG_REPO="$TEST_TMPDIR/invalid-config-repo"
setup_assessed_repo "$REMOTE" "$INVALID_CONFIG_REPO" "invalid-config-work"
cat > "$(repo_state_root "$INVALID_CONFIG_REPO")/config.json" <<'EOF'
{ invalid json
EOF
if malformed_config_output="$(assess_freshness "$INVALID_CONFIG_REPO" false)"; then
  assert_output_contains "$malformed_config_output" '"status":"fresh"' "malformed config degrades cleanly to workflow-backed assessment"
  assert_output_contains "$malformed_config_output" '"validation":"branch-head"' "malformed config does not drop workflow freshness settings"
else
  fail "helper tolerates malformed shared config"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
