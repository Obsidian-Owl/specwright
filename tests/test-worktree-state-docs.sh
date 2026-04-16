#!/usr/bin/env bash
#
# Broad regression checks for the work/session state model introduced by
# multi-worktree-state Unit 02.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_PROTOCOL="$ROOT_DIR/core/protocols/state.md"
CONTEXT_PROTOCOL="$ROOT_DIR/core/protocols/context.md"
GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"
PARALLEL_PROTOCOL="$ROOT_DIR/core/protocols/parallel-build.md"
RECOVERY_PROTOCOL="$ROOT_DIR/core/protocols/recovery.md"
INIT_SKILL="$ROOT_DIR/core/skills/sw-init/SKILL.md"
STATUS_SKILL="$ROOT_DIR/core/skills/sw-status/SKILL.md"
SYNC_SKILL="$ROOT_DIR/core/skills/sw-sync/SKILL.md"
DOCTOR_SKILL="$ROOT_DIR/core/skills/sw-doctor/SKILL.md"

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
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

echo "=== worktree state doc regression ==="
echo ""

for file in \
  "$STATE_PROTOCOL" \
  "$CONTEXT_PROTOCOL" \
  "$GIT_PROTOCOL" \
  "$PARALLEL_PROTOCOL" \
  "$RECOVERY_PROTOCOL" \
  "$INIT_SKILL" \
  "$STATUS_SKILL" \
  "$SYNC_SKILL" \
  "$DOCTOR_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Init shared/session bootstrap ---"
assert_contains "$INIT_SKILL" '{projectArtifactsRoot}/config.json' "sw-init writes tracked config to projectArtifactsRoot"
assert_contains "$INIT_SKILL" '{worktreeStateRoot}/session.json' "sw-init creates the per-worktree session root"
assert_contains "$INIT_SKILL" 'shared across developers and agent sessions via' "sw-init documents linked-worktree bootstrap against shared state"
assert_not_contains "$INIT_SKILL" "\`.specwright/\` created here will not be visible in other worktrees" "sw-init no longer treats linked worktrees as isolated .specwright installs"
assert_not_contains "$INIT_SKILL" '.specwright/state/workflow.json' "sw-init no longer initializes the legacy singleton workflow path"

echo ""
echo "--- State protocol ---"
assert_contains "$STATE_PROTOCOL" '{repoStateRoot}/work/{workId}/workflow.json' "state protocol defines per-work workflow files"
assert_contains "$STATE_PROTOCOL" '{worktreeStateRoot}/session.json' "state protocol defines per-worktree session files"
assert_contains "$STATE_PROTOCOL" 'zero or one top-level attachment' "state protocol limits top-level ownership"
assert_contains "$STATE_PROTOCOL" 'Subordinate sessions are allowed only as controlled helper contexts' "state protocol documents subordinate-session behavior"
assert_not_contains "$STATE_PROTOCOL" '## Workflow State File' "state protocol no longer presents a singleton workflow heading"

echo ""
echo "--- Context migration fallback ---"
assert_contains "$CONTEXT_PROTOCOL" 'currentWork` wrapper' "context protocol documents legacy workflow wrapper normalization"
assert_contains "$CONTEXT_PROTOCOL" 'legacy working-tree Specwright layout' "context protocol warns when legacy layout is in use"

echo ""
echo "--- Doctor migration checks ---"
assert_contains "$DOCTOR_SKILL" 'layout status' "sw-doctor reports shared versus legacy layout status"
assert_contains "$DOCTOR_SKILL" 'dead sessions' "sw-doctor checks for dead sessions"
assert_contains "$DOCTOR_SKILL" 'legacy-write drift' "sw-doctor checks for legacy-write drift"
assert_contains "$DOCTOR_SKILL" 'migration surface: tracked docs/config under' "sw-doctor bounds repair to the migration surface"

