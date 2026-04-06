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

# ── T2: sw-ship — AC-3, AC-4, AC-5, AC-6, AC-7, AC-16 ──────────────────────

echo "=== T2: sw-ship — pre-flight, state lifecycle, evidence, recovery ==="

SHIP_MD="$ROOT_DIR/core/skills/sw-ship/SKILL.md"

# AC-3: Pre-flight requires verifying, rejects building
if grep -q 'verifying' "$SHIP_MD" && ! grep -q 'status is.*verifying.*or.*building' "$SHIP_MD"; then
  pass "AC-3a: pre-flight requires verifying status"
else
  fail "AC-3a: pre-flight still accepts building status"
fi

if grep -q 'Run /sw-verify first' "$SHIP_MD"; then
  pass "AC-3b: rejection message for building status present"
else
  fail "AC-3b: rejection message 'Run /sw-verify first' not found"
fi

# AC-4: shipping state lifecycle — set shipping before PR, shipped after, revert on failure
if grep -qi 'shipping' "$SHIP_MD" && grep -q 'shipped' "$SHIP_MD"; then
  # Check for the three-step lifecycle
  shipping_mentions=$(grep -c 'shipping' "$SHIP_MD" 2>/dev/null || echo 0)
  if [ "$shipping_mentions" -ge 3 ]; then
    pass "AC-4a: shipping state lifecycle described (≥3 mentions)"
  else
    fail "AC-4a: shipping state lifecycle insufficiently described ($shipping_mentions mentions)"
  fi
else
  fail "AC-4a: shipping state not mentioned in sw-ship"
fi

if grep -qi 'revert.*verifying\|verifying.*rollback\|verifying.*fail' "$SHIP_MD"; then
  pass "AC-4b: rollback to verifying on failure described"
else
  fail "AC-4b: rollback to verifying on failure not described"
fi

# AC-5: Gate evidence validation in pre-flight
if grep -q 'enabled gates' "$SHIP_MD" && grep -qi 'verdict' "$SHIP_MD"; then
  pass "AC-5a: pre-flight checks for gate verdicts"
else
  fail "AC-5a: pre-flight gate verdict check not found"
fi

if grep -qi 'FAIL.*ERROR\|ERROR.*FAIL' "$SHIP_MD"; then
  pass "AC-5b: pre-flight blocks FAIL/ERROR verdicts"
else
  fail "AC-5b: FAIL/ERROR verdict blocking not specified"
fi

if grep -qi 'evidence.*file\|evidence.*exist' "$SHIP_MD"; then
  pass "AC-5c: pre-flight requires evidence files"
else
  fail "AC-5c: evidence file existence check not specified"
fi

# AC-6: Evidence-sourced PR body
if grep -qi 'NOT RUN' "$SHIP_MD"; then
  pass "AC-6a: NOT RUN for gates without verdicts"
else
  fail "AC-6a: 'NOT RUN' text not found"
fi

if grep -qi 'no evidence file' "$SHIP_MD"; then
  pass "AC-6b: '(no evidence file)' for verdict-without-file"
else
  fail "AC-6b: 'no evidence file' text not found"
fi

if grep -qi 'workflow.json.*verdict\|verdict.*workflow.json\|source.*evidence' "$SHIP_MD"; then
  pass "AC-6c: PR body sourced from workflow.json/evidence files"
else
  fail "AC-6c: evidence sourcing requirement not specified"
fi

# AC-7: Shipping state recovery in failure modes
if grep -qi 'gh pr list.*--head\|pr list.*branch' "$SHIP_MD"; then
  pass "AC-7a: recovery checks if PR already exists"
else
  fail "AC-7a: PR existence check for recovery not found"
fi

if grep -qi 'shipping.*recovery\|stale.*shipping\|shipping.*stale' "$SHIP_MD"; then
  pass "AC-7b: shipping state recovery described"
else
  fail "AC-7b: shipping state recovery not found in failure modes"
fi

# AC-16: Pre-flight applies regardless of prRequired
if grep -qi 'prRequired\|unconditional' "$SHIP_MD" || \
   ! grep -qi 'prRequired.*skip.*pre-flight\|prRequired.*bypass' "$SHIP_MD"; then
  # Check that the pre-flight section does NOT branch on prRequired
  preflight_section=$(sed -n '/Pre-flight/,/^\*\*/p' "$SHIP_MD")
  if echo "$preflight_section" | grep -qi 'prRequired'; then
    fail "AC-16: pre-flight branches on prRequired (should be unconditional)"
  else
    pass "AC-16: pre-flight is unconditional (no prRequired branch)"
  fi
else
  fail "AC-16: pre-flight conditionality unclear"
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
