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

extract_body() {
  local file="$1"
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  tail -n +"$((closing_line + 2))" "$file"
}

assert_body_contains() {
  local pattern="$1"
  local message="$2"
  if echo "$BODY" | grep -qE "$pattern"; then
    pass "$message"
  else
    fail "$message — pattern not found in body: $pattern"
  fi
}

assert_body_not_contains() {
  local pattern="$1"
  local message="$2"
  if echo "$BODY" | grep -qE "$pattern"; then
    fail "$message — unexpected pattern found in body: $pattern"
  else
    pass "$message"
  fi
}

echo "=== sw-verify enriched handoff and selected-work semantics ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "core/skills/sw-verify/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

FULL_CONTENT=$(cat "$SKILL_FILE")
BODY=$(extract_body "$SKILL_FILE") || {
  fail "SKILL.md has body content after frontmatter"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
}

echo "=== Selected-work roots ==="
assert_body_contains 'session\.json|selected work' \
  "sw-verify references the current worktree session or selected work"
assert_body_contains '{repoStateRoot}/work/{selectedWork\.id}/workflow\.json|selected work.?s `?workflow\.json`' \
  "sw-verify reads the selected work workflow"
assert_body_contains '{workDir}/evidence/' \
  "sw-verify writes evidence into {workDir}/evidence"
assert_body_not_contains '\.specwright/state/workflow\.json' \
  "sw-verify avoids checkout-local singleton workflow paths"

echo ""
echo "=== Ownership and state updates ==="
assert_body_contains 'adopt/takeover|owned that work' \
  "sw-verify stops with adopt/takeover guidance on ownership conflicts"
assert_body_contains 'Mutate only the selected work.?s `?workflow\.json` and the current worktree session|selected work.?s `?workflow\.json`' \
  "sw-verify state updates target the selected work"
assert_body_contains 'gates` section|summary table `\| Gate \| Status \| Findings \(B/W/I\) \|`' \
  "sw-verify preserves gate-summary reporting"

echo ""
echo "=== Enriched handoff contract ==="
assert_body_contains 'Per-finding detail|per-finding detail' \
  "sw-verify keeps the per-finding detail tier"
assert_body_contains '\| Gate \| Status \| Findings \(B/W/I\) \|' \
  "sw-verify keeps the summary table tier"
assert_body_contains 'Actionable Findings' \
  "sw-verify keeps the actionable findings tier"
assert_body_contains '^\s*\|[[:space:]]*#[[:space:]]*\|.*Gate.*\|.*Severity.*\|.*File.*\|.*Finding.*\|.*Recommended Fix.*\|' \
  "sw-verify includes the actionable findings table header"
assert_body_contains '^\s*\|---\|------\|----------\|------\|---------\|-----------------\|' \
  "sw-verify includes the actionable findings markdown separator row"
assert_body_contains 'only WARN and BLOCK severity rows, not INFO|Include only WARN and BLOCK severity rows, not INFO' \
  "sw-verify excludes INFO findings from the actionable findings table"
assert_body_contains 'specific file path from gate evidence|specific file path' \
  "sw-verify requires specific file paths in actionable findings"
assert_body_contains 'manual review' \
  "sw-verify preserves manual-review guidance for BLOCK findings"
assert_body_contains 'N of M' \
  "sw-verify preserves the actionable summary count guidance"

echo ""
echo "=== Stage boundary and handoff ==="
assert_body_contains 'NEVER fix|NEVER fix code, create PRs, or ship' \
  "sw-verify stage boundary still forbids fixing or shipping"
assert_body_contains 'Artifacts: \{workDir\}/stage-report\.md|stage-report\.md' \
  "sw-verify handoff still points at stage-report.md"
assert_body_contains 'Next: /sw-build|Next: /sw-ship' \
  "sw-verify handoff still routes to /sw-build or /sw-ship"
assert_body_contains 'Fix and re-run `?/sw-verify`?' \
  "sw-verify keeps the explicit BLOCK handoff"
assert_body_contains 'Review, then fix or `?/sw-ship`?' \
  "sw-verify keeps the explicit WARN handoff"
assert_body_contains 'Ready for `?/sw-ship`?' \
  "sw-verify keeps the explicit PASS handoff"
assert_contains 'protocols/stage-boundary\.md' \
  "sw-verify still references protocols/stage-boundary.md"

echo ""
echo "=== Budget ==="
WORD_COUNT=$(echo "$FULL_CONTENT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt 1500 ]; then
  pass "sw-verify word count ($WORD_COUNT) stays under 1500"
else
  fail "sw-verify word count ($WORD_COUNT) stays under 1500"
fi
if [ "$WORD_COUNT" -gt 200 ]; then
  pass "sw-verify word count ($WORD_COUNT) stays above 200"
else
  fail "sw-verify word count ($WORD_COUNT) stays above 200"
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
