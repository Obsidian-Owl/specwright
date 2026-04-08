#!/usr/bin/env bash
#
# Test for Unit 02b-2 smoke tagging (AC-19).
# Verifies the smoke-tag changes do not regress existing evals.
#
# Usage: ./tests/test-eval-smoke-tag.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cd "$ROOT_DIR" || exit 1

echo "=== Test: smoke tagging end-to-end ==="

# AC-19a: skill suite still validates
if python -m evals --suite skill --validate 2>&1 | grep -q '^OK$'; then
  pass "skill suite validates after smoke tagging"
else
  fail "skill suite validation failed after smoke tagging"
fi

# AC-19b: exactly 4 entries are tagged smoke: true
SMOKE_COUNT=$(grep -c '"smoke": true' evals/suites/skill/evals.json)
if [ "$SMOKE_COUNT" = "4" ]; then
  pass "exactly 4 entries tagged smoke: true (got $SMOKE_COUNT)"
else
  fail "expected 4 smoke-tagged entries, got $SMOKE_COUNT"
fi

# AC-19c: the 4 tagged entries are the *-handoff-format ones
EXPECTED_IDS="sw-design-handoff-format sw-plan-handoff-format sw-verify-handoff-format sw-ship-handoff-format"
for expected in $EXPECTED_IDS; do
  # Verify the smoke flag appears within ~3 lines of each id (the id and
  # smoke field are in the same eval-case object)
  if grep -A 4 "\"id\": \"$expected\"" evals/suites/skill/evals.json | grep -q '"smoke": true'; then
    pass "$expected has smoke: true"
  else
    fail "$expected is missing smoke: true"
  fi
done

# AC-19d: --smoke-only --dry-run lists exactly 4 cases on stderr
DRY_RUN_OUT=$(python -m evals --suite skill --smoke-only --dry-run 2>&1 | head -100)
DRY_RUN_COUNT=$(echo "$DRY_RUN_OUT" | grep -c 'sw-.*-handoff-format' || true)
if [ "$DRY_RUN_COUNT" = "4" ]; then
  pass "--smoke-only --dry-run lists exactly 4 handoff-format cases"
else
  fail "--smoke-only --dry-run produced unexpected case count: $DRY_RUN_COUNT (output: $DRY_RUN_OUT)"
fi

# AC-19e: --smoke-only does NOT list non-smoke cases
if echo "$DRY_RUN_OUT" | grep -q 'sw-build-simple-function\|sw-init-fresh-ts'; then
  fail "--smoke-only included a non-smoke case"
else
  pass "--smoke-only excludes non-smoke cases"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
