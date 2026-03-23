#!/usr/bin/env bash
#
# Tests for skills/sw-sync/SKILL.md (AC1-AC7, AC9)
#
# Validates the skill definition file structure and content against
# acceptance criteria.
#
# Boundary classification: Internal (TESTING.md -- core skills are
# validated via file reads and pattern matching, no mocks).
#
# Dependencies: bash
# Usage: bash tests/test-sw-sync-skill.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/sw-sync/SKILL.md"

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

echo "=== AC1-AC7, AC9: sw-sync skill definition tests ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "skills/sw-sync/SKILL.md exists"
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
assert_eq "$FM_NAME" "sw-sync" "frontmatter name is 'sw-sync'"

FM_DESC=$(echo "$FM" | grep -c '^description:')
if [ "$FM_DESC" -ge 1 ]; then
  pass "frontmatter has description field"
else
  fail "frontmatter has description field"
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

for required_tool in Read Bash Glob AskUserQuestion; do
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

# --- Word count ceiling ---

echo "--- Word count ---"

WORD_COUNT=$(echo "$FULL_CONTENT" | wc -w | tr -d ' ')
if [ "$WORD_COUNT" -lt 1500 ]; then
  pass "word count ($WORD_COUNT) is under 1500"
else
  fail "word count ($WORD_COUNT) is under 1500"
fi

# Word count must be non-trivial (at least 200 words to cover all sections meaningfully)
if [ "$WORD_COUNT" -gt 200 ]; then
  pass "word count ($WORD_COUNT) is above 200 (non-trivial content)"
else
  fail "word count ($WORD_COUNT) is above 200 (non-trivial content)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC2: Fetch and prune operations
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC2: Fetch and prune operations ==="

# Must mention fetch with prune
if echo "$BODY" | grep -qi 'fetch.*prune\|fetch.*--all.*--prune\|--prune'; then
  pass "content mentions fetch with prune"
else
  fail "content mentions fetch with prune"
fi

# Must not hardcode 'origin' as the sole remote -- should use --all or be generic
# Check: if 'origin' appears, it must not be the ONLY remote reference
# (i.e., must also mention --all or multiple remotes or generic approach)
if echo "$BODY" | grep -qi 'fetch.*--all'; then
  pass "fetch uses --all (not hardcoded to single remote)"
else
  # If origin is mentioned without --all, that's a problem
  if echo "$BODY" | grep -qi 'fetch.*origin' && ! echo "$BODY" | grep -qi 'fetch.*--all'; then
    fail "fetch uses --all (not hardcoded to single remote) -- found hardcoded origin"
  else
    pass "fetch uses --all (not hardcoded to single remote)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# AC3: Stale branch detection uses two methods
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC3: Stale branch detection ==="

# Method 1: [gone] annotation
if echo "$BODY" | grep -q '\[gone\]'; then
  pass "mentions [gone] annotation for tracking branch deletion"
else
  fail "mentions [gone] annotation for tracking branch deletion"
fi

# Method 2: --merged as supplementary
if echo "$BODY" | grep -q '\-\-merged'; then
  pass "mentions --merged as supplementary stale detection"
else
  fail "mentions --merged as supplementary stale detection"
fi

# Both methods mentioned (not just one)
GONE_COUNT=$(echo "$BODY" | grep -c '\[gone\]' || true)
MERGED_COUNT=$(echo "$BODY" | grep -c '\-\-merged' || true)
if [ "$GONE_COUNT" -ge 1 ] && [ "$MERGED_COUNT" -ge 1 ]; then
  pass "both detection methods present (not just one)"
else
  fail "both detection methods present (not just one)"
fi

# Base branch from config, not hardcoded main
if echo "$BODY" | grep -qi 'config.*base.branch\|config\.json.*base\|baseBranch.*config\|config.*baseBranch'; then
  pass "base branch sourced from config (not hardcoded)"
else
  fail "base branch sourced from config (not hardcoded)"
fi

# Negative: 'main' must not appear as the sole/default branch without config reference
# A lazy impl could just hardcode "main" -- ensure config is the source of truth
MAIN_AS_DEFAULT=$(echo "$BODY" | grep -ci 'default.*main\|branch.*main\b' || true)
CONFIG_REF=$(echo "$BODY" | grep -ci 'config' || true)
if [ "$MAIN_AS_DEFAULT" -gt 0 ] && [ "$CONFIG_REF" -lt 1 ]; then
  fail "base branch references config, not just hardcoded 'main'"
else
  pass "base branch references config, not just hardcoded 'main'"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC4: Safety checks prevent destructive operations
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC4: Safety checks ==="

# Current branch protection
if echo "$BODY" | grep -qi 'current branch.*protect\|current branch.*skip\|never.*delete.*current\|exclude.*current.*branch\|current.*branch.*safe'; then
  pass "mentions current branch protection"
else
  fail "mentions current branch protection"
fi

# Base branch protection
if echo "$BODY" | grep -qi 'base branch.*protect\|base branch.*skip\|never.*delete.*base\|exclude.*base.*branch\|base.*branch.*safe\|protect.*base'; then
  pass "mentions base branch protection"
else
  fail "mentions base branch protection"
fi

# Worktree check
if echo "$BODY" | grep -q 'worktree'; then
  pass "mentions worktree check"
else
  fail "mentions worktree check"
fi

# git worktree list specifically
if echo "$BODY" | grep -q 'git worktree list\|worktree list'; then
  pass "mentions 'git worktree list' command"
