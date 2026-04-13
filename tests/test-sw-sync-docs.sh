#!/usr/bin/env bash
#
# Cross-document checks for the shared/session state terminology introduced in
# Unit 02.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_PROTOCOL="$ROOT_DIR/core/protocols/state.md"
CONTEXT_PROTOCOL="$ROOT_DIR/core/protocols/context.md"
GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"
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

echo "=== shared/session protocol alignment ==="
echo ""

for file in "$STATE_PROTOCOL" "$CONTEXT_PROTOCOL" "$GIT_PROTOCOL" "$STATUS_SKILL" "$SYNC_SKILL" "$DOCTOR_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Core roots ---"
for file in "$STATE_PROTOCOL" "$CONTEXT_PROTOCOL" "$GIT_PROTOCOL"; do
  label="${file#"$ROOT_DIR"/}"
  assert_contains "$file" 'projectRoot' "$label defines projectRoot"
  assert_contains "$file" 'repoStateRoot' "$label defines repoStateRoot"
  assert_contains "$file" 'worktreeStateRoot' "$label defines worktreeStateRoot"
done

echo ""
echo "--- Context protocol ---"
assert_contains "$CONTEXT_PROTOCOL" 'linked worktree is not degraded' "context removes linked-worktree STOP degradation"
assert_contains "$CONTEXT_PROTOCOL" '{worktreeStateRoot}/session.json.attachedWorkId' "context resolves work via session attachment"
assert_not_contains "$CONTEXT_PROTOCOL" '## Linked Worktree Degradation' "legacy linked-worktree degradation section is gone"
assert_not_contains "$CONTEXT_PROTOCOL" 'Tier A —' "legacy tiered degradation language is gone"

echo ""
echo "--- Git protocol ---"
assert_contains "$GIT_PROTOCOL" 'worktreeStateRoot/session.json.attachedWorkId' "git resolves the selected work from session state"
assert_contains "$GIT_PROTOCOL" 'adopt/takeover guidance' "git documents takeover guidance"
assert_contains "$GIT_PROTOCOL" 'workflow.json.status' "git gates PR creation on the selected work status"
assert_not_contains "$GIT_PROTOCOL" 'currentWork.status' "git no longer references currentWork.status"

echo ""
echo "--- Read-only skills ---"
assert_contains "$STATUS_SKILL" 'Repo-wide summary of active works' "sw-status reports repo-wide active works"
assert_contains "$STATUS_SKILL" '{worktreeStateRoot}/session.json' "sw-status reads session state"
assert_contains "$SYNC_SKILL" 'live sessions' "sw-sync protects live-session branches"
assert_contains "$SYNC_SKILL" '{repoStateRoot}/work/*/workflow.json' "sw-sync enumerates per-work workflows"
assert_contains "$DOCTOR_SKILL" 'STATE_DRIFT' "sw-doctor keeps repo-wide state drift checks"
assert_contains "$DOCTOR_SKILL" 'owning work' "sw-doctor reports the owning work for drift"

echo ""
echo "--- Singleton drift guards ---"
for file in "$STATUS_SKILL" "$SYNC_SKILL" "$DOCTOR_SKILL"; do
  label="${file#"$ROOT_DIR"/}"
  assert_not_contains "$file" '.specwright/state/workflow.json' "$label does not reference the legacy singleton workflow path"
done

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