echo ""
echo "--- Repo-wide work visibility ---"
assert_contains "$STATUS_SKILL" "\`projectArtifactsRoot\`, \`repoStateRoot\`" "sw-status prints resolved logical roots"
assert_contains "$STATUS_SKILL" 'live top-level sessions' "sw-status distinguishes live session ownership from stale attachments"
assert_contains "$SYNC_SKILL" "subordinate helper worktrees discovered via \`git worktree list --porcelain\`" "sw-sync protects subordinate helper worktrees discovered from Git"
assert_contains "$SYNC_SKILL" 'live session or subordinate helper still claims it' "sw-sync keeps claimed branches out of deletion"

echo ""
echo "--- Parallel-build protocol ---"
assert_contains "$PARALLEL_PROTOCOL" 'top-level' "parallel-build keeps a top-level parent session"
assert_contains "$PARALLEL_PROTOCOL" 'subordinate' "parallel-build creates subordinate helper sessions"
assert_contains "$PARALLEL_PROTOCOL" 'workflow.json.attachment' "parallel-build keeps ownership on the parent workflow"
assert_contains "$PARALLEL_PROTOCOL" 'attachedWorkId = {parentWorkId}' "parallel-build binds helpers to the parent work"
assert_contains "$PARALLEL_PROTOCOL" 'AskUserQuestion' "parallel-build requires confirmation before helper creation"
assert_contains "$PARALLEL_PROTOCOL" 'install them in each helper worktree' "parallel-build documents helper dependency installation"
assert_contains "$PARALLEL_PROTOCOL" 'if helperWasLocked' "parallel-build only unlocks helpers that were locked"
assert_not_contains "$PARALLEL_PROTOCOL" '.specwright/state/' "parallel-build no longer points helpers at legacy state paths"

echo ""
echo "--- Shared/session path coverage ---"
for file in \
  "$STATE_PROTOCOL" \
  "$CONTEXT_PROTOCOL" \
  "$GIT_PROTOCOL" \
  "$PARALLEL_PROTOCOL" \
  "$RECOVERY_PROTOCOL" \
  "$STATUS_SKILL" \
  "$SYNC_SKILL" \
  "$DOCTOR_SKILL"; do
  label="${file#"$ROOT_DIR"/}"
  if grep -Fq 'repoStateRoot' "$file" || grep -Fq 'worktreeStateRoot' "$file"; then
    pass "$label references a logical state root"
  else
    fail "$label references a logical state root"
  fi
done

echo ""
echo "--- Recovery logical roots ---"
assert_contains "$RECOVERY_PROTOCOL" '{worktreeStateRoot}/session.json' "recovery reads session state from worktreeStateRoot"
assert_contains "$RECOVERY_PROTOCOL" '{repoStateRoot}/work/{workId}/workflow.json' "recovery reads the selected work workflow from repoStateRoot"
assert_contains "$RECOVERY_PROTOCOL" '{worktreeStateRoot}/continuation.md' "recovery reads continuation from worktreeStateRoot"
assert_not_contains "$RECOVERY_PROTOCOL" '.specwright/state/workflow.json' "recovery no longer points at the legacy singleton workflow path"

echo ""
echo "--- File-specific singleton drift guards ---"
assert_not_contains "$CONTEXT_PROTOCOL" '## Linked Worktree Degradation' "context protocol no longer encodes linked-worktree stop tiers"
assert_not_contains "$GIT_PROTOCOL" 'currentWork.status' "git protocol no longer uses repo-global currentWork state"
assert_not_contains "$STATUS_SKILL" 'currentWork.unitId' "sw-status no longer centers currentWork.unitId"
assert_not_contains "$SYNC_SKILL" "active feature branch (\`currentWork.branch\`)" "sw-sync no longer relies on currentWork.branch"
assert_not_contains "$DOCTOR_SKILL" '.specwright/state/workflow.json' "sw-doctor no longer points at the legacy singleton workflow path"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
