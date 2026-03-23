#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Tests for sw-verify enriched handoff enhancement (AC1-AC6)
#
#   AC1: Actionable Findings table appears in aggregate report
#   AC2: Recommended Fix column contains actionable content
#   AC3: Summary line communicates fix scope
#   AC4: Existing handoff tiers preserved and extended
#   AC5: Stage boundary NOT violated
#   AC6: Token budget maintained
#
# Boundary classification: Internal (core skill definition validated via
# file reads and pattern matching, no mocks).
#
# Dependencies: bash
# Usage: bash tests/test-verify-enriched-handoff.sh
#   Exit 0 = all pass, exit 1 = any failure

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

# ═══════════════════════════════════════════════════════════════════════
# Pre-flight: file must exist
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC1-AC6: sw-verify enriched handoff tests ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "skills/sw-verify/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (file missing, cannot continue)"
  exit 1
fi

FULL_CONTENT=$(cat "$SKILL_FILE")

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

BODY=$(extract_body "$SKILL_FILE") || {
  fail "SKILL.md has body content after frontmatter"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (no body, cannot continue)"
  exit 1
}

# Extract aggregate report constraint section for focused checks
# Reserved for future use in scoped checks
_AGG_SECTION=$(echo "$BODY" | sed -n '/Aggregate report/,/^\*\*/p')

# ═══════════════════════════════════════════════════════════════════════
# AC1: Actionable Findings table appears in aggregate report
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC1: Actionable Findings table ==="

# AC1a: Section heading or label for actionable findings
if echo "$BODY" | grep -qi 'Actionable Findings'; then
  pass "AC1a: 'Actionable Findings' heading/label present"
else
  fail "AC1a: 'Actionable Findings' heading/label present"
fi

# AC1b: Table columns -- must mention the column names that form the table
# We check each column individually to prevent a partial implementation
# that omits one or two columns.
for col in "#" "Gate" "Severity" "File" "Finding" "Recommended Fix"; do
  if echo "$BODY" | grep -qi "$col"; then
    pass "AC1b: table column '$col' mentioned"
  else
    fail "AC1b: table column '$col' mentioned"
  fi
done

# AC1c: Table must be a pipe-delimited markdown table (not just prose)
# Check for the actual table row pattern: | something | something |
if echo "$BODY" | grep -qE '^\s*\|.*\|.*\|.*\|'; then
  pass "AC1c: pipe-delimited table row pattern present"
else
  fail "AC1c: pipe-delimited table row pattern present"
fi

# AC1d: Table header row specifically for actionable findings
# Must contain at least 4 of the 6 column names in a single pipe-delimited line
ACTION_TABLE_HEADER=$(echo "$BODY" | grep -iE '^\s*\|.*#.*\|.*Gate.*\|.*Severity.*\|' || true)
if [ -n "$ACTION_TABLE_HEADER" ]; then
  pass "AC1d: actionable findings table header row with #, Gate, Severity columns"
else
  fail "AC1d: actionable findings table header row with #, Gate, Severity columns"
fi

# AC1e: Table includes WARN and BLOCK (not INFO) -- must be in Actionable Findings context
AFTER_ACTIONABLE_1E=$(echo "$BODY" | sed -n '/Actionable Findings/,$p')
WARN_IN_AF=$(echo "$AFTER_ACTIONABLE_1E" | grep -ci 'WARN' || true)
BLOCK_IN_AF=$(echo "$AFTER_ACTIONABLE_1E" | grep -ci 'BLOCK' || true)
if [ "$WARN_IN_AF" -ge 1 ] && [ "$BLOCK_IN_AF" -ge 1 ]; then
  pass "AC1e: WARN and BLOCK both referenced in Actionable Findings context"
else
  fail "AC1e: WARN and BLOCK both referenced in Actionable Findings context (WARN=$WARN_IN_AF, BLOCK=$BLOCK_IN_AF)"
fi

