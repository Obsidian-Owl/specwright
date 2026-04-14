#!/usr/bin/env bash
#
# Regression checks for the target-branch and freshness model introduced by
# branch-freshness-policy Unit 01.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

STATE_PROTOCOL="$ROOT_DIR/core/protocols/state.md"
GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"
DESIGN_SKILL="$ROOT_DIR/core/skills/sw-design/SKILL.md"
PLAN_SKILL="$ROOT_DIR/core/skills/sw-plan/SKILL.md"
INIT_SKILL="$ROOT_DIR/core/skills/sw-init/SKILL.md"
GUARD_SKILL="$ROOT_DIR/core/skills/sw-guard/SKILL.md"
BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"

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

echo "=== branch freshness target model docs ==="
echo ""

for file in "$STATE_PROTOCOL" "$GIT_PROTOCOL" "$DESIGN_SKILL" "$PLAN_SKILL" "$INIT_SKILL" "$GUARD_SKILL" "$BUILD_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- State protocol ---"
assert_contains "$STATE_PROTOCOL" '"targetRef": {' "workflow schema adds targetRef object"
assert_contains "$STATE_PROTOCOL" '"remote": "string"' "targetRef records remote"
assert_contains "$STATE_PROTOCOL" '"branch": "string"' "targetRef records branch"
assert_contains "$STATE_PROTOCOL" '"role": "string"' "targetRef records role"
assert_contains "$STATE_PROTOCOL" '"resolvedBy": "string"' "targetRef records resolution source"
assert_contains "$STATE_PROTOCOL" '"resolvedAt": "ISO timestamp"' "targetRef records resolution timestamp"
assert_contains "$STATE_PROTOCOL" '"freshness": {' "workflow schema adds freshness metadata"

echo ""
echo "--- Git protocol ---"
assert_contains "$GIT_PROTOCOL" '"targets": {' "git config schema adds targets"
assert_contains "$GIT_PROTOCOL" '"freshness": {' "git config schema adds freshness"
assert_contains "$GIT_PROTOCOL" 'compatibility alias for the default integration branch' "baseBranch remains a compatibility alias"
assert_contains "$GIT_PROTOCOL" 'Zero or multiple matches require an explicit user choice' "git protocol defines the safe pattern-resolution rule"

echo ""
echo "--- Skill surfaces ---"
assert_contains "$DESIGN_SKILL" "selected work's \`targetRef\` records the concrete remote, branch, role, resolution source, and resolution time" "sw-design records the concrete targetRef at design time"
assert_contains "$DESIGN_SKILL" "selected work's \`freshness\` is seeded from the resolved \`git.freshness\` config" "sw-design seeds freshness at design time"
assert_contains "$DESIGN_SKILL" "baselineCommit\` is the SHA of the resolved target branch HEAD" "sw-design ties baselineCommit to the resolved target branch head"
assert_contains "$PLAN_SKILL" "Preserve the selected work's recorded \`targetRef\` and freshness metadata" "sw-plan preserves the recorded target model"
assert_contains "$PLAN_SKILL" "Do not collapse back to inferring a single \`baseBranch\` target" "sw-plan rejects single-base inference drift"
assert_contains "$INIT_SKILL" "Store \`git.targets\` and \`git.freshness\` in \`config.json\`" "sw-init writes the new git config surfaces"
assert_contains "$INIT_SKILL" 'without requiring users to define a custom branch DSL' "sw-init avoids a custom branch DSL"
assert_contains "$GUARD_SKILL" "seed or migrate \`git.targets\` and \`git.freshness\` from the detected Git workflow strategy" "sw-guard seeds or migrates the new git model"
assert_contains "$GUARD_SKILL" 'without requiring users to define a custom branch DSL' "sw-guard keeps the git model intentionally small"
assert_contains "$BUILD_SKILL" "work's recorded \`targetRef\`, when present, is the first branch-resolution" "sw-build acknowledges targetRef-first branch setup"

echo ""
echo "--- Consistency guards ---"
assert_contains "$DESIGN_SKILL" "\`targetRef\` also written to \`{workDir}/context.md\` for historical reference." "sw-design writes targetRef to context"
assert_contains "$GIT_PROTOCOL" "If the selected work already records \`targetRef\`, branch setup uses that" "git branch setup prefers targetRef before compatibility fallbacks"
for file in "$STATE_PROTOCOL" "$GIT_PROTOCOL" "$DESIGN_SKILL" "$PLAN_SKILL" "$INIT_SKILL" "$GUARD_SKILL" "$BUILD_SKILL"; do
  assert_not_contains "$file" "targetBranch" "${file#"$ROOT_DIR"/} avoids targetBranch drift"
done

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
