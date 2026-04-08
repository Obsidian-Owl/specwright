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

echo "=== Test: structural smoke eval subset ==="

# Unit 02d replaces the broken live `*-handoff-format` placeholders with
# deterministic structural smoke entries that execute existing repo-local
# checks. The smoke subset is now real and should stay small, explicit,
# and deterministic.

# AC-19a: skill suite still validates
if python -m evals --suite skill --validate 2>&1 | grep -q '^OK$'; then
  pass "skill suite validates"
else
  fail "skill suite validation failed"
fi

# AC-19b: exactly 5 structural entries tagged smoke
SMOKE_COUNT=$(grep -c '"smoke": true' evals/suites/skill/evals.json || true)
if [ "$SMOKE_COUNT" = "5" ]; then
  pass "exactly 5 entries are tagged smoke: true"
else
  fail "expected 5 smoke-tagged entries, got $SMOKE_COUNT"
fi

# AC-19c: --smoke-only --dry-run emits the 5 structural smoke entries only
DRY_RUN_OUT=$(python -m evals --suite skill --smoke-only --dry-run 2>&1 || true)
DRY_RUN_COUNT=$(echo "$DRY_RUN_OUT" | grep -Ec '^(structural-|grader-function-tests|workflow-yaml-validation)' || true)
if [ "$DRY_RUN_COUNT" = "5" ]; then
  pass "--smoke-only --dry-run emits 5 structural cases"
else
  fail "--smoke-only --dry-run emitted unexpected case count: $DRY_RUN_COUNT (output: $DRY_RUN_OUT)"
fi

# AC-19d: every required structural ID is present
if echo "$DRY_RUN_OUT" | grep -q '^structural-skill-validation' \
  && echo "$DRY_RUN_OUT" | grep -q '^structural-handoff-template' \
  && echo "$DRY_RUN_OUT" | grep -q '^structural-state-enforcement' \
  && echo "$DRY_RUN_OUT" | grep -q '^grader-function-tests' \
  && echo "$DRY_RUN_OUT" | grep -q '^workflow-yaml-validation'; then
  pass "all 5 structural smoke IDs are present"
else
  fail "missing one or more structural smoke IDs (output: $DRY_RUN_OUT)"
fi

# AC-19e: deleted handoff-format placeholders stay gone
if echo "$DRY_RUN_OUT" | grep -q 'handoff-format'; then
  fail "deleted handoff-format evals still appear in smoke output"
else
  pass "deleted handoff-format evals are absent from smoke output"
fi

# AC-19f: smoke filter still excludes ordinary non-smoke cases
if echo "$DRY_RUN_OUT" | grep -q 'sw-build-simple-function\|sw-init-fresh-ts'; then
  fail "smoke-only included a non-smoke case"
else
  pass "smoke-only excludes ordinary non-smoke cases"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
