#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Tests for skills/sw-review/SKILL.md (AC1-AC7, AC9)
#
# Validates the skill definition file structure and content against
# acceptance criteria.
#
# Boundary classification: Internal (TESTING.md -- core skills are
# validated via file reads and pattern matching, no mocks).
#
# Dependencies: bash
# Usage: bash tests/test-sw-review-skill.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/sw-review/SKILL.md"

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

# Extract allowed-tools list items from YAML frontmatter
extract_allowed_tools() {
  local fm="$1"
  echo "$fm" | sed -n '/^allowed-tools:/,/^[^ ]/{/^  - /p;}' | sed 's/^  - //'
}

# ═══════════════════════════════════════════════════════════════════════
# Pre-flight: file must exist
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC1-AC7, AC9: sw-review skill definition tests ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "skills/sw-review/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (file missing, cannot continue)"
  exit 1
fi

# Load file content once
FM=$(extract_frontmatter "$SKILL_FILE") || {
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
FULL_CONTENT=$(cat "$SKILL_FILE")
TOOLS=$(extract_allowed_tools "$FM")

# ═══════════════════════════════════════════════════════════════════════
# AC1: SKILL.md follows skill anatomy template
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC1: Skill anatomy template ==="

# --- Frontmatter fields ---

echo "--- Frontmatter fields ---"

FM_NAME=$(echo "$FM" | grep '^name:' | sed 's/^name: *//')
assert_eq "$FM_NAME" "sw-review" "frontmatter name is 'sw-review'"

FM_DESC=$(echo "$FM" | grep -c '^description:')
if [ "$FM_DESC" -ge 1 ]; then
  pass "frontmatter has description field"
else
  fail "frontmatter has description field"
fi

# Description must be non-empty (not just "description:")
FM_DESC_VAL=$(echo "$FM" | grep '^description:' | sed 's/^description: *//')
if [ -n "$FM_DESC_VAL" ] && [ ${#FM_DESC_VAL} -ge 10 ]; then
  pass "frontmatter description is non-trivial (${#FM_DESC_VAL} chars)"
else
  fail "frontmatter description is non-trivial (got '${FM_DESC_VAL:-}')"
fi

FM_HINT=$(echo "$FM" | grep -c '^argument-hint:')
if [ "$FM_HINT" -ge 1 ]; then
  pass "frontmatter has argument-hint field"
else
  fail "frontmatter has argument-hint field"
fi

FM_TOOLS=$(echo "$FM" | grep -c '^allowed-tools:')
if [ "$FM_TOOLS" -ge 1 ]; then
  pass "frontmatter has allowed-tools field"
else
  fail "frontmatter has allowed-tools field"
fi

# --- Allowed tools: required tools present ---

echo "--- Allowed tools ---"

for required_tool in Read Bash Grep AskUserQuestion; do
  if echo "$TOOLS" | grep -qx "$required_tool"; then
    pass "allowed-tools includes $required_tool"
  else
    fail "allowed-tools includes $required_tool"
  fi
done

# --- Allowed tools: Write must NOT be present (AC7 -- no state mutation) ---

if echo "$TOOLS" | grep -qx "Write"; then
  fail "allowed-tools does NOT include Write (no state mutation)"
else
  pass "allowed-tools does NOT include Write (no state mutation)"
fi

# --- Required sections ---

echo "--- Required sections ---"

for section in "Goal" "Inputs" "Outputs" "Constraints" "Protocol References" "Failure Modes"; do
  if echo "$BODY" | grep -q "^## $section"; then
    pass "has required section: $section"
  else
    fail "has required section: $section"
  fi
done

# --- Word count ---

echo "--- Word count ---"

WORD_COUNT=$(echo "$FULL_CONTENT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt 1500 ]; then
  pass "word count ($WORD_COUNT) is under 1500"
else
  fail "word count ($WORD_COUNT) is under 1500"
fi

if [ "$WORD_COUNT" -gt 200 ]; then
  pass "word count ($WORD_COUNT) is above 200 (non-trivial content)"
else
  fail "word count ($WORD_COUNT) is above 200 (non-trivial content)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC2: PR detection from current branch
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC2: PR detection from current branch ==="

# Must mention detecting current branch
if echo "$BODY" | grep -q 'git branch --show-current'; then
  pass "mentions 'git branch --show-current' for branch detection"
else
  fail "mentions 'git branch --show-current' for branch detection"
fi

# Must mention PR discovery via gh pr list --head
if echo "$BODY" | grep -q 'gh pr list.*--head\|--head.*gh pr list'; then
  pass "mentions 'gh pr list --head' for PR discovery"
else
  fail "mentions 'gh pr list --head' for PR discovery"
fi

# Must handle merged PRs (not just open)
if echo "$BODY" | grep -qi '\-\-state merged\|merged.*PR\|merged.*fallback\|state.*merged'; then
  pass "mentions merged PR fallback (--state merged or equivalent)"
else
  fail "mentions merged PR fallback (--state merged or equivalent)"
fi

# Must handle multiple PRs via AskUserQuestion disambiguation
if echo "$BODY" | grep -qi 'multiple.*PR.*AskUser\|disambiguat\|AskUserQuestion.*multiple\|more than one.*PR\|multiple.*pull request'; then
  pass "mentions AskUserQuestion for multiple PR disambiguation"
else
  fail "mentions AskUserQuestion for multiple PR disambiguation"
fi

# Must reference prTool config
if echo "$BODY" | grep -qi 'config\.git\.prTool\|prTool.*config\|config.*prTool\|prTool'; then
  pass "mentions prTool config"
else
  fail "mentions prTool config"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC3: All three comment types are fetched
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC3: Three comment types ==="

# Issue comments (general PR conversation)
if echo "$BODY" | grep -qi '/issues/.*comments\|issue.*comment\|issues/{.*}/comments'; then
  pass "mentions issue comments via REST"
else
  fail "mentions issue comments via REST (/issues/{n}/comments)"
fi

# Review comments (inline code comments)
if echo "$BODY" | grep -qi '/pulls/.*comments\|review.*comment\|pulls/{.*}/comments\|pull.*request.*comment'; then
  pass "mentions review comments via REST"
else
  fail "mentions review comments via REST (/pulls/{n}/comments)"
fi

# Thread resolution state via GraphQL
if echo "$BODY" | grep -qi 'reviewThreads\|isResolved\|graphql.*thread\|thread.*resolution\|GraphQL.*resolv'; then
  pass "mentions GraphQL for thread resolution state"
else
  fail "mentions GraphQL for thread resolution state (reviewThreads/isResolved)"
fi

# All three comment types must be DISTINCTLY mentioned (not just one catch-all)
ISSUE_COMMENTS=$(echo "$BODY" | grep -ci 'issue.*comment' || true)
REVIEW_COMMENTS=$(echo "$BODY" | grep -ci 'review.*comment' || true)
THREAD_RESOLUTION=$(echo "$BODY" | grep -ci 'thread.*resol\|isResolved\|reviewThread' || true)
if [ "$ISSUE_COMMENTS" -ge 1 ] && [ "$REVIEW_COMMENTS" -ge 1 ] && [ "$THREAD_RESOLUTION" -ge 1 ]; then
  pass "all three comment types distinctly mentioned"
else
  fail "all three comment types distinctly mentioned (issue=$ISSUE_COMMENTS, review=$REVIEW_COMMENTS, threads=$THREAD_RESOLUTION)"
fi

# Must mention a cap or truncation limit
if echo "$BODY" | grep -qi 'cap\|truncat\|limit.*50\|50.*limit\|maximum.*comment\|comment.*maximum\|first.*50\|--per-page'; then
  pass "mentions comment cap/limit/truncation"
else
  fail "mentions comment cap/limit/truncation"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC4: Comments grouped by status and priority
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC4: Comment grouping by status and priority ==="

# Unresolved threads as highest priority
if echo "$BODY" | grep -qi 'unresolved.*highest\|unresolved.*priority\|unresolved.*first\|priority.*unresolved\|highest.*unresolved'; then
  pass "unresolved threads identified as highest priority"
else
  fail "unresolved threads identified as highest priority"
fi

# Grouping/categorization of comments
if echo "$BODY" | grep -qi 'group\|categor\|section\|bucket\|cluster\|organiz'; then
  pass "mentions grouping or categorization of comments"
else
  fail "mentions grouping or categorization of comments"
fi

# Author display
if echo "$BODY" | grep -qi 'author'; then
  pass "mentions author in comment display"
else
  fail "mentions author in comment display"
fi

# Timestamp display
if echo "$BODY" | grep -qi 'timestamp\|date\|time\|created_at\|createdAt'; then
  pass "mentions timestamp in comment display"
else
  fail "mentions timestamp in comment display"
fi

# File/line context display
if echo "$BODY" | grep -qi 'file.*line\|line.*file\|path.*line\|diff_hunk\|diffHunk\|file.*path'; then
  pass "mentions file/line context in comment display"
else
  fail "mentions file/line context in comment display"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC5: User can respond to comments
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC5: User can respond to comments ==="

# Posting replies via gh api
if echo "$BODY" | grep -qi 'gh api.*POST\|POST.*gh api\|gh api.*reply\|post.*reply\|reply.*comment'; then
  pass "mentions posting replies via gh api"
else
  fail "mentions posting replies via gh api"
fi

# resolveReviewThread GraphQL mutation
if echo "$BODY" | grep -qi 'resolveReviewThread'; then
  pass "mentions resolveReviewThread GraphQL mutation"
else
  fail "mentions resolveReviewThread GraphQL mutation"
fi

# Must use Pattern P3 or gh api (not gh pr edit which is wrong for comments)
if echo "$BODY" | grep -q 'gh api'; then
  pass "uses 'gh api' for GitHub interactions"
else
  fail "uses 'gh api' for GitHub interactions (Pattern P3)"
fi

# Negative check: must NOT use gh pr edit for comment replies
if echo "$BODY" | grep -qi 'gh pr edit.*comment\|gh pr edit.*reply'; then
  fail "must NOT use 'gh pr edit' for comment operations"
else
  pass "does not use 'gh pr edit' for comment operations"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC6: Graceful degradation without gh
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC6: Graceful degradation without gh ==="

# Must mention constructing PR URL from remote
if echo "$BODY" | grep -qi 'remote.*url\|construct.*URL\|PR.*URL.*remote\|url.*remote\|git remote'; then
  pass "mentions constructing PR URL from remote URL"
else
  fail "mentions constructing PR URL from remote URL"
fi

# Must mention install/missing gh message
if echo "$BODY" | grep -qi 'install.*gh\|gh.*install\|gh.*missing\|gh.*not.*found\|gh.*unavailable\|gh CLI'; then
  pass "mentions install gh CLI message or equivalent"
else
  fail "mentions install gh CLI message or equivalent"
fi

# Must NOT use STOP/abort for missing gh -- graceful degradation
if echo "$BODY" | grep -qi 'STOP.*gh\|abort.*gh\|fail.*gh.*missing\|halt.*gh'; then
  fail "must NOT STOP/abort for missing gh (should degrade gracefully)"
else
  pass "does not STOP/abort for missing gh (graceful degradation)"
fi

# Positive: must explicitly mention degrade/fallback behavior
if echo "$BODY" | grep -qi 'degrad\|fallback\|without.*gh\|gh.*not.*available\|gh.*absent'; then
  pass "explicitly describes degraded/fallback behavior without gh"
else
  fail "explicitly describes degraded/fallback behavior without gh"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC7: No workflow state mutation
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC7: No workflow state mutation ==="

# Must NOT mention modifying/writing/updating workflow.json
if echo "$BODY" | grep -qi 'modify.*workflow\.json\|write.*workflow\.json\|update.*workflow\.json\|mutate.*workflow'; then
  fail "must NOT mention modifying workflow.json"
else
  pass "does not mention modifying workflow.json"
fi

# Must NOT mention acquiring a lock
if echo "$BODY" | grep -qi 'acquire.*lock\|take.*lock\|obtain.*lock\|lock.*acquire\|lockfile'; then
  fail "must NOT mention acquiring a lock"
else
  pass "does not mention acquiring a lock"
fi

# Positive: should explicitly state read-only / no mutation / utility constraint
if echo "$BODY" | grep -qi 'read.only\|read only\|no.*mutation\|never.*modif\|does not.*modify\|no.*state.*change\|never.*write.*state\|utility.*skill\|stateless'; then
  pass "explicitly states read-only or no-mutation constraint"
else
  fail "explicitly states read-only or no-mutation constraint"
fi

# Write must not be in allowed-tools (already checked in AC1 but verify independently)
if echo "$TOOLS" | grep -qx "Write"; then
  fail "AC7 cross-check: Write not in allowed-tools"
else
  pass "AC7 cross-check: Write not in allowed-tools"
fi

# Must not mention TodoWrite or any write-capable tools
if echo "$TOOLS" | grep -qx "TodoWrite"; then
  fail "allowed-tools does NOT include TodoWrite"
else
  pass "allowed-tools does NOT include TodoWrite"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC9: Failure modes cover edge cases
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC9: Failure modes ==="

# Extract Failure Modes section content
FM_SECTION=$(echo "$BODY" | sed -n '/^## Failure Modes/,/^## /p')

if [ -n "$FM_SECTION" ]; then
  pass "Failure Modes section has content"
else
  fail "Failure Modes section has content"
fi

# Failure mode: detached HEAD
if echo "$FM_SECTION" | grep -qi 'detached.*HEAD\|HEAD.*detached'; then
  pass "failure mode: detached HEAD"
else
  fail "failure mode: detached HEAD"
fi

# Failure mode: no PR found
if echo "$FM_SECTION" | grep -qi 'no PR\|no.*pull request\|PR.*not.*found\|no.*associated.*PR'; then
  pass "failure mode: no PR found"
else
  fail "failure mode: no PR found"
fi

# Failure mode: no comments
if echo "$FM_SECTION" | grep -qi 'no comment\|zero comment\|no.*review.*comment\|empty.*comment\|comment.*empty'; then
  pass "failure mode: no comments"
else
  fail "failure mode: no comments"
fi

# Failure mode: rate limit
if echo "$FM_SECTION" | grep -qi 'rate.*limit\|rate.limit\|API.*limit\|throttl'; then
  pass "failure mode: rate limit"
else
  fail "failure mode: rate limit"
fi

# At least 4 distinct failure mode bullet entries
if [ -n "$FM_SECTION" ]; then
  FM_BULLET_COUNT=$(echo "$FM_SECTION" | grep -c '^[[:space:]]*[-*]' || true)
  if [ "$FM_BULLET_COUNT" -ge 4 ]; then
    pass "at least 4 failure mode entries ($FM_BULLET_COUNT found)"
  else
    fail "at least 4 failure mode entries ($FM_BULLET_COUNT found)"
  fi
else
  fail "at least 4 failure mode entries (section missing)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Cross-cutting: Protocol references
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Cross-cutting: Protocol references ==="

# Must reference git protocol (PR operations)
if echo "$BODY" | grep -q 'protocols/git'; then
  pass "references protocols/git.md"
else
  fail "references protocols/git.md"
fi

# Must reference headless protocol (standard for skills with AskUserQuestion)
if echo "$BODY" | grep -q 'protocols/headless'; then
  pass "references protocols/headless.md"
else
  fail "references protocols/headless.md"
fi

# Must reference context protocol (for config loading)
if echo "$BODY" | grep -q 'protocols/context\|protocols/state'; then
  pass "references protocols/context.md or protocols/state.md"
else
  fail "references protocols/context.md or protocols/state.md"
fi

# ═══════════════════════════════════════════════════════════════════════
# Cross-cutting: Constitution compliance
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Cross-cutting: Constitution compliance ==="

# Constitution says skills define goals and constraints, never procedures.
# Check that the file does NOT contain step-by-step numbered procedures.
NUMBERED_STEPS=$(echo "$BODY" | grep -cE '^\s*(Step )?[0-9]+\.' || true)
if [ "$NUMBERED_STEPS" -gt 5 ]; then
  fail "skill defines goals/constraints, not procedures ($NUMBERED_STEPS numbered steps found)"
else
  pass "skill defines goals/constraints, not procedures ($NUMBERED_STEPS numbered steps)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Anti-bypass: Hardcoded / partial implementation guards
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Anti-bypass: Implementation guards ==="

# Guard: Must mention BOTH gh api AND GraphQL (not just one API style)
GH_API_COUNT=$(echo "$BODY" | grep -ci 'gh api' || true)
GRAPHQL_COUNT=$(echo "$BODY" | grep -ci 'graphql\|GraphQL' || true)
if [ "$GH_API_COUNT" -ge 1 ] && [ "$GRAPHQL_COUNT" -ge 1 ]; then
  pass "mentions both gh api REST and GraphQL approaches"
else
  fail "mentions both gh api REST and GraphQL approaches (REST=$GH_API_COUNT, GraphQL=$GRAPHQL_COUNT)"
fi

# Guard: Must mention both reading AND writing (reply/resolve) operations
READ_OP_COUNT=$(echo "$BODY" | grep -ci 'fetch.*comment\|list.*comment\|get.*comment\|read.*comment\|retrieve' || true)
WRITE_OP_COUNT=$(echo "$BODY" | grep -ci 'reply\|resolve\|post.*comment\|respond' || true)
if [ "$READ_OP_COUNT" -ge 1 ] && [ "$WRITE_OP_COUNT" -ge 1 ]; then
  pass "covers both read (fetch comments) and write (reply/resolve) operations"
else
  fail "covers both read and write operations (read=$READ_OP_COUNT, write=$WRITE_OP_COUNT)"
fi

# Guard: PR detection must not be just "ask user for PR number" -- must autodetect
if echo "$BODY" | grep -qi 'git branch --show-current' && echo "$BODY" | grep -qi 'gh pr list'; then
  pass "PR detection autodetects from branch (not just user input)"
else
  fail "PR detection autodetects from branch (not just user input)"
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
