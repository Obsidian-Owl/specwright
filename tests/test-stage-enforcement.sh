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

# ── T3: PreToolUse hook — AC-8, AC-9, AC-10 ─────────────────────────────────

echo "=== T3: PreToolUse hook — pre-ship-guard ==="

HOOK_FILE="$ROOT_DIR/adapters/claude-code/hooks/pre-ship-guard.mjs"
HOOKS_JSON="$ROOT_DIR/adapters/claude-code/hooks/hooks.json"

# AC-9: Hook registered in hooks.json
if jq -e '.hooks.PreToolUse' "$HOOKS_JSON" > /dev/null 2>&1; then
  if jq -r '.hooks.PreToolUse[].hooks[].command // ""' "$HOOKS_JSON" | grep -q 'pre-ship-guard'; then
    pass "AC-9: PreToolUse hook registered for pre-ship-guard.mjs"
  else
    fail "AC-9: PreToolUse entry exists but doesn't reference pre-ship-guard"
  fi
else
  fail "AC-9: No PreToolUse entry in hooks.json"
fi

# AC-9: Matcher is Bash
if jq -r '.hooks.PreToolUse[].matcher // ""' "$HOOKS_JSON" | grep -q 'Bash'; then
  pass "AC-9b: PreToolUse matcher includes Bash"
else
  fail "AC-9b: PreToolUse matcher does not include Bash"
fi

# AC-8: Hook file exists and is valid Node.js
if [ -f "$HOOK_FILE" ]; then
  pass "AC-8a: pre-ship-guard.mjs exists"
else
  fail "AC-8a: pre-ship-guard.mjs does not exist"
fi

if [ -f "$HOOK_FILE" ] && node --check "$HOOK_FILE" 2>/dev/null; then
  pass "AC-8b: pre-ship-guard.mjs passes node --check"
else
  fail "AC-8b: pre-ship-guard.mjs fails node --check"
fi

# AC-8: Hook subprocess tests (a-d from spec)
# Helper: run hook with given stdin JSON and project dir, check exit code
run_hook() {
  local stdin_json="$1"
  local project_dir="$2"
  echo "$stdin_json" | node "$HOOK_FILE" "$project_dir" > /dev/null 2>&1
}

