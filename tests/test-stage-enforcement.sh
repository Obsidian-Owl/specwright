#!/usr/bin/env bash
#
# Tests for stage enforcement (shipping state, hook, evidence, protocols)
#
# T1: AC-1, AC-2 — State machine shipping status and transitions
# T2: AC-3, AC-4, AC-5, AC-6, AC-7, AC-16 — sw-ship pre-flight and lifecycle
# T3: AC-8, AC-9, AC-10 — PreToolUse hook
# T4: AC-11, AC-12, AC-13, AC-14 — Protocol and skill updates
# T5: AC-15, AC-17 — Session hooks and documentation
#
# Dependencies: bash, jq, node
# Usage: ./tests/test-stage-enforcement.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# ── T1: State machine — AC-1, AC-2 ──────────────────────────────────────────

echo "=== T1: State machine — shipping status and transitions ==="

STATE_MD="$ROOT_DIR/core/protocols/state.md"

# AC-1: shipping in currentWork.status enum
if grep -q '"status":.*shipping' "$STATE_MD"; then
  pass "AC-1a: shipping in currentWork.status enum"
else
  fail "AC-1a: shipping not found in currentWork.status enum"
fi

# AC-1: shipping in workUnits entry status
if grep -q 'shipping' "$STATE_MD" | head -1 > /dev/null && \
   grep -A2 'workUnits' "$STATE_MD" | grep -q 'shipping'; then
  pass "AC-1b: shipping in workUnits entry status"
else
  # Alternative: check that shipping appears in the workUnits schema line
  if grep 'pending.*planned.*building.*verifying.*shipping.*shipped' "$STATE_MD" > /dev/null 2>&1; then
    pass "AC-1b: shipping in workUnits entry status"
  else
    fail "AC-1b: shipping not found in workUnits entry status"
  fi
fi

# AC-2: Transition verifying → shipping exists
if grep -E 'verifying.*\|.*shipping.*\|.*sw-ship' "$STATE_MD" > /dev/null 2>&1; then
  pass "AC-2a: verifying → shipping transition exists"
else
  fail "AC-2a: verifying → shipping transition not found"
fi

# AC-2: Transition shipping → shipped exists
if grep -E 'shipping.*\|.*shipped.*\|.*sw-ship' "$STATE_MD" > /dev/null 2>&1; then
  pass "AC-2b: shipping → shipped transition exists"
else
  fail "AC-2b: shipping → shipped transition not found"
fi

# AC-2: Transition shipping → verifying (rollback) exists
if grep -E 'shipping.*\|.*verifying' "$STATE_MD" > /dev/null 2>&1; then
  pass "AC-2c: shipping → verifying rollback transition exists"
else
  fail "AC-2c: shipping → verifying rollback transition not found"
fi

# AC-2: building → shipped transition REMOVED (check transition table only, not enum lines)
# shellcheck disable=SC2016
if grep -E '^\| `building`.*\|.*`shipped`' "$STATE_MD" > /dev/null 2>&1; then
  fail "AC-2d: building → shipped transition should be removed but still exists"
else
  pass "AC-2d: building → shipped transition correctly removed"
fi

# AC-2: shipped → building (multi-unit advancement) still exists
if grep -E 'shipped.*\|.*building' "$STATE_MD" > /dev/null 2>&1; then
  pass "AC-2e: shipped → building multi-unit transition preserved"
else
  fail "AC-2e: shipped → building multi-unit transition missing"
fi

echo ""

# ── Summary ──────────────────────────────────────────────────────────────────

echo "=== Results ==="
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "FAILED"
  exit 1
else
  echo "ALL PASSED"
  exit 0
fi