# AC1f: INFO findings explicitly excluded from actionable table
if echo "$BODY" | grep -qi 'not INFO\|exclud.*INFO\|omit.*INFO\|INFO.*excluded\|INFO.*omit\|only WARN.*BLOCK\|only BLOCK.*WARN'; then
  pass "AC1f: INFO findings excluded from actionable table"
else
  fail "AC1f: INFO findings excluded from actionable table"
fi

# AC1g: Table conditional -- only shown when findings exist
if echo "$BODY" | grep -qi 'only.*when.*finding\|if.*finding.*exist\|when.*BLOCK\|when.*WARN\|omit.*all PASS\|skip.*all PASS\|not.*shown.*all PASS\|suppress.*when.*PASS'; then
  pass "AC1g: table shown only when findings exist (not when all PASS)"
else
  fail "AC1g: table shown only when findings exist (not when all PASS)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC2: Recommended Fix column contains actionable content
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC2: Recommended Fix column is actionable ==="

# AC2a: WARN findings get concrete fix suggestions (not just "fix it")
# Must appear in the Actionable Findings context, not the existing per-finding detail
AFTER_ACTIONABLE_2A=$(echo "$BODY" | sed -n '/Actionable Findings/,$p')
if echo "$AFTER_ACTIONABLE_2A" | grep -qi 'concrete.*fix\|specific.*fix\|actionable.*suggest\|fix.*suggestion\|remediation\|Recommended Fix'; then
  pass "AC2a: concrete fix suggestions in actionable findings context"
else
  fail "AC2a: concrete fix suggestions in actionable findings context"
fi

# AC2b: BLOCK findings that need human judgment get "manual review" or equivalent
if echo "$BODY" | grep -qi 'manual review\|human judgment\|manual.*inspection\|requires.*review\|needs.*judgment\|review.*required'; then
  pass "AC2b: BLOCK findings can indicate manual review needed"
else
  fail "AC2b: BLOCK findings can indicate manual review needed"
fi

# AC2c: File paths must be specific (not vague)
# Check that the spec mentions specific file paths or rejects "various files"
if echo "$BODY" | grep -qi 'specific.*file\|file.*path\|exact.*file\|actual.*path\|concrete.*path\|not.*various'; then
  pass "AC2c: specific file paths required (not vague references)"
else
  fail "AC2c: specific file paths required (not vague references)"
fi

# AC2d: Gate evidence is the source of findings for the actionable table
AFTER_ACTIONABLE_2D=$(echo "$BODY" | sed -n '/Actionable Findings/,$p')
if echo "$AFTER_ACTIONABLE_2D" | grep -qi 'evidence.*source\|from.*evidence\|gate.*evidence\|evidence.*finding\|sourced.*from.*gate\|drawn.*from.*evidence\|populate.*from.*evidence'; then
  pass "AC2d: gate evidence identified as source of actionable findings"
else
  fail "AC2d: gate evidence identified as source of actionable findings"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC3: Summary line communicates fix scope
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC3: Summary line with fix scope ==="

# AC3a: Count format like "N of M" or "N/M" or equivalent
if echo "$BODY" | grep -qi 'N of M\|N/M\|count.*of.*total\|X of Y\|{n}.*of.*{m}\|number.*of.*total\|findings.*count\|tally'; then
  pass "AC3a: count format (N of M or equivalent) present"
else
  fail "AC3a: count format (N of M or equivalent) present"
fi

# AC3b: Summary line explicitly tells user to resolve/address warns
# Must be in actionable-findings context, not the existing handoff tier text
AFTER_ACTIONABLE=$(echo "$BODY" | sed -n '/Actionable Findings/,$p')
if echo "$AFTER_ACTIONABLE" | grep -qi 'resolve.*warn\|address.*warn\|clear.*warn\|action.*warn\|fix.*warn'; then
  pass "AC3b: 'resolve the warns' or equivalent user action in actionable findings context"
else
  fail "AC3b: 'resolve the warns' or equivalent user action in actionable findings context"
fi

# AC3c: Handling for all-manual-review case
if echo "$BODY" | grep -qi 'all.*manual\|every.*manual\|all.*require.*review\|no.*auto.*fix\|none.*auto'; then
  pass "AC3c: handling for all-manual-review case"
