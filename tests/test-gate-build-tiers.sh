#!/usr/bin/env bash
#
# Tests for gate-build tiered test execution (AC-2, AC-3)
#
# Validates that core/skills/gate-build/SKILL.md specifies tiered
# execution of build and test commands with per-tier verdicts,
# evidence format, timeout, and visibility rules.
#
# Boundary classification: Internal (TESTING.md -- core skills are
# validated via file reads and pattern matching, no mocks).
#
# Dependencies: bash
# Usage: bash tests/test-gate-build-tiers.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/gate-build/SKILL.md"

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

assert_eq() {
  local actual="$1"
  local expected="$2"
  local label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

# Extract YAML frontmatter (content between first --- and second ---)
extract_frontmatter() {
  local file="$1"
  local first_line
  first_line=$(head -n 1 "$file")
  if [ "$first_line" != "---" ]; then
    return 1
  fi
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  head -n "$((closing_line + 1))" "$file" | tail -n +"2" | head -n "$((closing_line - 1))"
}

# Extract body content (everything after the closing --- of frontmatter)
extract_body() {
  local file="$1"
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  tail -n +"$((closing_line + 2))" "$file"
}

# ═══════════════════════════════════════════════════════════════════════
# Pre-flight: file must exist
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC-2, AC-3: gate-build tiered execution tests ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "core/skills/gate-build/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (file missing, cannot continue)"
  exit 1
fi

# Load file content once
_FM=$(extract_frontmatter "$SKILL_FILE") || {
  fail "SKILL.md has valid YAML frontmatter"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (no frontmatter, cannot continue)"
  exit 1
}
BODY=$(extract_body "$SKILL_FILE") || {
  fail "SKILL.md has body content after frontmatter"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (no body, cannot continue)"
  exit 1
}

# ═══════════════════════════════════════════════════════════════════════
# AC-2: All four tiers are specified
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC-2: Tier names ==="

# Each of the four tier names must appear in the skill body.
# A lazy impl that only mentions "build" and "test" will fail on
# the integration and smoke tiers.

if echo "$BODY" | grep -qi 'commands\.build\|tier.*build\b'; then
  pass "tier: build command referenced"
else
  fail "tier: build command referenced"
fi

if echo "$BODY" | grep -qi 'commands\.test\b'; then
  pass "tier: test command referenced"
else
  fail "tier: test command referenced"
fi

if echo "$BODY" | grep -qi 'test:integration'; then
  pass "tier: test:integration command referenced"
else
  fail "tier: test:integration command referenced"
fi

if echo "$BODY" | grep -qi 'test:smoke'; then
  pass "tier: test:smoke command referenced"
else
  fail "tier: test:smoke command referenced"
fi

# All four must be present -- not just two of four.
# Count distinct tier references to block partial implementations.
TIER_BUILD=$(echo "$BODY" | grep -ci 'commands\.build\|tier.*build' || true)
TIER_TEST=$(echo "$BODY" | grep -ci 'commands\.test\b' || true)
TIER_INTEGRATION=$(echo "$BODY" | grep -ci 'test:integration' || true)
TIER_SMOKE=$(echo "$BODY" | grep -ci 'test:smoke' || true)
TIER_COUNT=0
[ "$TIER_BUILD" -ge 1 ] && TIER_COUNT=$((TIER_COUNT + 1))
[ "$TIER_TEST" -ge 1 ] && TIER_COUNT=$((TIER_COUNT + 1))
[ "$TIER_INTEGRATION" -ge 1 ] && TIER_COUNT=$((TIER_COUNT + 1))
[ "$TIER_SMOKE" -ge 1 ] && TIER_COUNT=$((TIER_COUNT + 1))
assert_eq "$TIER_COUNT" "4" "all 4 tiers mentioned (build, test, test:integration, test:smoke)"

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Execution order is specified (build first, smoke last)
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Execution order ==="

# The skill must specify execution order. We check that "build" appears
# BEFORE "test:smoke" in the body, and that the ordering is explicit
# (not just randomly scattered mentions).

# Must explicitly mention ordering/sequence of tiers
if echo "$BODY" | grep -qi 'order\|sequence\|first.*last\|in order\|tier.*order\|execution.*order'; then
  pass "execution order is explicitly mentioned"
else
  fail "execution order is explicitly mentioned"
fi

# Build must appear before smoke in the document (structural ordering).
# This catches an impl that lists tiers but in wrong order.
BUILD_LINE=$(echo "$BODY" | grep -ni 'build' | head -n 1 | cut -d: -f1)
SMOKE_LINE=$(echo "$BODY" | grep -ni 'test:smoke' | head -n 1 | cut -d: -f1)
if [ -n "$BUILD_LINE" ] && [ -n "$SMOKE_LINE" ]; then
  if [ "$BUILD_LINE" -lt "$SMOKE_LINE" ]; then
    pass "build tier appears before test:smoke tier in document"
  else
    fail "build tier appears before test:smoke tier in document (build at line $BUILD_LINE, smoke at line $SMOKE_LINE)"
  fi
else
  fail "build tier appears before test:smoke tier in document (one or both not found)"
fi

# The full ordering must be: build -> test -> test:integration -> test:smoke
# Verify test:integration appears before test:smoke
INTEGRATION_LINE=$(echo "$BODY" | grep -ni 'test:integration' | head -n 1 | cut -d: -f1)
if [ -n "$INTEGRATION_LINE" ] && [ -n "$SMOKE_LINE" ]; then
  if [ "$INTEGRATION_LINE" -lt "$SMOKE_LINE" ]; then
    pass "test:integration appears before test:smoke in document"
  else
    fail "test:integration appears before test:smoke in document (integration at line $INTEGRATION_LINE, smoke at line $SMOKE_LINE)"
  fi
else
  fail "test:integration appears before test:smoke in document (one or both not found)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Per-tier verdict mapping
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Per-tier verdicts ==="

# test and test:integration failures must produce FAIL verdict.
# A sloppy impl might make everything WARN or everything FAIL.

# test = FAIL on failure
if echo "$BODY" | grep -qi 'test.*FAIL\|FAIL.*test'; then
  pass "test tier failure produces FAIL verdict"
else
  fail "test tier failure produces FAIL verdict"
fi

# test:integration = FAIL on failure
if echo "$BODY" | grep -qi 'integration.*FAIL\|FAIL.*integration'; then
  pass "test:integration tier failure produces FAIL verdict"
else
  fail "test:integration tier failure produces FAIL verdict"
fi

# test:smoke = WARN on failure (NOT FAIL -- this is the key distinction)
if echo "$BODY" | grep -qi 'smoke.*WARN\|WARN.*smoke'; then
  pass "test:smoke tier failure produces WARN verdict (not FAIL)"
else
  fail "test:smoke tier failure produces WARN verdict (not FAIL)"
fi

# Negative: smoke must NOT produce FAIL (catch impl that makes all tiers FAIL)
if echo "$BODY" | grep -qi 'smoke.*FAIL\b'; then
  fail "test:smoke must NOT produce FAIL on failure (should be WARN)"
else
  pass "test:smoke does not produce FAIL on failure"
fi

# Unconfigured tiers = SKIP
if echo "$BODY" | grep -qi 'unconfigured.*SKIP\|null.*SKIP\|missing.*SKIP\|SKIP.*unconfigured\|SKIP.*null\|not configured.*SKIP'; then
  pass "unconfigured tier produces SKIP verdict"
else
  fail "unconfigured tier produces SKIP verdict"
fi

# WARN and FAIL and SKIP must all be distinctly mentioned as tier outcomes
FAIL_VERDICT=$(echo "$BODY" | grep -ci '\bFAIL\b' || true)
WARN_VERDICT=$(echo "$BODY" | grep -ci '\bWARN\b' || true)
SKIP_VERDICT=$(echo "$BODY" | grep -ci '\bSKIP\b' || true)
if [ "$FAIL_VERDICT" -ge 1 ] && [ "$WARN_VERDICT" -ge 1 ] && [ "$SKIP_VERDICT" -ge 1 ]; then
  pass "all three verdict types present: FAIL, WARN, SKIP"
else
  fail "all three verdict types present (FAIL=$FAIL_VERDICT, WARN=$WARN_VERDICT, SKIP=$SKIP_VERDICT)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Per-tier evidence sections
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Per-tier evidence format ==="

# Each tier must produce its own section in evidence with:
# command, exit code, output, duration

# Evidence must mention per-tier sections (not just one combined blob)
if echo "$BODY" | grep -qi 'per.tier.*section\|section.*per.*tier\|each tier.*section\|tier.*its own.*section\|separate.*section.*tier\|tier.*evidence.*section'; then
  pass "evidence specifies per-tier sections"
else
  fail "evidence specifies per-tier sections"
fi

# Evidence must capture command that was run
if echo "$BODY" | grep -qi 'command.*run\|command.*executed\|command.*capture\|capture.*command'; then
  pass "evidence captures command run"
else
  fail "evidence captures command run"
fi

# Evidence must capture exit code
if echo "$BODY" | grep -qi 'exit code\|exit.code\|return code'; then
  pass "evidence captures exit code"
else
  fail "evidence captures exit code"
fi

# Evidence must capture output (stdout/stderr)
if echo "$BODY" | grep -qi 'stdout\|stderr\|output'; then
  pass "evidence captures output"
else
  fail "evidence captures output"
fi

# Evidence must capture duration
if echo "$BODY" | grep -qi 'duration\|elapsed\|time.*taken\|wall.time\|execution.*time'; then
  pass "evidence captures duration per tier"
else
  fail "evidence captures duration per tier"
fi

# Evidence must start with a header describing tier layout
if echo "$BODY" | grep -qi 'header.*tier\|tier.*header\|tier.*layout\|layout.*header\|summary.*tier.*layout\|tier.*overview.*header'; then
  pass "evidence starts with tier layout header"
else
  fail "evidence starts with tier layout header"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Timeout remains 5 minutes per command
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Timeout ==="

# Must specify 5-minute timeout (not some other value)
if echo "$BODY" | grep -qi '5 minute\|5.minute\|five minute\|300.*second\|5 min'; then
  pass "timeout specified as 5 minutes per command"
else
  fail "timeout specified as 5 minutes per command"
fi

# Timeout must apply per command (not total across all tiers)
if echo "$BODY" | grep -qi 'per command\|each command\|per tier\|each tier'; then
  pass "timeout applies per command (not total)"
else
  fail "timeout applies per command (not total)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Backwards compatibility -- all null = SKIP
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Backwards compatibility ==="

# When ALL tiers are null/unconfigured, gate = SKIP.
# This is existing behavior that must be preserved.
# The test must verify this is still stated with the expanded tier set.
if echo "$BODY" | grep -qi 'all.*null.*SKIP\|all.*command.*null.*SKIP\|all.*tier.*null.*SKIP\|all.*unconfigured.*SKIP\|both.*null.*SKIP\|every.*tier.*null.*SKIP'; then
  pass "when all tiers null, gate status is SKIP"
else
  fail "when all tiers null, gate status is SKIP"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-3: Visibility rule -- INFO note when tiers unconfigured
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-3: Visibility rule ==="

# Must mention INFO level note/message when tiers are unconfigured
if echo "$BODY" | grep -qi 'INFO.*unconfigured\|INFO.*not configured\|INFO.*tier.*not\|unconfigured.*INFO\|INFO.*note.*tier\|INFO.*missing.*tier'; then
  pass "INFO note when tiers are unconfigured"
else
  fail "INFO note when tiers are unconfigured"
fi

# Must be INFO specifically (not WARN, not ERROR) for unconfigured tiers
# This is a visibility note, not a problem indicator
if echo "$BODY" | grep -qi 'INFO'; then
  pass "uses INFO level (not WARN/ERROR) for unconfigured tiers"
else
  fail "uses INFO level (not WARN/ERROR) for unconfigured tiers"
fi

# Must mention visibility or note concept specifically for unconfigured tiers
# (not just generic "show user" language about test output)
if echo "$BODY" | grep -qi 'note.*unconfigured\|display.*unconfigured\|emit.*INFO.*tier\|INFO.*note\|visibility.*tier\|tier.*visibility'; then
  pass "visibility rule explicitly described for unconfigured tiers"
else
  fail "visibility rule explicitly described for unconfigured tiers"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Charter invariant 3 exception for smoke tier
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Charter invariant exception for smoke ==="

# Smoke tier uses WARN instead of FAIL, which may conflict with
# charter invariant 3 (quality gates default to FAIL). The skill
# must document this exception or rationale.
if echo "$BODY" | grep -qi 'charter.*invariant.*smoke\|smoke.*charter.*invariant\|charter.*exception.*smoke\|smoke.*exception\|invariant.*3.*smoke\|smoke.*invariant.*3\|charter.*3.*smoke\|smoke.*WARN.*charter\|charter.*smoke.*WARN'; then
  pass "charter invariant 3 exception documented for smoke tier"
else
  fail "charter invariant 3 exception documented for smoke tier"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Inputs reference the new config paths
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Config paths for new tiers ==="

# Inputs must reference commands.test:integration and commands.test:smoke
# (or equivalent config paths). A lazy impl might add tier names to the
# body but forget to update the Inputs section.

if echo "$BODY" | grep -qi 'commands.*test:integration\|test:integration.*config\|config.*test:integration'; then
  pass "inputs reference commands.test:integration config path"
else
  fail "inputs reference commands.test:integration config path"
fi

if echo "$BODY" | grep -qi 'commands.*test:smoke\|test:smoke.*config\|config.*test:smoke'; then
  pass "inputs reference commands.test:smoke config path"
else
  fail "inputs reference commands.test:smoke config path"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Failure Modes updated for new tiers
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Failure modes for new tiers ==="

# The Failure Modes table/section must cover the new tiers
FM_SECTION=$(echo "$BODY" | sed -n '/^## Failure Modes/,/^## /p')

if [ -n "$FM_SECTION" ]; then
  # Must mention integration tier failure handling
  if echo "$FM_SECTION" | grep -qi 'integration'; then
    pass "failure modes mention test:integration tier"
  else
    fail "failure modes mention test:integration tier"
  fi

  # Must mention smoke tier failure handling
  if echo "$FM_SECTION" | grep -qi 'smoke'; then
    pass "failure modes mention test:smoke tier"
  else
    fail "failure modes mention test:smoke tier"
  fi
else
  fail "failure modes mention test:integration tier (section missing)"
  fail "failure modes mention test:smoke tier (section missing)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Anti-bypass: Hardcoded / partial implementation guards
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Anti-bypass: Implementation guards ==="

# Guard 1: Smoke must have DIFFERENT verdict than test/integration.
# A lazy impl might give all tiers the same verdict.
# We already checked smoke=WARN above and test/integration=FAIL.
# Cross-check: the document must mention WARN at least once AND
# in the same context as smoke (not just a stray WARN somewhere).
WARN_NEAR_SMOKE=$(echo "$BODY" | grep -ci 'smoke.*WARN\|WARN.*smoke' || true)
if [ "$WARN_NEAR_SMOKE" -ge 1 ]; then
  pass "WARN verdict is specifically associated with smoke tier"
else
  fail "WARN verdict is specifically associated with smoke tier"
fi

# Guard 2: Must mention all 4 tiers in the Constraints section
# (not just in a random paragraph). A lazy impl might scatter tier
# names without actually constraining execution.
CONSTRAINTS_SECTION=$(echo "$BODY" | sed -n '/^## Constraints/,/^## /p')
if [ -n "$CONSTRAINTS_SECTION" ]; then
  CONSTRAINTS_TIERS=0
  echo "$CONSTRAINTS_SECTION" | grep -qi 'build' && CONSTRAINTS_TIERS=$((CONSTRAINTS_TIERS + 1))
  echo "$CONSTRAINTS_SECTION" | grep -qi 'test:integration' && CONSTRAINTS_TIERS=$((CONSTRAINTS_TIERS + 1))
  echo "$CONSTRAINTS_SECTION" | grep -qi 'test:smoke' && CONSTRAINTS_TIERS=$((CONSTRAINTS_TIERS + 1))
  if [ "$CONSTRAINTS_TIERS" -ge 3 ]; then
    pass "Constraints section references at least 3 tier types (build, integration, smoke)"
  else
    fail "Constraints section references at least 3 tier types ($CONSTRAINTS_TIERS found)"
  fi
else
  fail "Constraints section references at least 3 tier types (section missing)"
fi

# Guard 3: Per-tier evidence must mention BOTH "section" and "duration"
# concepts -- a partial impl might add sections but forget duration tracking.
SECTION_AND_DURATION=$(echo "$BODY" | grep -ci 'section' || true)
DURATION_COUNT=$(echo "$BODY" | grep -ci 'duration\|elapsed' || true)
if [ "$SECTION_AND_DURATION" -ge 1 ] && [ "$DURATION_COUNT" -ge 1 ]; then
  pass "evidence mentions both per-tier sections and duration tracking"
else
  fail "evidence mentions both per-tier sections and duration tracking (sections=$SECTION_AND_DURATION, duration=$DURATION_COUNT)"
fi

# Guard 4: The word "tier" or "tiered" must appear multiple times.
# A minimal patch that just adds tier names without structural
# tiered execution concept would be caught.
TIER_WORD_COUNT=$(echo "$BODY" | grep -ci '\btier\b\|tiered' || true)
if [ "$TIER_WORD_COUNT" -ge 3 ]; then
  pass "tier/tiered concept appears at least 3 times ($TIER_WORD_COUNT found)"
else
  fail "tier/tiered concept appears at least 3 times ($TIER_WORD_COUNT found)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Cross-cutting: Constitution compliance
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Cross-cutting: Constitution compliance ==="

# Constitution says skills define goals and constraints, never procedures.
NUMBERED_STEPS=$(echo "$BODY" | grep -cE '^\s*(Step )?[0-9]+\.' || true)
if [ "$NUMBERED_STEPS" -gt 5 ]; then
  fail "skill defines goals/constraints, not procedures ($NUMBERED_STEPS numbered steps found)"
else
  pass "skill defines goals/constraints, not procedures ($NUMBERED_STEPS numbered steps)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════"
echo "RESULT: $PASS passed, $FAIL failed"
echo "═══════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
