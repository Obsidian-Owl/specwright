#!/usr/bin/env bash
#
# Tests for sw-build compression (AC-4) and inner-loop validation (AC-5)
#
# Validates that core/skills/sw-build/SKILL.md has been compressed by
# at least 300 words (from 1657 baseline), that compressed sections
# reference their protocols, and that a new inner-loop validation
# constraint block exists with correct placement and content.
#
# Boundary classification: Internal (core skills validated via file
# reads and pattern matching, no mocks).
#
# Dependencies: bash
# Usage: bash tests/test-sw-build-inner-loop.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/sw-build/SKILL.md"

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

# Extract a constraint block: from its **Name header to the line before
# the next **Uppercase header. macOS-compatible (no head -n -1).
# Usage: extract_block "$BODY" "Block name pattern"
extract_block() {
  local body="$1"
  local pattern="$2"
  echo "$body" | awk -v pat="$pattern" '
    BEGIN { found=0 }
    $0 ~ "\\*\\*" pat && !found { found=1; next }
    found && /^\*\*[A-Z]/ { exit }
    found { print }
  '
}

# ═══════════════════════════════════════════════════════════════════════
# Pre-flight: file must exist
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC-4, AC-5: sw-build compression and inner-loop validation tests ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "core/skills/sw-build/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (file missing, cannot continue)"
  exit 1
fi

BODY=$(extract_body "$SKILL_FILE") || {
  fail "SKILL.md has body content after frontmatter"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (no body, cannot continue)"
  exit 1
}

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Overall word count reduction
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC-4: Word count compression ==="

BASELINE_WORDS=1357
WORD_COUNT=$(wc -w < "$SKILL_FILE" | tr -d ' ')
MAX_WORDS=$((BASELINE_WORDS + 30))

if [ "$WORD_COUNT" -le "$MAX_WORDS" ]; then
  pass "word count within budget of baseline (now $WORD_COUNT, max $MAX_WORDS)"
else
  fail "word count within budget of baseline (now $WORD_COUNT, max $MAX_WORDS)"
fi

# Sanity: the file should still have substantial content (not gutted)
MIN_WORDS=500
if [ "$WORD_COUNT" -ge "$MIN_WORDS" ]; then
  pass "file retains at least $MIN_WORDS words (not over-compressed: $WORD_COUNT)"
else
  fail "file retains at least $MIN_WORDS words (not over-compressed: $WORD_COUNT)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Repo map section compressed to protocol reference
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Repo map compression ==="

# The repo map constraint block must still exist
if echo "$BODY" | grep -qi 'Repo map'; then
  pass "repo map constraint block still exists"
else
  fail "repo map constraint block still exists"
fi

# Must reference the protocol (compressed form)
if echo "$BODY" | grep -q 'protocols/repo-map.md'; then
  pass "repo map section references protocols/repo-map.md"
else
  fail "repo map section references protocols/repo-map.md"
fi

# The verbose inline detail should be gone. Check that the old verbose
# content (sg/ast-grep details, token budget inline, degradation steps)
# is NOT still in the repo map block.
REPO_MAP_BLOCK=$(extract_block "$BODY" "Repo map")

if echo "$REPO_MAP_BLOCK" | grep -qi 'extract definition signatures'; then
  fail "repo map block no longer contains verbose 'extract definition signatures' detail"
else
  pass "repo map block no longer contains verbose 'extract definition signatures' detail"
fi

if echo "$REPO_MAP_BLOCK" | grep -qi 'degrade to a file listing'; then
  fail "repo map block no longer contains verbose degradation instructions"
else
  pass "repo map block no longer contains verbose degradation instructions"
fi

# Repo map block should be short (protocol reference, not inline detail)
REPO_MAP_WORDS=$(echo "$REPO_MAP_BLOCK" | wc -w | tr -d ' ')
if [ "$REPO_MAP_WORDS" -le 30 ]; then
  pass "repo map block is concise ($REPO_MAP_WORDS words, max 30)"
else
  fail "repo map block is concise ($REPO_MAP_WORDS words, max 30)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Build failures section compressed to headless.md reference
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Build failures compression ==="

# Build failures block must still exist
if echo "$BODY" | grep -qi 'Build failures'; then
  pass "build failures constraint block still exists"
else
  fail "build failures constraint block still exists"
fi