else
  fail "AC3c: handling for all-manual-review case"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC4: Existing handoff tiers preserved and extended
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC4: Existing handoff tiers preserved ==="

# AC4a: BLOCK handoff preserved
if echo "$BODY" | grep -q 'Fix and re-run.*sw-verify\|Fix and re-run `/sw-verify`'; then
  pass "AC4a: BLOCK handoff 'Fix and re-run /sw-verify' preserved"
else
  fail "AC4a: BLOCK handoff 'Fix and re-run /sw-verify' preserved"
fi

# AC4b: WARN handoff preserved
if echo "$BODY" | grep -q 'Review, then fix or.*sw-ship\|Review, then fix or `/sw-ship`'; then
  pass "AC4b: WARN handoff 'Review, then fix or /sw-ship' preserved"
else
  fail "AC4b: WARN handoff 'Review, then fix or /sw-ship' preserved"
fi

# AC4c: PASS handoff preserved
if echo "$BODY" | grep -q 'Ready for.*sw-ship\|Ready for `/sw-ship`'; then
  pass "AC4c: PASS handoff 'Ready for /sw-ship' preserved"
else
  fail "AC4c: PASS handoff 'Ready for /sw-ship' preserved"
fi

# AC4d: All three tiers coexist (not replaced by a single new handoff)
BLOCK_HANDOFF=$(echo "$BODY" | grep -c 'Fix and re-run' || true)
WARN_HANDOFF=$(echo "$BODY" | grep -c 'Review, then fix or' || true)
PASS_HANDOFF=$(echo "$BODY" | grep -c 'Ready for' || true)
if [ "$BLOCK_HANDOFF" -ge 1 ] && [ "$WARN_HANDOFF" -ge 1 ] && [ "$PASS_HANDOFF" -ge 1 ]; then
  pass "AC4d: all three handoff tiers coexist"
else
  fail "AC4d: all three handoff tiers coexist (BLOCK=$BLOCK_HANDOFF, WARN=$WARN_HANDOFF, PASS=$PASS_HANDOFF)"
fi

# AC4e: Table is additive -- the existing per-finding detail and summary table
# must still be present alongside the new actionable findings table
if echo "$BODY" | grep -qi 'Per-finding detail\|per-finding'; then
  pass "AC4e: per-finding detail tier still present"
else
  fail "AC4e: per-finding detail tier still present"
fi

if echo "$BODY" | grep -qi 'Summary table\|summary.*table\|Gate.*Status.*Findings'; then
  pass "AC4f: summary table tier still present"
else
  fail "AC4f: summary table tier still present"
fi

# AC4g: The existing summary table pipe format is preserved
if echo "$BODY" | grep -qE '\|.*Gate.*\|.*Status.*\|.*Finding'; then
  pass "AC4g: existing summary table header '| Gate | Status | Findings |' preserved"
else
  fail "AC4g: existing summary table header '| Gate | Status | Findings |' preserved"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC5: Stage boundary NOT violated
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC5: Stage boundary preserved ==="

# AC5a: Core stage boundary statement preserved
if echo "$BODY" | grep -q 'You NEVER fix code, create PRs, or ship'; then
  pass "AC5a: 'You NEVER fix code, create PRs, or ship' preserved"
else
  fail "AC5a: 'You NEVER fix code, create PRs, or ship' preserved"
fi

# AC5b: No instructions to fix/modify/write code
# Search for imperative verbs that would violate stage boundary
VIOLATION_COUNT=0
for verb in "fix the code" "modify the file" "write the fix" "apply the fix" "patch the" "edit the file" "update the code" "change the file"; do
  if echo "$BODY" | grep -qi "$verb"; then
    VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
  fi
done
if [ "$VIOLATION_COUNT" -eq 0 ]; then
  pass "AC5b: no imperative code-fixing instructions found"
else
  fail "AC5b: found $VIOLATION_COUNT imperative code-fixing instructions"
fi

