#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Regression checks for sw-verify's handoff and multi-worktree state wording.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/sw-verify/SKILL.md"

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
  local pattern="$1"
  local message="$2"
  if grep -qE "$pattern" "$SKILL_FILE" 2>/dev/null; then
    pass "$message"
  else
    fail "$message — pattern not found: $pattern"
  fi
}

assert_not_contains() {
  local pattern="$1"
  local message="$2"
  if grep -qE "$pattern" "$SKILL_FILE" 2>/dev/null; then
    fail "$message — unexpected pattern found: $pattern"
  else
    pass "$message"
  fi
}

echo "=== sw-verify handoff and selected-work semantics ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "core/skills/sw-verify/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

echo "=== Selected-work roots ==="
assert_contains 'session\.json|selected work' \
  "sw-verify references the current worktree session or selected work"
assert_contains '{repoStateRoot}/work/{selectedWork\.id}/workflow\.json|selected work.?s `?workflow\.json`' \
  "sw-verify reads the selected work workflow"
assert_contains '{workDir}/evidence/' \
  "sw-verify writes evidence into {workDir}/evidence"
assert_not_contains '\.specwright/state/workflow\.json' \
  "sw-verify avoids checkout-local singleton workflow paths"

echo ""
echo "=== Ownership and state updates ==="
assert_contains 'adopt/takeover|owned that work' \
  "sw-verify stops with adopt/takeover guidance on ownership conflicts"
assert_contains 'Mutate only the selected work.?s `?workflow\.json` and the current worktree session|selected work.?s `?workflow\.json`' \
  "sw-verify state updates target the selected work"
assert_contains 'gates` section|summary table `\| Gate \| Status \| Findings \(B/W/I\) \|`' \
  "sw-verify preserves gate-summary reporting"

echo ""
echo "=== Stage boundary and handoff ==="
assert_contains 'NEVER fix|NEVER fix code, create PRs, or ship' \
  "sw-verify stage boundary still forbids fixing or shipping"
assert_contains 'Artifacts: \{workDir\}/stage-report\.md|stage-report\.md' \
  "sw-verify handoff still points at stage-report.md"
assert_contains 'Next: /sw-build|Next: /sw-ship' \
  "sw-verify handoff still routes to /sw-build or /sw-ship"
assert_contains 'Fix and re-run /sw-verify|/sw-build' \
  "sw-verify still describes the block path"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