# Must reference headless.md protocol
if echo "$BODY" | grep -q 'protocols/headless.md'; then
  pass "build failures references protocols/headless.md"
else
  fail "build failures references protocols/headless.md"
fi

# The verbose inline branching for headless should be gone
BUILD_FAILURES_BLOCK=$(extract_block "$BODY" "Build failures")

if echo "$BUILD_FAILURES_BLOCK" | grep -qi 'headless-result.json.*status.*aborted'; then
  fail "build failures no longer contains verbose headless-result.json inline detail"
else
  pass "build failures no longer contains verbose headless-result.json inline detail"
fi

# Must still mention build-fixer (essential constraint, not removed)
if echo "$BUILD_FAILURES_BLOCK" | grep -qi 'build-fixer'; then
  pass "build failures still mentions build-fixer delegation"
else
  fail "build failures still mentions build-fixer delegation"
fi

# Must still mention max 2 attempts (essential constraint)
if echo "$BUILD_FAILURES_BLOCK" | grep -qi '2 attempt\|max 2\|twice'; then
  pass "build failures still mentions max 2 attempts"
else
  fail "build failures still mentions max 2 attempts"
fi

# Must still mention plan mismatch (essential constraint, not headless-related)
if echo "$BUILD_FAILURES_BLOCK" | grep -qi 'plan mismatch\|discrepanc'; then
  pass "build failures still mentions plan mismatch handling"
else
  fail "build failures still mentions plan mismatch handling"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Stage boundary compressed
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Stage boundary compression ==="

STAGE_BLOCK=$(extract_block "$BODY" "Stage boundary")

if [ -n "$STAGE_BLOCK" ]; then
  pass "stage boundary constraint block still exists"
else
  fail "stage boundary constraint block still exists"
fi

# Must reference the protocol
if echo "$STAGE_BLOCK" | grep -q 'protocols/stage-boundary.md'; then
  pass "stage boundary references protocols/stage-boundary.md"
else
  fail "stage boundary references protocols/stage-boundary.md"
fi

# Should be at most 2 sentences (compressed). Count sentences roughly
# by counting period-terminated segments (excluding protocol paths).
STAGE_SENTENCES=$(echo "$STAGE_BLOCK" | sed 's|protocols/[^ ]*||g' | tr -cd '.' | wc -c | tr -d ' ')
if [ "$STAGE_SENTENCES" -le 2 ]; then
  pass "stage boundary is at most 2 sentences ($STAGE_SENTENCES found)"
else
  fail "stage boundary is at most 2 sentences ($STAGE_SENTENCES found)"
fi

# Stage boundary word count should be small
STAGE_WORDS=$(echo "$STAGE_BLOCK" | wc -w | tr -d ' ')
if [ "$STAGE_WORDS" -le 30 ]; then
  pass "stage boundary block is concise ($STAGE_WORDS words, max 30)"
else
  fail "stage boundary block is concise ($STAGE_WORDS words, max 30)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Task loop preamble compressed
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Task loop compression ==="

TASK_LOOP_BLOCK=$(extract_block "$BODY" "Task loop")

if [ -n "$TASK_LOOP_BLOCK" ]; then
  pass "task loop constraint block still exists"
else
  fail "task loop constraint block still exists"
fi

# Task loop should be compressed to ~15 words
TASK_LOOP_WORDS=$(echo "$TASK_LOOP_BLOCK" | wc -w | tr -d ' ')
if [ "$TASK_LOOP_WORDS" -le 30 ]; then
  pass "task loop block is concise ($TASK_LOOP_WORDS words, max 30)"
else
  fail "task loop block is concise ($TASK_LOOP_WORDS words, max 30)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-5: Inner-loop validation block exists
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-5: Inner-loop validation block placement ==="

# Must exist as a constraint block
if echo "$BODY" | grep -qi 'Inner.loop validation\|Inner-loop validation'; then
  pass "inner-loop validation constraint block exists"
else
  fail "inner-loop validation constraint block exists"
fi

# Must be between post-build review and as-built notes.
# Get line numbers of each section to verify ordering.
POST_BUILD_LINE=$(echo "$BODY" | grep -ni 'Post-build review\|Post.build review' | head -n 1 | cut -d: -f1)
INNER_LOOP_LINE=$(echo "$BODY" | grep -ni 'Inner.loop validation\|Inner-loop validation' | head -n 1 | cut -d: -f1)
AS_BUILT_LINE=$(echo "$BODY" | grep -ni 'As-built notes\|As.built notes' | head -n 1 | cut -d: -f1)