# AC5c: No new state transitions added beyond existing ones
# The existing transitions are: verifying (start), gate updates, no shipped
# Check that no new status values are introduced
NEW_STATUS_COUNT=$(echo "$BODY" | grep -oiE 'status.*to.*`[a-z-]+`' | grep -vic 'verifying\|shipped' || true)
if [ "$NEW_STATUS_COUNT" -eq 0 ]; then
  pass "AC5c: no new state transitions beyond verifying"
else
  fail "AC5c: found $NEW_STATUS_COUNT unexpected state transitions"
fi

# AC5d: Stage boundary protocol reference preserved
if echo "$BODY" | grep -q 'protocols/stage-boundary.md'; then
  pass "AC5d: protocols/stage-boundary.md reference preserved"
else
  fail "AC5d: protocols/stage-boundary.md reference preserved"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC6: Token budget maintained
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC6: Token budget ==="

WORD_COUNT=$(echo "$FULL_CONTENT" | wc -w | tr -d ' ')

if [ "$WORD_COUNT" -lt 1500 ]; then
  pass "AC6a: word count ($WORD_COUNT) is under 1500 ceiling"
else
  fail "AC6a: word count ($WORD_COUNT) is under 1500 ceiling"
fi

if [ "$WORD_COUNT" -gt 200 ]; then
  pass "AC6b: word count ($WORD_COUNT) is above 200 sanity floor"
else
  fail "AC6b: word count ($WORD_COUNT) is above 200 sanity floor"
fi

# ═══════════════════════════════════════════════════════════════════════
# Anti-bypass: Guards against sloppy implementations
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Anti-bypass: Implementation guards ==="

# Guard 1: The actionable findings table must be INSIDE the aggregate report
# constraint (not floating elsewhere). Check that "Actionable Findings" appears
# after "Aggregate report" heading.
AFTER_AGG=$(echo "$BODY" | sed -n '/Aggregate report/,$p')
if echo "$AFTER_AGG" | grep -qi 'Actionable Findings'; then
  pass "guard: Actionable Findings is within or after Aggregate report section"
else
  fail "guard: Actionable Findings is within or after Aggregate report section"
fi

# Guard 2: The table example must include BOTH the column header AND a separator
# row (standard markdown table format), not just prose about columns
TABLE_SEPARATOR=$(echo "$BODY" | grep -cE '^\s*\|[-: ]+\|[-: ]+\|' || true)
if [ "$TABLE_SEPARATOR" -ge 1 ]; then
  pass "guard: markdown table separator row present (|---|---|)"
else
  fail "guard: markdown table separator row present (|---|---|)"
fi

# Guard 3: "Recommended Fix" column must appear in actual table header, not just
# in prose text. Check for it inside a pipe-delimited line.
if echo "$BODY" | grep -iE '^\s*\|.*Recommended Fix.*\|' | grep -q '.'; then
  pass "guard: 'Recommended Fix' appears inside a table header row"
else
  fail "guard: 'Recommended Fix' appears inside a table header row"
fi

# Guard 4: The three existing report tiers must now be three or more
# (per-finding detail, summary table, actionable findings)
TIER_COUNT=0
echo "$BODY" | grep -qi 'Per-finding detail\|per-finding' && TIER_COUNT=$((TIER_COUNT + 1))
echo "$BODY" | grep -qi 'Summary table' && TIER_COUNT=$((TIER_COUNT + 1))
echo "$BODY" | grep -qi 'Actionable Findings' && TIER_COUNT=$((TIER_COUNT + 1))
if [ "$TIER_COUNT" -ge 3 ]; then
  pass "guard: at least 3 report tiers present ($TIER_COUNT found)"
else
  fail "guard: at least 3 report tiers present ($TIER_COUNT found)"
fi

# Guard 5: File column in table must be distinct from Finding column
# (prevents collapsing two concepts into one column)
FILE_COL=$(echo "$BODY" | grep -iE '^\s*\|.*File.*\|.*Finding.*\|' || true)
if [ -n "$FILE_COL" ]; then
  pass "guard: File and Finding are separate columns in table"
else
  fail "guard: File and Finding are separate columns in table"
fi

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════"
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"
echo "═══════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