else
  fail "mentions 'git worktree list' command"
fi

# Active feature branch protection via workflow.json
if echo "$BODY" | grep -q 'workflow\.json\|workflow state\|active.*feature\|feature.*branch.*active\|currentWork'; then
  pass "mentions active feature branch protection (workflow.json)"
else
  fail "mentions active feature branch protection (workflow.json)"
fi

# Branch name validation / metacharacter check
if echo "$BODY" | grep -qi 'metacharacter\|branch.*valid\|sanitiz\|name.*valid\|valid.*branch\|special.*char\|injection'; then
  pass "mentions branch name validation or metacharacter check"
else
  fail "mentions branch name validation or metacharacter check"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC5: Preview and confirmation before deletion
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC5: Preview and confirmation ==="

# Must use AskUserQuestion for confirmation
if echo "$BODY" | grep -q 'AskUserQuestion'; then
  pass "mentions AskUserQuestion for user confirmation"
else
  fail "mentions AskUserQuestion for user confirmation"
fi

# Must use safe delete (git branch -d), not force delete (-D)
if echo "$BODY" | grep -q 'branch -d\b\|branch -d '; then
  pass "mentions 'git branch -d' (safe delete)"
else
  # Also accept if -d is referenced in context of branch deletion
  if echo "$BODY" | grep -q '\-d '; then
    pass "mentions safe delete flag (-d)"
  else
    fail "mentions 'git branch -d' (safe delete)"
  fi
fi

# Must NOT use force delete -D (or must explicitly prohibit it)
if echo "$BODY" | grep -q 'branch -D\b\|branch -D '; then
  # If -D appears, it should be in a prohibition context (e.g., "never use -D")
  if echo "$BODY" | grep -qi 'never.*-D\|not.*-D\|avoid.*-D\|prohibit.*-D\|NO.*-D'; then
    pass "-D mentioned only in prohibition context"
  else
    fail "uses -D (force delete) without explicit prohibition"
  fi
else
  pass "does not use -D (force delete)"
fi

# Must mention cleanupBranch config option
if echo "$BODY" | grep -q 'cleanupBranch'; then
  pass "mentions cleanupBranch config option"
else
  fail "mentions cleanupBranch config option"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC6: Base branch sync
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC6: Base branch sync ==="

# Must mention checking out base branch
if echo "$BODY" | grep -qi 'checkout.*base\|switch.*base\|check out.*base'; then
  pass "mentions checking out base branch"
else
  fail "mentions checking out base branch"
fi

# Must mention pulling base branch
if echo "$BODY" | grep -qi 'pull.*base\|pull.*branch\|git pull\|ff-only\|fast-forward'; then
  pass "mentions pulling base branch"
else
  fail "mentions pulling base branch"
fi

# Must mention returning to original branch
if echo "$BODY" | grep -qi 'return.*original\|switch.*back\|checkout.*original\|restore.*branch\|previous.*branch\|back to.*branch'; then
  pass "mentions returning to original branch after sync"
else
  fail "mentions returning to original branch after sync"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC7: No workflow state mutation
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC7: No workflow state mutation ==="

# Must NOT mention modifying/writing/updating workflow.json
# (Reading it is fine for AC4 active branch check, but writing is not)
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

# Positive: should explicitly state read-only / no mutation constraint
if echo "$BODY" | grep -qi 'read.only\|read only\|no.*mutation\|never.*modif\|does not.*modify\|no.*state.*change\|never.*write.*state'; then
  pass "explicitly states read-only or no-mutation constraint"
else
  fail "explicitly states read-only or no-mutation constraint"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC9: Failure modes
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC9: Failure modes ==="

# Must have a Failure Modes section (already checked in AC1, but verify content)
FM_SECTION=$(echo "$BODY" | sed -n '/^## Failure Modes/,/^## /p')

if [ -n "$FM_SECTION" ]; then
  pass "Failure Modes section has content"
else
  fail "Failure Modes section has content"
fi

# Failure mode: dirty working tree
if echo "$BODY" | grep -qi 'dirty.*work\|uncommitted.*change\|unstaged.*change\|working.*tree.*clean\|clean.*working'; then
  pass "failure mode: dirty working tree"
else
  fail "failure mode: dirty working tree"
fi

# Failure mode: no remotes configured
if echo "$BODY" | grep -qi 'no remote\|remote.*missing\|no.*configured.*remote\|remote.*not.*found\|zero.*remote'; then
  pass "failure mode: no remotes configured"
else
  fail "failure mode: no remotes configured"
fi

# Failure mode: no stale branches found
if echo "$BODY" | grep -qi 'no stale\|no.*branch.*found\|nothing.*clean\|no.*candidates\|zero.*stale\|no.*branches.*to'; then
  pass "failure mode: no stale branches found"
else
  fail "failure mode: no stale branches found"
fi

# At least 3 distinct failure modes listed (bullet points or subsections)
if [ -n "$FM_SECTION" ]; then
  FM_BULLET_COUNT=$(echo "$FM_SECTION" | grep -c '^\s*[-*]' || true)
  if [ "$FM_BULLET_COUNT" -ge 3 ]; then
    pass "at least 3 failure mode entries ($FM_BULLET_COUNT found)"
  else
    fail "at least 3 failure mode entries ($FM_BULLET_COUNT found)"
  fi
else
  fail "at least 3 failure mode entries (section missing)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Cross-cutting: Protocol references
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Cross-cutting: Protocol references ==="

# Must reference git protocol (since this skill does git operations)
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