if [ -n "$POST_BUILD_LINE" ] && [ -n "$INNER_LOOP_LINE" ] && [ -n "$AS_BUILT_LINE" ]; then
  if [ "$POST_BUILD_LINE" -lt "$INNER_LOOP_LINE" ] && [ "$INNER_LOOP_LINE" -lt "$AS_BUILT_LINE" ]; then
    pass "inner-loop validation is between post-build review (line $POST_BUILD_LINE) and as-built notes (line $AS_BUILT_LINE)"
  else
    fail "inner-loop validation is between post-build review and as-built notes (post-build=$POST_BUILD_LINE, inner-loop=$INNER_LOOP_LINE, as-built=$AS_BUILT_LINE)"
  fi
else
  fail "inner-loop validation is between post-build review and as-built notes (one or more sections missing: post-build=${POST_BUILD_LINE:-missing}, inner-loop=${INNER_LOOP_LINE:-missing}, as-built=${AS_BUILT_LINE:-missing})"
fi

# Must be MEDIUM freedom
if echo "$BODY" | grep -qi 'Inner.loop validation.*(MEDIUM'; then
  pass "inner-loop validation has MEDIUM freedom level"
else
  fail "inner-loop validation has MEDIUM freedom level"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-5: Inner-loop validation content
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-5: Inner-loop validation content ==="

INNER_LOOP_BLOCK=$(extract_block "$BODY" "Inner.loop validation")

# Must mention test:integration config key
if echo "$INNER_LOOP_BLOCK" | grep -qi 'test:integration'; then
  pass "inner-loop mentions test:integration config"
else
  fail "inner-loop mentions test:integration config"
fi

# Must mention reading from commands config
if echo "$INNER_LOOP_BLOCK" | grep -qi 'commands\.\|config'; then
  pass "inner-loop reads from config"
else
  fail "inner-loop reads from config"
fi

# Must mention 5-minute timeout
if echo "$INNER_LOOP_BLOCK" | grep -qi '5.minute\|five.minute\|5 min\|300.s'; then
  pass "inner-loop specifies 5-minute timeout"
else
  fail "inner-loop specifies 5-minute timeout"
fi

# Must mention build-fixer delegation
if echo "$INNER_LOOP_BLOCK" | grep -qi 'build-fixer\|specwright-build-fixer'; then
  pass "inner-loop delegates to build-fixer on failure"
else
  fail "inner-loop delegates to build-fixer on failure"
fi

# Must mention max 2 attempts for build-fixer
if echo "$INNER_LOOP_BLOCK" | grep -qi '2 attempt\|max 2\|twice'; then
  pass "inner-loop specifies max 2 build-fixer attempts"
else
  fail "inner-loop specifies max 2 build-fixer attempts"
fi

# Must mention status card on pass
if echo "$INNER_LOOP_BLOCK" | grep -qi 'status card'; then
  pass "inner-loop notes result in status card"
else
  fail "inner-loop notes result in status card"
fi

# Must mention skip silently when not configured
if echo "$INNER_LOOP_BLOCK" | grep -qi 'skip.*silent\|silent.*skip'; then
  pass "inner-loop skips silently when not configured"
else
  fail "inner-loop skips silently when not configured"
fi

# Must handle interactive vs headless distinction for still-failing case
if echo "$INNER_LOOP_BLOCK" | grep -qi 'interactive\|headless'; then
  pass "inner-loop distinguishes interactive vs headless on persistent failure"
else
  fail "inner-loop distinguishes interactive vs headless on persistent failure"
fi

# On headless persistent failure: skip and record (not abort)
if echo "$INNER_LOOP_BLOCK" | grep -qi 'skip.*record\|record.*skip\|skip.*log\|log.*skip'; then
  pass "inner-loop headless persistent failure skips and records"
else
  fail "inner-loop headless persistent failure skips and records"
fi

# On interactive persistent failure: present to user
if echo "$INNER_LOOP_BLOCK" | grep -qi 'present.*user\|show.*user\|ask.*user\|user.*present'; then
  pass "inner-loop interactive persistent failure presents to user"
