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

echo "=== Test: smoke tag infrastructure (no entries tagged) ==="

# REVISED post first-real-baseline-run (2026-04-08): the original test
# asserted 4 smoke-tagged entries. Running the live baseline revealed
# that the *-handoff-format eval entries from Unit 01 do NOT actually
# pass when invoked end-to-end against the trivial-task fixture —
# Claude shortcircuits with a clarifying question instead of running
# the multi-minute pipeline skill. Documented in field-findings.md.
#
# Until the eval design is fixed in a follow-up unit, Unit 02b-2 ships
# the smoke filter infrastructure WITHOUT any tagged entries. The
# workflow runs trivially (zero entries → zero comparison work).
# This test now asserts the empty state is honest, not the broken state.

# AC-19a: skill suite still validates
if python -m evals --suite skill --validate 2>&1 | grep -q '^OK$'; then
  pass "skill suite validates"
else
  fail "skill suite validation failed"
fi

# AC-19b: zero entries tagged smoke (deferred to follow-up unit)
SMOKE_COUNT=$(grep -c '"smoke": true' evals/suites/skill/evals.json || true)
if [ "$SMOKE_COUNT" = "0" ]; then
  pass "zero entries tagged smoke: true (eval design fix deferred to follow-up unit)"
else
  fail "expected 0 smoke-tagged entries, got $SMOKE_COUNT"
fi

# AC-19c: --smoke-only --dry-run produces zero cases (filter behaves correctly with empty set)
DRY_RUN_OUT=$(python -m evals --suite skill --smoke-only --dry-run 2>&1 || true)
DRY_RUN_COUNT=$(echo "$DRY_RUN_OUT" | grep -c '^sw-' || true)
if [ "$DRY_RUN_COUNT" = "0" ]; then
  pass "--smoke-only --dry-run produces zero cases when nothing is tagged"
else
  fail "--smoke-only --dry-run produced unexpected case count: $DRY_RUN_COUNT (output: $DRY_RUN_OUT)"
fi

# AC-19d: smoke filter infrastructure correct — non-smoke cases excluded
if echo "$DRY_RUN_OUT" | grep -q 'sw-build-simple-function\|sw-init-fresh-ts'; then
  fail "--smoke-only somehow included a non-smoke case (filter broken)"
else
  pass "--smoke-only excludes all non-smoke cases (filter correct)"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
