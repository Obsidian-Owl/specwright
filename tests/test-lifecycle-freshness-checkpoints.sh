#!/usr/bin/env bash
#
# Regression checks for lifecycle freshness checkpoint wording introduced by
# branch-freshness-policy Unit 03.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"

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

echo "=== lifecycle freshness checkpoints ==="
echo ""

for file in "$BUILD_SKILL" "$VERIFY_SKILL" "$SHIP_SKILL" "$GIT_PROTOCOL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Build checkpoint ---"
assert_contains "$BUILD_SKILL" "Before task work begins" "sw-build names a build-entry freshness checkpoint"
assert_contains "$BUILD_SKILL" "selected work's recorded \`targetRef\` and \`freshness\`" "sw-build resolves build freshness from the recorded target and policy"
assert_contains "$BUILD_SKILL" "queue-managed" "sw-build distinguishes queue-managed freshness"
assert_contains "$BUILD_SKILL" "protocols/git-freshness.md" "sw-build references the shared freshness protocol"

echo ""
echo "--- Verify checkpoint ---"
assert_contains "$VERIFY_SKILL" "before any gate runs" "sw-verify checks freshness before gate execution"
assert_contains "$VERIFY_SKILL" "branch-head \`require\` blocks stale, diverged, and blocked freshness results" "sw-verify blocks stale branch-head verification when required"
assert_contains "$VERIFY_SKILL" "queue-managed" "sw-verify distinguishes queue-managed freshness"
assert_contains "$VERIFY_SKILL" "protocols/git-freshness.md" "sw-verify references the shared freshness protocol"

echo ""
echo "--- Ship checkpoint ---"
assert_contains "$SHIP_SKILL" "Re-check shipping freshness during pre-flight" "sw-ship re-checks freshness during pre-flight"
assert_contains "$SHIP_SKILL" "branch-head \`require\` blocks stale, diverged, and blocked freshness results" "sw-ship blocks stale branch-head shipping when required"
assert_contains "$SHIP_SKILL" "must not force a local rebase by default" "sw-ship keeps queue-managed shipping distinct from local rebasing"
assert_contains "$SHIP_SKILL" "protocols/git-freshness.md" "sw-ship references the shared freshness protocol"

echo ""
echo "--- Git lifecycle contract ---"
assert_contains "$GIT_PROTOCOL" "## Lifecycle Freshness Checkpoints" "git protocol adds a lifecycle checkpoint section"
assert_contains "$GIT_PROTOCOL" "\`sw-build\` consumes the \`build\` checkpoint" "git protocol describes build checkpoint consumption"
assert_contains "$GIT_PROTOCOL" "\`sw-verify\` consumes the \`verify\` checkpoint before gate execution" "git protocol describes verify checkpoint ordering"
assert_contains "$GIT_PROTOCOL" "\`sw-ship\` consumes the \`ship\` checkpoint during shipping pre-flight" "git protocol describes ship checkpoint usage"
assert_contains "$GIT_PROTOCOL" "queue-managed results stay distinct from local rewrite policy" "git protocol preserves queue-managed distinction"
assert_not_contains "$GIT_PROTOCOL" "This is advisory only unless a skill adds a stricter policy." "git protocol no longer leaves freshness as advisory-only drift guidance"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