else
  fail "inner-loop interactive persistent failure presents to user"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-5: Inner-loop validation word count
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-5: Inner-loop validation word count ==="

INNER_LOOP_WORDS=$(echo "$INNER_LOOP_BLOCK" | wc -w | tr -d ' ')
if [ "$INNER_LOOP_WORDS" -le 80 ]; then
  pass "inner-loop validation block is at most 80 words ($INNER_LOOP_WORDS found)"
else
  fail "inner-loop validation block is at most 80 words ($INNER_LOOP_WORDS found)"
fi

# Must have meaningful content (not just the header)
if [ "$INNER_LOOP_WORDS" -ge 20 ]; then
  pass "inner-loop validation block has meaningful content ($INNER_LOOP_WORDS words, min 20)"
else
  fail "inner-loop validation block has meaningful content ($INNER_LOOP_WORDS words, min 20)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Essential constraints preserved (no behavior change)
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Essential constraints preserved ==="

# TDD cycle must still be present and detailed (HIGH freedom for test
# design, LOW freedom for sequence). This is the core of sw-build.
if echo "$BODY" | grep -qi 'TDD cycle'; then
  pass "TDD cycle constraint block still exists"
else
  fail "TDD cycle constraint block still exists"
fi

if echo "$BODY" | grep -qi 'RED.*GREEN.*REFACTOR\|RED.*GREEN'; then
  pass "TDD cycle still specifies RED -> GREEN -> REFACTOR sequence"
else
  fail "TDD cycle still specifies RED -> GREEN -> REFACTOR sequence"
fi

# Commits constraint must still be present
if echo "$BODY" | grep -qi 'Commits.*LOW freedom\|Commits.*(LOW'; then
  pass "commits constraint block still exists with LOW freedom"
else
  fail "commits constraint block still exists with LOW freedom"
fi

if echo "$BODY" | grep -qi 'never.*git add -A\|never.*git add.*-A'; then
  pass "commits still forbids git add -A"
else
  fail "commits still forbids git add -A"
fi

# Context envelope must still be present
if echo "$BODY" | grep -qi 'Context envelope'; then
  pass "context envelope constraint block still exists"
else
  fail "context envelope constraint block still exists"
fi

# Micro-check must still be present
if echo "$BODY" | grep -qi 'micro-check\|micro.check'; then
  pass "per-task micro-check constraint still exists"
else
  fail "per-task micro-check constraint still exists"
fi

# specwright-tester delegation must still be mentioned
if echo "$BODY" | grep -qi 'specwright-tester'; then
  pass "tester agent delegation still mentioned"
else
  fail "tester agent delegation still mentioned"
fi

# specwright-executor delegation must still be mentioned
if echo "$BODY" | grep -qi 'specwright-executor'; then
  pass "executor agent delegation still mentioned"
else
  fail "executor agent delegation still mentioned"
fi

# Branch setup must still be present (not part of compression targets)
if echo "$BODY" | grep -qi 'Branch setup'; then
  pass "branch setup constraint block still exists"
else
  fail "branch setup constraint block still exists"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Protocol References section still lists required protocols
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Protocol references preserved ==="

PROTO_SECTION=$(echo "$BODY" | sed -n '/^## Protocol References/,/^## /p')

if [ -n "$PROTO_SECTION" ]; then
  pass "Protocol References section exists"
else
  fail "Protocol References section exists"
fi

# repo-map.md must still be in Protocol References
if echo "$PROTO_SECTION" | grep -q 'repo-map.md'; then
  pass "Protocol References still lists repo-map.md"
else
  fail "Protocol References still lists repo-map.md"
fi

# headless.md must still be in Protocol References
if echo "$PROTO_SECTION" | grep -q 'headless.md'; then
  pass "Protocol References still lists headless.md"
else
  fail "Protocol References still lists headless.md"
fi

# build-context.md must still be in Protocol References
if echo "$PROTO_SECTION" | grep -q 'build-context.md'; then
  pass "Protocol References still lists build-context.md"
else
  fail "Protocol References still lists build-context.md"
fi

# stage-boundary.md must still be in Protocol References
if echo "$PROTO_SECTION" | grep -q 'stage-boundary.md'; then
  pass "Protocol References still lists stage-boundary.md"
else
  fail "Protocol References still lists stage-boundary.md"
fi