if [ -f "$HOOK_FILE" ]; then
  TMPDIR_HOOK=$(mktemp -d)
  trap 'rm -rf "$TMPDIR_HOOK"' EXIT

  # (a) Non-matching command → exit 0
  if run_hook '{"tool_name":"Bash","tool_input":{"command":"ls -la"}}' "$TMPDIR_HOOK"; then
    pass "AC-8c: non-matching command exits 0"
  else
    fail "AC-8c: non-matching command should exit 0"
  fi

  # (b) Matching command with building status → exit non-zero
  mkdir -p "$TMPDIR_HOOK/.specwright/state"
  cat > "$TMPDIR_HOOK/.specwright/state/workflow.json" <<WEOF
{"version":"2.0","currentWork":{"id":"test","status":"building","workDir":".specwright/work/test"},"gates":{},"lock":null,"lastUpdated":"2026-01-01T00:00:00Z"}
WEOF
  if ! run_hook '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}' "$TMPDIR_HOOK"; then
    pass "AC-8d: matching command with building status exits non-zero"
  else
    fail "AC-8d: matching command with building status should exit non-zero"
  fi

  # (c) Matching command with shipping status → exit 0
  cat > "$TMPDIR_HOOK/.specwright/state/workflow.json" <<WEOF
{"version":"2.0","currentWork":{"id":"test","status":"shipping","workDir":".specwright/work/test"},"gates":{},"lock":null,"lastUpdated":"2026-01-01T00:00:00Z"}
WEOF
  if run_hook '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}' "$TMPDIR_HOOK"; then
    pass "AC-8e: matching command with shipping status exits 0"
  else
    fail "AC-8e: matching command with shipping status should exit 0"
  fi

  # (d) Matching command with no workflow.json → exit 0
  TMPDIR_HOOK2=$(mktemp -d)
  if run_hook '{"tool_name":"Bash","tool_input":{"command":"gh pr create --title test"}}' "$TMPDIR_HOOK2"; then
    pass "AC-8f: matching command with no workflow.json exits 0"
  else
    fail "AC-8f: matching command with no workflow.json should exit 0"
  fi
  rm -rf "$TMPDIR_HOOK2"

  # AC-10: Fast-exit — non-matching command with no workflow.json → exit 0
  TMPDIR_HOOK3=$(mktemp -d)
  if run_hook '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' "$TMPDIR_HOOK3"; then
    pass "AC-10: fast-exit on non-matching command (no workflow.json, no error)"
  else
    fail "AC-10: fast-exit failed — hook read workflow.json on non-matching command"
  fi
  rm -rf "$TMPDIR_HOOK3"

  # Reset to building for remaining pattern tests
  cat > "$TMPDIR_HOOK/.specwright/state/workflow.json" <<WEOF
{"version":"2.0","currentWork":{"id":"test","status":"building","workDir":".specwright/work/test"},"gates":{},"lock":null,"lastUpdated":"2026-01-01T00:00:00Z"}
WEOF

  # Test gh api /pulls pattern
  if ! run_hook '{"tool_name":"Bash","tool_input":{"command":"gh api repos/foo/bar/pulls --method POST"}}' "$TMPDIR_HOOK"; then
    pass "AC-8g: gh api /pulls pattern detected and blocked"
  else
    fail "AC-8g: gh api /pulls pattern should be blocked during building"
  fi

  # Test curl pattern
  if ! run_hook '{"tool_name":"Bash","tool_input":{"command":"curl -X POST https://api.github.com/repos/foo/bar/pulls"}}' "$TMPDIR_HOOK"; then
    pass "AC-8h: curl api.github.com/pulls pattern detected and blocked"
  else
    fail "AC-8h: curl api.github.com/pulls pattern should be blocked"
  fi

  rm -rf "$TMPDIR_HOOK"
else
  fail "AC-8c: skipped (hook file missing)"
  fail "AC-8d: skipped (hook file missing)"
  fail "AC-8e: skipped (hook file missing)"
  fail "AC-8f: skipped (hook file missing)"
  fail "AC-10: skipped (hook file missing)"
  fail "AC-8g: skipped (hook file missing)"
  fail "AC-8h: skipped (hook file missing)"
fi

echo ""

# ── T4: Protocol and skill updates — AC-11, AC-12, AC-13, AC-14 ─────────────

echo "=== T4: Protocol and skill updates ==="

BOUNDARY_MD="$ROOT_DIR/core/protocols/stage-boundary.md"
GIT_MD="$ROOT_DIR/core/protocols/git.md"
BUILD_MD="$ROOT_DIR/core/skills/sw-build/SKILL.md"

# AC-11: Blocked operations table in stage-boundary.md
if grep -qi 'Blocked Operations' "$BOUNDARY_MD"; then
  pass "AC-11a: Blocked Operations section exists"
else
  fail "AC-11a: Blocked Operations section not found"
fi

if grep -q 'gh pr create' "$BOUNDARY_MD" && grep -q 'building' "$BOUNDARY_MD"; then
  pass "AC-11b: gh pr create blocked during building"
else
  fail "AC-11b: gh pr create not listed as blocked during building"
fi

if grep -q 'api.github.com' "$BOUNDARY_MD" || grep -q 'gh api.*pulls' "$BOUNDARY_MD"; then
  pass "AC-11c: API-based PR creation patterns listed"
else
  fail "AC-11c: API-based PR creation patterns not listed"
fi

if grep -q 'verifying' "$BOUNDARY_MD" | head -1 > /dev/null; then
  # Check that verifying also blocks PR creation (from the table)
  if grep -A5 'Blocked Operations' "$BOUNDARY_MD" | grep -q 'verifying'; then
    pass "AC-11d: PR creation also blocked during verifying"
  else
    fail "AC-11d: verifying state not in blocked operations table"
  fi
