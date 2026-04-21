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
GIT_RECONCILE_PROTOCOL="$ROOT_DIR/core/protocols/git-reconcile.md"
CONFIG_FILE="$ROOT_DIR/.specwright/config.json"

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

emit_coverage_marker() {
  printf 'COVERAGE: %s\n' "$1"
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

for file in "$BUILD_SKILL" "$VERIFY_SKILL" "$SHIP_SKILL" "$GIT_PROTOCOL" "$GIT_RECONCILE_PROTOCOL" "$CONFIG_FILE"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Build checkpoint ---"
assert_contains "$BUILD_SKILL" "**Build freshness checkpoint (LOW freedom) — after branch setup:**" "sw-build gives the build freshness checkpoint its own headed block"
assert_contains "$BUILD_SKILL" "selected work's recorded \`targetRef\` and \`freshness\`" "sw-build resolves build freshness from the recorded target and policy"
assert_contains "$BUILD_SKILL" "queue-managed" "sw-build distinguishes queue-managed freshness"
assert_contains "$BUILD_SKILL" "protocols/git-reconcile.md" "sw-build references the shared reconcile protocol"
assert_contains "$BUILD_SKILL" "\`rebase\` or \`merge\` reconcile is configured" "sw-build allows lifecycle-owned rebase or merge recovery"
assert_contains "$BUILD_SKILL" "same stage after a successful reconcile" "sw-build keeps recovery inside build when reconcile succeeds"
assert_contains "$BUILD_SKILL" "\`manual\` remains an explicit fallback" "sw-build keeps manual as a fallback instead of the default path"
assert_contains "$BUILD_SKILL" "protocols/git-freshness.md" "sw-build references the shared freshness protocol"

echo ""
echo "--- Verify checkpoint ---"
assert_contains "$VERIFY_SKILL" "before any gate runs" "sw-verify checks freshness before gate execution"
assert_contains "$VERIFY_SKILL" "branch-head \`require\` blocks stale, diverged, and blocked freshness results" "sw-verify blocks stale branch-head verification when required"
assert_contains "$VERIFY_SKILL" "Queue-managed mode remains" "sw-verify capitalizes the queue-managed verification sentence"
assert_contains "$VERIFY_SKILL" "protocols/git-reconcile.md" "sw-verify references the shared reconcile protocol"
assert_contains "$VERIFY_SKILL" "\`rebase\` or \`merge\` reconcile is configured" "sw-verify allows lifecycle-owned rebase or merge recovery"
assert_contains "$VERIFY_SKILL" "continue gate execution in that same verify run" "sw-verify keeps recovery inside verify when reconcile succeeds"
assert_contains "$VERIFY_SKILL" "\`manual\` remains an explicit fallback" "sw-verify keeps manual as an explicit fallback"
assert_contains "$VERIFY_SKILL" "In headless mode, follow" "sw-verify documents the headless verify exception"
assert_contains "$VERIFY_SKILL" "skip freshness blocking, continue gate execution, and" "sw-verify preserves the headless skip-freshness exception"
assert_contains "$VERIFY_SKILL" "protocols/git-freshness.md" "sw-verify references the shared freshness protocol"
assert_contains "$VERIFY_SKILL" "**Gate Re-Run Policy (LOW freedom):**" "sw-verify distinguishes the gate rerun section from the freshness checkpoint"

echo ""
echo "--- Ship checkpoint ---"
assert_contains "$SHIP_SKILL" "Re-check shipping freshness during pre-flight" "sw-ship re-checks freshness during pre-flight"
assert_contains "$SHIP_SKILL" "branch-head \`require\` blocks stale, diverged, and blocked freshness results" "sw-ship blocks stale branch-head shipping when required"
assert_contains "$SHIP_SKILL" "Queue-managed validation remains distinct" "sw-ship capitalizes the queue-managed shipping sentence"
assert_contains "$SHIP_SKILL" "must not force a local rebase by default" "sw-ship keeps queue-managed shipping distinct from local rebasing"
assert_contains "$SHIP_SKILL" "protocols/git-reconcile.md" "sw-ship references the shared reconcile protocol"
assert_contains "$SHIP_SKILL" "\`rebase\` or \`merge\` reconcile is configured" "sw-ship allows lifecycle-owned rebase or merge recovery"
assert_contains "$SHIP_SKILL" "continue shipping in that same run" "sw-ship keeps recovery inside ship when reconcile succeeds"
assert_contains "$SHIP_SKILL" "\`manual\` remains an explicit fallback" "sw-ship keeps manual as an explicit fallback"
assert_contains "$SHIP_SKILL" "protocols/git-freshness.md" "sw-ship references the shared freshness protocol"

echo ""
echo "--- Default policy ---"
assert_contains "$CONFIG_FILE" '"reconcile": "rebase"' "repo config defaults lifecycle freshness recovery to rebase"
assert_not_contains "$CONFIG_FILE" '"reconcile": "manual"' "repo config no longer defaults lifecycle freshness recovery to manual"

echo ""
echo "--- Git lifecycle contract ---"
assert_contains "$GIT_PROTOCOL" "## Lifecycle Freshness Checkpoints" "git protocol adds a lifecycle checkpoint section"
assert_contains "$GIT_PROTOCOL" "\`sw-build\` consumes the \`build\` checkpoint" "git protocol describes build checkpoint consumption"
assert_contains "$GIT_PROTOCOL" "\`sw-verify\` consumes the \`verify\` checkpoint before gate execution" "git protocol describes verify checkpoint ordering"
assert_contains "$GIT_PROTOCOL" "\`sw-ship\` consumes the \`ship\` checkpoint during shipping pre-flight" "git protocol describes ship checkpoint usage"
assert_contains "$GIT_PROTOCOL" "\`rebase\` or \`merge\` reconcile inside the blocked lifecycle stage" "git protocol describes same-stage lifecycle-owned recovery"
assert_contains "$GIT_PROTOCOL" "\`manual\` remains the explicit fallback" "git protocol preserves manual as explicit fallback wording"
assert_contains "$GIT_PROTOCOL" "Queue-managed results stay distinct from local rewrite policy" "git protocol preserves queue-managed distinction with sentence-case wording"
assert_not_contains "$GIT_PROTOCOL" "This is advisory only unless a skill adds a stricter policy." "git protocol no longer leaves freshness as advisory-only drift guidance"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "freshness.lifecycle-policy"