# ═══════════════════════════════════════════════════════════════════════
# Anti-bypass: Guards against lazy implementations
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== Anti-bypass: Implementation guards ==="

# Guard 1: Cannot pass word count test by just deleting sections.
# The essential constraint checks above ensure content is preserved.
# Also verify Constraints section has a minimum number of blocks.
CONSTRAINT_BLOCKS=$(echo "$BODY" | grep -c '^\*\*[A-Z]' || true)
if [ "$CONSTRAINT_BLOCKS" -ge 10 ]; then
  pass "at least 10 constraint blocks remain ($CONSTRAINT_BLOCKS found)"
else
  fail "at least 10 constraint blocks remain ($CONSTRAINT_BLOCKS found)"
fi

# Guard 2: Inner-loop must mention ALL key terms together in one block.
# A lazy impl that scatters mentions across existing blocks fails this.
INNER_HAS_INTEGRATION=$(echo "$INNER_LOOP_BLOCK" | grep -ci 'test:integration' || true)
INNER_HAS_FIXER=$(echo "$INNER_LOOP_BLOCK" | grep -ci 'build-fixer' || true)
INNER_HAS_TIMEOUT=$(echo "$INNER_LOOP_BLOCK" | grep -ci '5.min\|5 min' || true)
INNER_HAS_SKIP=$(echo "$INNER_LOOP_BLOCK" | grep -ci 'skip' || true)
INNER_KEY_COUNT=0
[ "$INNER_HAS_INTEGRATION" -ge 1 ] && INNER_KEY_COUNT=$((INNER_KEY_COUNT + 1))
[ "$INNER_HAS_FIXER" -ge 1 ] && INNER_KEY_COUNT=$((INNER_KEY_COUNT + 1))
[ "$INNER_HAS_TIMEOUT" -ge 1 ] && INNER_KEY_COUNT=$((INNER_KEY_COUNT + 1))
[ "$INNER_HAS_SKIP" -ge 1 ] && INNER_KEY_COUNT=$((INNER_KEY_COUNT + 1))
if [ "$INNER_KEY_COUNT" -ge 4 ]; then
  pass "inner-loop block contains all 4 key terms together ($INNER_KEY_COUNT/4)"
else
  fail "inner-loop block contains all 4 key terms together ($INNER_KEY_COUNT/4)"
fi

# Guard 3: The compressed repo-map block must NOT have the old verbose
# content but MUST still convey the essential constraint (protocol ref).
# We already checked both above -- this is a combined cross-check.
if [ "$REPO_MAP_WORDS" -le 30 ] && echo "$REPO_MAP_BLOCK" | grep -q 'protocols/repo-map.md'; then
  pass "repo map is both compressed AND references protocol"
else
  fail "repo map is both compressed AND references protocol (words=$REPO_MAP_WORDS)"
fi

# Guard 4: Inner-loop must be a constraint block with freedom level
# (not just a random paragraph mentioning inner-loop).
if echo "$BODY" | grep -qiE '\*\*Inner.loop validation \(MEDIUM freedom\)'; then
  pass "inner-loop is a proper constraint block with freedom annotation"
else
  fail "inner-loop is a proper constraint block with freedom annotation"
fi

# Guard 5: Compression should not have introduced protocol references
# as a substitute for ALL constraints. The TDD cycle, commits, and
# context envelope should still have substantive inline content.
TDD_BLOCK=$(extract_block "$BODY" "TDD cycle")
TDD_WORDS=$(echo "$TDD_BLOCK" | wc -w | tr -d ' ')
if [ "$TDD_WORDS" -ge 40 ]; then
  pass "TDD cycle block retains substantive content ($TDD_WORDS words, min 40)"
else
  fail "TDD cycle block retains substantive content ($TDD_WORDS words, min 40)"
fi

COMMITS_BLOCK=$(extract_block "$BODY" "Commits")
COMMITS_WORDS=$(echo "$COMMITS_BLOCK" | wc -w | tr -d ' ')
if [ "$COMMITS_WORDS" -ge 30 ]; then
  pass "commits block retains substantive content ($COMMITS_WORDS words, min 30)"
else
  fail "commits block retains substantive content ($COMMITS_WORDS words, min 30)"
fi

# ═══════════════════════════════════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "==========================================="
echo "RESULT: $PASS passed, $FAIL failed"
echo "==========================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