else
  fail "AC-11d: verifying not mentioned in stage-boundary.md"
fi

# AC-12: git.md state prerequisite for PR creation
if grep -qi 'shipping' "$GIT_MD" && grep -qi 'Prerequisite\|prerequisite\|status.*shipping' "$GIT_MD"; then
  pass "AC-12: git.md PR Creation has shipping state prerequisite"
else
  fail "AC-12: shipping state prerequisite not found in git.md PR Creation"
fi

# AC-13: sw-build prohibits PR creation
if grep -qi 'gh pr create\|PR creation\|pull request' "$BUILD_MD" | head -1 > /dev/null; then
  if grep -qi 'NOT\|never\|prohibit\|NEVER.*PR\|NEVER.*pr create' "$BUILD_MD"; then
    pass "AC-13: sw-build prohibits PR creation"
  else
    fail "AC-13: sw-build mentions PR but doesn't prohibit it"
  fi
else
  fail "AC-13: sw-build doesn't mention PR creation prohibition"
fi

# AC-14: Honest limitation updated for hook enforcement
if grep -qi 'hook\|PreToolUse\|pre-tool' "$BOUNDARY_MD"; then
  pass "AC-14a: stage-boundary mentions hook enforcement"
else
  fail "AC-14a: hook enforcement not mentioned in honest limitation"
fi

if grep -qi 'Opencode\|protocol-level' "$BOUNDARY_MD"; then
  pass "AC-14b: stage-boundary mentions Opencode protocol-level enforcement"
else
  fail "AC-14b: Opencode enforcement gap not mentioned"
fi

echo ""

# ── T5: Session-start hooks and documentation — AC-15, AC-17 ────────────────

echo "=== T5: Session-start hooks and documentation ==="

SESSION_START_MJS="$ROOT_DIR/adapters/claude-code/hooks/session-start.mjs"
PLUGIN_TS="$ROOT_DIR/adapters/opencode/plugin.ts"
DESIGN_MD="$ROOT_DIR/DESIGN.md"

# AC-15: session-start.mjs handles shipping status
if grep -q 'shipping' "$SESSION_START_MJS"; then
  pass "AC-15a: session-start.mjs handles shipping status"
else
  fail "AC-15a: session-start.mjs does not handle shipping status"
fi

# AC-15: plugin.ts handles shipping status
if grep -q 'shipping' "$PLUGIN_TS"; then
  pass "AC-15b: plugin.ts handles shipping status"
else
  fail "AC-15b: plugin.ts does not handle shipping status"
fi

# AC-15: Messages contain both "shipping" and "PR"/"pull request"
if grep -A3 'shipping' "$SESSION_START_MJS" | grep -qi 'PR\|pull request'; then
  pass "AC-15c: session-start.mjs shipping message mentions PR"
else
  fail "AC-15c: session-start.mjs shipping message doesn't mention PR"
fi

if grep -A3 'shipping' "$PLUGIN_TS" | grep -qi 'PR\|pull request'; then
  pass "AC-15d: plugin.ts shipping message mentions PR"
else
  fail "AC-15d: plugin.ts shipping message doesn't mention PR"
fi

# AC-17: DESIGN.md references shipping, PreToolUse, and evidence
if grep -q 'shipping' "$DESIGN_MD"; then
  pass "AC-17a: DESIGN.md references shipping state"
else
  fail "AC-17a: DESIGN.md does not reference shipping state"
fi

if grep -qi 'PreToolUse\|pre-tool\|pre-ship-guard' "$DESIGN_MD"; then
  pass "AC-17b: DESIGN.md references PreToolUse hook"
else
  fail "AC-17b: DESIGN.md does not reference PreToolUse hook"
fi

if grep -qi 'evidence.*integrity\|evidence.*sourc\|evidence.*file' "$DESIGN_MD"; then
  pass "AC-17c: DESIGN.md references evidence integrity"
else
  fail "AC-17c: DESIGN.md does not reference evidence integrity"
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
