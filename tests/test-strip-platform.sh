#!/usr/bin/env bash
#
# Tests for strip_platform_sections()
#
# AC-1: Strips non-matching platform blocks (markers + content)
# AC-2: Preserves matching platform blocks (content kept, markers removed)
# AC-3: Handles unclosed markers (treat as block to EOF)
#
# Dependencies: bash, awk
# Usage: ./tests/test-strip-platform.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/build/build.sh"

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
    fail "$label"
    echo "    expected: $(echo "$expected" | head -20)"
    echo "    actual:   $(echo "$actual" | head -20)"
  fi
}

# ─── Setup ────────────────────────────────────────────────────────────

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Source build.sh to get strip_platform_sections function
# Use subshell tricks to avoid build.sh's main execution
# We source it and check the function exists
if [ ! -f "$BUILD_SCRIPT" ]; then
  echo "ABORT: build script not found at $BUILD_SCRIPT"
  exit 1
fi

# Source build.sh to load functions. The BASH_SOURCE guard in build.sh
# prevents main() from executing when sourced.
source "$BUILD_SCRIPT" 2>/dev/null || true

# Verify the function exists (this is our first gate)
if ! type strip_platform_sections &>/dev/null; then
  echo "  NOTE: strip_platform_sections is not yet defined in build.sh"
  echo "  All tests will fail (RED phase -- function does not exist yet)"
  echo ""
fi

# Helper: write content to a temp file, run strip_platform_sections, read result
run_strip() {
  local content="$1"
  local platform="$2"
  local fixture="$TMPDIR_TEST/fixture_$RANDOM.md"

  printf '%s' "$content" > "$fixture"
  strip_platform_sections "$fixture" "$platform" 2>/dev/null
  cat "$fixture"
}

echo "=== AC-1: strip_platform_sections strips non-matching platform blocks ==="
echo ""

# ─── AC-1: Single non-matching block fully removed ──────────────────────

echo "--- Single non-matching block removed (markers + content) ---"

INPUT_SINGLE_NONMATCH="line one
<!-- platform:claude-code -->
claude-only content A
claude-only content B
<!-- /platform -->
line after block"

EXPECTED_SINGLE_NONMATCH="line one
line after block"

ACTUAL=$(run_strip "$INPUT_SINGLE_NONMATCH" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_SINGLE_NONMATCH" \
  "single non-matching block: markers and content fully removed"

# ─── AC-1: Multiple non-adjacent non-matching blocks all removed ────────

echo "--- Multiple non-adjacent non-matching blocks all removed ---"

INPUT_MULTI_NONMATCH="header line
<!-- platform:claude-code -->
claude block one
<!-- /platform -->
middle line
<!-- platform:claude-code -->
claude block two
<!-- /platform -->
footer line"

EXPECTED_MULTI_NONMATCH="header line
middle line
footer line"

ACTUAL=$(run_strip "$INPUT_MULTI_NONMATCH" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_MULTI_NONMATCH" \
  "multiple non-adjacent non-matching blocks: all markers and content removed"

# ─── AC-1: Lines outside blocks unchanged (exact content) ───────────────

echo "--- Lines outside blocks are completely unchanged ---"

INPUT_OUTSIDE_LINES="first line with special chars: \$VAR & <tag> \"quotes\"
second line
<!-- platform:claude-code -->
removed stuff
<!-- /platform -->
third line with   extra   spaces
fourth line"

EXPECTED_OUTSIDE_LINES="first line with special chars: \$VAR & <tag> \"quotes\"
second line
third line with   extra   spaces
fourth line"

ACTUAL=$(run_strip "$INPUT_OUTSIDE_LINES" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_OUTSIDE_LINES" \
  "lines outside blocks preserved exactly including special characters"

# ─── AC-1: Non-matching block at start of file ──────────────────────────

echo "--- Non-matching block at start of file ---"

INPUT_START_BLOCK="<!-- platform:claude-code -->
removed header
<!-- /platform -->
content after"

EXPECTED_START_BLOCK="content after"

ACTUAL=$(run_strip "$INPUT_START_BLOCK" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_START_BLOCK" \
  "non-matching block at start of file: fully removed"

# ─── AC-1: Non-matching block at end of file (closed) ───────────────────

echo "--- Non-matching block at end of file (closed) ---"

INPUT_END_BLOCK="content before
<!-- platform:claude-code -->
removed footer
<!-- /platform -->"

EXPECTED_END_BLOCK="content before"

ACTUAL=$(run_strip "$INPUT_END_BLOCK" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_END_BLOCK" \
  "non-matching block at end of file (closed): fully removed"

echo ""
echo "=== AC-2: strip_platform_sections preserves matching platform blocks ==="
echo ""

# ─── AC-2: Single matching block: content preserved, markers removed ─────

echo "--- Single matching block: content preserved, markers removed ---"

INPUT_SINGLE_MATCH="line one
<!-- platform:opencode -->
opencode-specific content
more opencode content
<!-- /platform -->
line after block"

EXPECTED_SINGLE_MATCH="line one
opencode-specific content
more opencode content
line after block"

ACTUAL=$(run_strip "$INPUT_SINGLE_MATCH" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_SINGLE_MATCH" \
  "single matching block: content preserved, marker lines removed"

# ─── AC-2: Multiple matching blocks: all content preserved ───────────────

echo "--- Multiple matching blocks: all content preserved ---"

INPUT_MULTI_MATCH="header
<!-- platform:opencode -->
opencode block one
<!-- /platform -->
middle
<!-- platform:opencode -->
opencode block two
<!-- /platform -->
footer"

EXPECTED_MULTI_MATCH="header
opencode block one
middle
opencode block two
footer"

ACTUAL=$(run_strip "$INPUT_MULTI_MATCH" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_MULTI_MATCH" \
  "multiple matching blocks: all content preserved, all markers removed"

# ─── AC-2: Matching block content preserved exactly (whitespace, indentation) ─

echo "--- Matching block content preserved exactly ---"

INPUT_EXACT_CONTENT="before
<!-- platform:claude-code -->
  indented line
    double indented
	tab indented

empty line above
<!-- /platform -->
after"

EXPECTED_EXACT_CONTENT="before
  indented line
    double indented
	tab indented

empty line above
after"

ACTUAL=$(run_strip "$INPUT_EXACT_CONTENT" "claude-code") || true
assert_eq "$ACTUAL" "$EXPECTED_EXACT_CONTENT" \
  "matching block: indentation, tabs, and empty lines preserved exactly"

echo ""
echo "=== AC-3: strip_platform_sections handles unclosed markers ==="
echo ""

# ─── AC-3: Unclosed non-matching marker: everything from marker to EOF removed ─

echo "--- Unclosed non-matching marker: rest of file removed ---"

INPUT_UNCLOSED_NONMATCH="keep this line
also keep this
<!-- platform:claude-code -->
this should be removed
and this too
no closing marker exists"

EXPECTED_UNCLOSED_NONMATCH="keep this line
also keep this"

ACTUAL=$(run_strip "$INPUT_UNCLOSED_NONMATCH" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_UNCLOSED_NONMATCH" \
  "unclosed non-matching marker: all lines from marker to EOF removed"

# ─── AC-3: Unclosed matching marker: content preserved, marker removed ───

echo "--- Unclosed matching marker: content preserved, marker removed ---"

INPUT_UNCLOSED_MATCH="keep this
<!-- platform:opencode -->
opencode content that extends to EOF
more opencode content
final opencode line"

EXPECTED_UNCLOSED_MATCH="keep this
opencode content that extends to EOF
more opencode content
final opencode line"

ACTUAL=$(run_strip "$INPUT_UNCLOSED_MATCH" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_UNCLOSED_MATCH" \
  "unclosed matching marker: content preserved, marker line removed"

# ─── AC-3: Unclosed marker is only marker in file ───────────────────────

echo "--- Unclosed marker is entire file content (non-matching) ---"

INPUT_UNCLOSED_ONLY="<!-- platform:claude-code -->
all content under unclosed block
more content here"

EXPECTED_UNCLOSED_ONLY=""

ACTUAL=$(run_strip "$INPUT_UNCLOSED_ONLY" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_UNCLOSED_ONLY" \
  "unclosed non-matching marker as entire file: produces empty output"

echo ""
echo "=== Mixed scenarios ==="
echo ""

# ─── Mixed: both matching and non-matching blocks ────────────────────────

echo "--- File with both matching and non-matching blocks ---"

INPUT_MIXED="# Skill Title

General instructions here.

<!-- platform:claude-code -->
Use the Bash tool to run commands.
Claude-specific guidance.
<!-- /platform -->
<!-- platform:opencode -->
Use the bash tool to run commands.
Opencode-specific guidance.
<!-- /platform -->

More general instructions.

<!-- platform:claude-code -->
Another Claude block.
<!-- /platform -->

Final line."

EXPECTED_MIXED="# Skill Title

General instructions here.

Use the bash tool to run commands.
Opencode-specific guidance.

More general instructions.


Final line."

ACTUAL=$(run_strip "$INPUT_MIXED" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_MIXED" \
  "mixed matching and non-matching blocks: correct filtering"

# ─── Mixed: verify the reverse platform also works ──────────────────────

echo "--- Same file, opposite platform ---"

EXPECTED_MIXED_CC="# Skill Title

General instructions here.

Use the Bash tool to run commands.
Claude-specific guidance.

More general instructions.

Another Claude block.

Final line."

# Need a fresh copy of the same input since strip modifies in-place
ACTUAL=$(run_strip "$INPUT_MIXED" "claude-code") || true
assert_eq "$ACTUAL" "$EXPECTED_MIXED_CC" \
  "mixed blocks with claude-code platform: reverse filtering correct"

# ─── Passthrough: file with NO markers ───────────────────────────────────

echo "--- File with no markers: output identical to input ---"

INPUT_NO_MARKERS="# Regular File

This file has no platform markers at all.

Just regular content.
With multiple lines."

ACTUAL=$(run_strip "$INPUT_NO_MARKERS" "opencode") || true
assert_eq "$ACTUAL" "$INPUT_NO_MARKERS" \
  "file with no markers: output identical to input (passthrough)"

# ─── Passthrough: empty file ────────────────────────────────────────────

echo "--- Empty file: remains empty ---"

INPUT_EMPTY=""
ACTUAL=$(run_strip "$INPUT_EMPTY" "opencode") || true
assert_eq "$ACTUAL" "" \
  "empty file: remains empty after processing"

# ─── Edge: marker-like text that is not a marker ─────────────────────────

echo "--- Marker-like text that is not a valid marker ---"

INPUT_NOT_MARKER="line one
this is not <!-- platform:claude-code --> a marker
line two"

ACTUAL=$(run_strip "$INPUT_NOT_MARKER" "opencode") || true
# An inline marker fragment should NOT trigger block behavior --
# the marker should be on its own line to be recognized
assert_eq "$ACTUAL" "$INPUT_NOT_MARKER" \
  "inline marker-like text not on its own line: not treated as block delimiter"

# ─── Edge: stray closing marker outside any block ─────────────────────────

echo "--- Stray closing marker outside any block is passed through ---"

INPUT_STRAY_CLOSE="line one
<!-- /platform -->
line two"

ACTUAL=$(run_strip "$INPUT_STRAY_CLOSE" "opencode") || true
assert_eq "$ACTUAL" "$INPUT_STRAY_CLOSE" \
  "stray closing marker outside a block is emitted as-is"

# ─── Edge: three different platform blocks ────────────────────────────────

echo "--- Three different platform names, only one matches ---"

INPUT_THREE_PLATFORMS="shared line
<!-- platform:claude-code -->
claude only
<!-- /platform -->
<!-- platform:opencode -->
opencode only
<!-- /platform -->
<!-- platform:cursor -->
cursor only
<!-- /platform -->
final shared line"

EXPECTED_THREE_PLATFORMS="shared line
opencode only
final shared line"

ACTUAL=$(run_strip "$INPUT_THREE_PLATFORMS" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_THREE_PLATFORMS" \
  "three different platform blocks: only matching platform content preserved"

# ─── Edge: adjacent blocks with no content between them ──────────────────

echo "--- Adjacent blocks with no gap ---"

INPUT_ADJACENT="before
<!-- platform:claude-code -->
claude content
<!-- /platform -->
<!-- platform:opencode -->
opencode content
<!-- /platform -->
after"

EXPECTED_ADJACENT="before
opencode content
after"

ACTUAL=$(run_strip "$INPUT_ADJACENT" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_ADJACENT" \
  "adjacent blocks with no gap: both processed correctly"

# ─── Edge: block with empty content ──────────────────────────────────────

echo "--- Block with no content between markers ---"

INPUT_EMPTY_BLOCK="before
<!-- platform:claude-code -->
<!-- /platform -->
after"

EXPECTED_EMPTY_BLOCK="before
after"

ACTUAL=$(run_strip "$INPUT_EMPTY_BLOCK" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_EMPTY_BLOCK" \
  "empty non-matching block: markers removed, no extra blank lines"

INPUT_EMPTY_MATCH_BLOCK="before
<!-- platform:opencode -->
<!-- /platform -->
after"

EXPECTED_EMPTY_MATCH_BLOCK="before
after"

ACTUAL=$(run_strip "$INPUT_EMPTY_MATCH_BLOCK" "opencode") || true
assert_eq "$ACTUAL" "$EXPECTED_EMPTY_MATCH_BLOCK" \
  "empty matching block: only markers removed, no extra content"

# ─── In-place modification: original file is modified ─────────────────────

echo "--- Function modifies file in-place ---"

INPLACE_FILE="$TMPDIR_TEST/inplace_test.md"
printf '%s' "keep
<!-- platform:claude-code -->
remove
<!-- /platform -->
also keep" > "$INPLACE_FILE"

strip_platform_sections "$INPLACE_FILE" "opencode" 2>/dev/null || true
INPLACE_RESULT=$(cat "$INPLACE_FILE")
assert_eq "$INPLACE_RESULT" "keep
also keep" \
  "function modifies the file in-place (not just stdout)"

# ─── Helpers for frontmatter/body extraction ──────────────────────────

extract_frontmatter() {
  local file="$1"
  local fm_end
  fm_end=$(awk 'NR==1 && /^---$/ { found=1; next }
       found && /^---$/ { print NR; exit }' "$file")
  [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && return 0
  sed -n "1,${fm_end}p" "$file"
}

extract_body() {
  local file="$1"
  local fm_end
  fm_end=$(awk 'NR==1 && /^---$/ { found=1; next }
       found && /^---$/ { print NR; exit }' "$file")
  [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && cat "$file" && return 0
  tail -n +"$((fm_end + 1))" "$file"
}

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Core sw-build has platform markers around Claude Code-specific sections
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Core sw-build has platform markers around Claude Code sections ==="
echo ""

CORE_BUILD="$ROOT_DIR/core/skills/sw-build/SKILL.md"

if [ ! -f "$CORE_BUILD" ]; then
  fail "AC-4: core sw-build SKILL.md not found at $CORE_BUILD"
else

  # --- AC-4a: Task tracking section is wrapped with platform:claude-code markers ---

  echo "--- Task tracking section wrapped with platform:claude-code markers ---"

  # The opening marker must appear on a line before "Task tracking (LOW freedom)"
  # and the closing marker must appear after the last line of that section.
  # We check that the marker immediately precedes the Task tracking heading.
  if grep -q '<!-- platform:claude-code -->' "$CORE_BUILD" && \
     grep -A1 '<!-- platform:claude-code -->' "$CORE_BUILD" | grep -q 'Task tracking (LOW freedom)'; then
    pass "AC-4a: opening platform:claude-code marker precedes Task tracking section"
  else
    fail "AC-4a: opening platform:claude-code marker precedes Task tracking section"
  fi

  # The closing marker must appear after the last line of the Task tracking section
  # (the "On recovery after compaction" line) and before "## Protocol References"
  TASK_TRACKING_BLOCK=$(sed -n '/<!-- platform:claude-code -->/,/<!-- \/platform -->/p' "$CORE_BUILD" | head -20)
  if echo "$TASK_TRACKING_BLOCK" | grep -q 'Task tracking (LOW freedom)' && \
     echo "$TASK_TRACKING_BLOCK" | grep -q 'On recovery after compaction'; then
    pass "AC-4a: platform:claude-code block contains full Task tracking section"
  else
    fail "AC-4a: platform:claude-code block contains full Task tracking section"
    echo "    got block: $(echo "$TASK_TRACKING_BLOCK" | head -10)"
  fi

  # --- AC-4b: "Task tracking tools unavailable" failure mode row is wrapped ---

  echo "--- Task tracking tools unavailable row wrapped with marker ---"

  # Find the line with "Task tracking tools unavailable" and check it's inside a platform block
  UNAVAIL_CONTEXT=$(grep -B2 'Task tracking tools unavailable' "$CORE_BUILD")
  if echo "$UNAVAIL_CONTEXT" | grep -q '<!-- platform:claude-code -->'; then
    pass "AC-4b: Task tracking tools unavailable row preceded by platform:claude-code marker"
  else
    fail "AC-4b: Task tracking tools unavailable row preceded by platform:claude-code marker"
    echo "    context: $UNAVAIL_CONTEXT"
  fi

  # Also verify closing marker follows
  UNAVAIL_AFTER=$(grep -A2 'Task tracking tools unavailable' "$CORE_BUILD")
  if echo "$UNAVAIL_AFTER" | grep -q '<!-- /platform -->'; then
    pass "AC-4b: Task tracking tools unavailable row followed by closing platform marker"
  else
    fail "AC-4b: Task tracking tools unavailable row followed by closing platform marker"
    echo "    context: $UNAVAIL_AFTER"
  fi

  # --- AC-4c: "Create fresh Claude Code tasks" content in compaction row is wrapped ---

  echo "--- Compaction row Claude Code tasks content wrapped with marker ---"

  # The compaction row should have the "Create fresh Claude Code tasks" text
  # inside a platform:claude-code block
  # We look for the marker either inline or wrapping that specific phrase
  COMPACTION_LINE=$(grep 'Compaction during build' "$CORE_BUILD")

  # After markers are added, "Claude Code tasks" in the compaction row must be inside a platform block
  # Check that a platform:claude-code block contains "Claude Code tasks"
  ALL_CC_BLOCKS=$(awk '/<!-- platform:claude-code -->/{capture=1; block=""} capture{block=block "\n" $0} /<!-- \/platform -->/{if(capture) print block; capture=0}' "$CORE_BUILD")
  if echo "$ALL_CC_BLOCKS" | grep -q 'Claude Code tasks'; then
    pass "AC-4c: 'Claude Code tasks' text is inside a platform:claude-code block"
  else
    fail "AC-4c: 'Claude Code tasks' text is inside a platform:claude-code block"
  fi

  # --- AC-4d: No platform markers in YAML frontmatter ---

  echo "--- No platform markers in YAML frontmatter ---"

  FRONTMATTER=$(extract_frontmatter "$CORE_BUILD")
  if echo "$FRONTMATTER" | grep -q '<!-- platform:'; then
    fail "AC-4d: no platform markers in YAML frontmatter"
    echo "    found marker in frontmatter"
  else
    pass "AC-4d: no platform markers in YAML frontmatter"
  fi

  # --- AC-4e: TaskCreate/TaskUpdate/TaskList/TaskGet still in YAML frontmatter ---

  echo "--- Task tools still present in YAML frontmatter ---"

  MISSING_TOOLS=""
  for tool in TaskCreate TaskUpdate TaskList TaskGet; do
    if ! echo "$FRONTMATTER" | grep -q "  - ${tool}"; then
      MISSING_TOOLS="$MISSING_TOOLS $tool"
    fi
  done
  if [ -z "$MISSING_TOOLS" ]; then
    pass "AC-4e: TaskCreate, TaskUpdate, TaskList, TaskGet all present in frontmatter"
  else
    fail "AC-4e: TaskCreate, TaskUpdate, TaskList, TaskGet all present in frontmatter"
    echo "    missing:$MISSING_TOOLS"
  fi

  # --- AC-4 extra: Verify the marker wraps ALL lines of the Task tracking section ---
  # A sloppy impl might only wrap the first line. Check that the disambiguation line is included.

  echo "--- Platform block includes all Task tracking content (not just first line) ---"

  if echo "$TASK_TRACKING_BLOCK" | grep -q 'Disambiguation:.*TaskCreate.*TaskUpdate'; then
    pass "AC-4 extra: platform block includes disambiguation line with tool names"
  else
    fail "AC-4 extra: platform block includes disambiguation line with tool names"
  fi

  if echo "$TASK_TRACKING_BLOCK" | grep -q 'Orchestrator-only'; then
    pass "AC-4 extra: platform block includes orchestrator-only constraint"
  else
    fail "AC-4 extra: platform block includes orchestrator-only constraint"
  fi

fi

# ═══════════════════════════════════════════════════════════════════════
# AC-5: Opencode dist sw-build excludes Claude Code content
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-5: Opencode dist sw-build excludes Claude Code content ==="
echo ""

echo "--- Running build.sh opencode ---"
BUILD_OC_OUTPUT=$(bash "$ROOT_DIR/build/build.sh" opencode 2>&1) || true
OC_BUILD_FILE="$DIST_DIR/opencode/skills/sw-build/SKILL.md"

if [ ! -f "$OC_BUILD_FILE" ]; then
  fail "AC-5: opencode build did not produce sw-build/SKILL.md (build may have failed)"
  echo "    build output: $(echo "$BUILD_OC_OUTPUT" | tail -5)"
else

  OC_BODY=$(extract_body "$OC_BUILD_FILE")
  OC_FULL=$(cat "$OC_BUILD_FILE")

  # --- AC-5a: No platform markers anywhere ---

  echo "--- No platform markers in opencode dist ---"

  if grep -q '<!-- platform:' "$OC_BUILD_FILE"; then
    fail "AC-5a: opencode dist sw-build contains no platform markers"
    echo "    found: $(grep '<!-- platform:' "$OC_BUILD_FILE")"
  else
    pass "AC-5a: opencode dist sw-build contains no platform markers"
  fi

  # --- AC-5b: Body does NOT contain TaskCreate, TaskUpdate, TaskList, TaskGet ---

  echo "--- Opencode body excludes Claude Code task tool references ---"

  FOUND_TOOLS=""
  for tool in TaskCreate TaskUpdate TaskList TaskGet; do
    if echo "$OC_BODY" | grep -q "$tool"; then
      FOUND_TOOLS="$FOUND_TOOLS $tool"
    fi
  done
  if [ -z "$FOUND_TOOLS" ]; then
    pass "AC-5b: opencode body does not mention TaskCreate/TaskUpdate/TaskList/TaskGet"
  else
    fail "AC-5b: opencode body does not mention TaskCreate/TaskUpdate/TaskList/TaskGet"
    echo "    found:$FOUND_TOOLS"
  fi

  # --- AC-5c: Body does NOT contain "Claude Code tasks" ---

  echo "--- Opencode body excludes 'Claude Code tasks' ---"

  if echo "$OC_BODY" | grep -q 'Claude Code tasks'; then
    fail "AC-5c: opencode body does not contain 'Claude Code tasks'"
    echo "    found: $(echo "$OC_BODY" | grep 'Claude Code tasks')"
  else
    pass "AC-5c: opencode body does not contain 'Claude Code tasks'"
  fi

  # --- AC-5d: Body DOES contain expected shared content ---

  echo "--- Opencode body retains shared content ---"

  for term in "RED" "GREEN" "REFACTOR"; do
    if echo "$OC_BODY" | grep -q "$term"; then
      pass "AC-5d: opencode body contains '$term'"
    else
      fail "AC-5d: opencode body contains '$term'"
    fi
  done

  for term in "specwright-tester" "specwright-executor"; do
    if echo "$OC_BODY" | grep -q "$term"; then
      pass "AC-5d: opencode body contains '$term'"
    else
      fail "AC-5d: opencode body contains '$term'"
    fi
  done

  if echo "$OC_BODY" | grep -q 'Mid-build checks'; then
    pass "AC-5d: opencode body contains 'Mid-build checks'"
  else
    fail "AC-5d: opencode body contains 'Mid-build checks'"
  fi

  # --- AC-5 extra: Task tracking section heading should NOT be in opencode body ---

  echo "--- Opencode body excludes Task tracking section ---"

  if echo "$OC_BODY" | grep -q 'Task tracking (LOW freedom)'; then
    fail "AC-5 extra: opencode body does not contain 'Task tracking (LOW freedom)'"
    echo "    found the section that should have been stripped"
  else
    pass "AC-5 extra: opencode body does not contain 'Task tracking (LOW freedom)'"
  fi

  # --- AC-5 extra: "Task tracking tools unavailable" row should NOT be present ---

  if echo "$OC_BODY" | grep -q 'Task tracking tools unavailable'; then
    fail "AC-5 extra: opencode body does not contain 'Task tracking tools unavailable'"
  else
    pass "AC-5 extra: opencode body does not contain 'Task tracking tools unavailable'"
  fi

fi

# ═══════════════════════════════════════════════════════════════════════
# AC-6: Claude-code dist sw-build preserves Claude Code content
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-6: Claude-code dist sw-build preserves Claude Code content ==="
echo ""

echo "--- Running build.sh claude-code ---"
BUILD_CC_OUTPUT=$(bash "$ROOT_DIR/build/build.sh" claude-code 2>&1) || true
CC_BUILD_FILE="$DIST_DIR/claude-code/skills/sw-build/SKILL.md"

if [ ! -f "$CC_BUILD_FILE" ]; then
  fail "AC-6: claude-code build did not produce sw-build/SKILL.md (build may have failed)"
  echo "    build output: $(echo "$BUILD_CC_OUTPUT" | tail -5)"
else

  CC_FRONTMATTER=$(extract_frontmatter "$CC_BUILD_FILE")
  CC_BODY=$(extract_body "$CC_BUILD_FILE")

  # --- AC-6a: No platform markers in output ---

  echo "--- No platform markers in claude-code dist ---"

  if grep -q '<!-- platform:' "$CC_BUILD_FILE"; then
    fail "AC-6a: claude-code dist sw-build contains no platform markers"
    echo "    found: $(grep '<!-- platform:' "$CC_BUILD_FILE")"
  else
    pass "AC-6a: claude-code dist sw-build contains no platform markers"
  fi

  # --- AC-6b: Frontmatter DOES contain TaskCreate and TaskUpdate ---

  echo "--- Claude-code frontmatter retains task tools ---"

  for tool in TaskCreate TaskUpdate; do
    if echo "$CC_FRONTMATTER" | grep -q "$tool"; then
      pass "AC-6b: claude-code frontmatter contains '$tool'"
    else
      fail "AC-6b: claude-code frontmatter contains '$tool'"
    fi
  done

  # --- AC-6c: Body DOES contain Task tracking section ---

  echo "--- Claude-code body retains Task tracking section ---"

  if echo "$CC_BODY" | grep -q 'Task tracking'; then
    pass "AC-6c: claude-code body contains 'Task tracking'"
  else
    fail "AC-6c: claude-code body contains 'Task tracking'"
  fi

  # Verify specific content from the Task tracking section survived
  if echo "$CC_BODY" | grep -q 'create.*tasks from spec/plan'; then
    pass "AC-6c: claude-code body contains task creation from spec/plan detail"
  else
    fail "AC-6c: claude-code body contains task creation from spec/plan detail"
  fi

  if echo "$CC_BODY" | grep -q 'Orchestrator-only'; then
    pass "AC-6c: claude-code body contains orchestrator-only constraint"
  else
    fail "AC-6c: claude-code body contains orchestrator-only constraint"
  fi

  # --- AC-6d: Body DOES contain Mid-build checks ---

  echo "--- Claude-code body retains Mid-build checks ---"

  if echo "$CC_BODY" | grep -q 'Mid-build checks'; then
    pass "AC-6d: claude-code body contains 'Mid-build checks'"
  else
    fail "AC-6d: claude-code body contains 'Mid-build checks'"
  fi

  # --- AC-6 extra: Task tracking tools unavailable row preserved ---

  if echo "$CC_BODY" | grep -q 'Task tracking tools unavailable'; then
    pass "AC-6 extra: claude-code body contains 'Task tracking tools unavailable' row"
  else
    fail "AC-6 extra: claude-code body contains 'Task tracking tools unavailable' row"
  fi

  # --- AC-6 extra: Claude Code tasks phrase preserved ---

  if echo "$CC_BODY" | grep -q 'Claude Code tasks'; then
    pass "AC-6 extra: claude-code body contains 'Claude Code tasks' phrase"
  else
    fail "AC-6 extra: claude-code body contains 'Claude Code tasks' phrase"
  fi

fi

# ═══════════════════════════════════════════════════════════════════════
# AC-7: Opencode adapter sw-build override is deleted
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-7: Opencode adapter sw-build override is deleted ==="
echo ""

ADAPTER_BUILD_OVERRIDE="$ROOT_DIR/adapters/opencode/skills/sw-build/SKILL.md"
OPENCODE_MAPPINGS="$ROOT_DIR/build/mappings/opencode.json"

# --- AC-7a: Adapter override file does NOT exist ---

echo "--- Adapter override file for sw-build does not exist ---"

if [ -f "$ADAPTER_BUILD_OVERRIDE" ]; then
  fail "AC-7a: adapters/opencode/skills/sw-build/SKILL.md should not exist"
  echo "    file still present at $ADAPTER_BUILD_OVERRIDE"
else
  pass "AC-7a: adapters/opencode/skills/sw-build/SKILL.md does not exist"
fi

# --- AC-7b: skillOverrides array has exactly 1 element ---

echo "--- skillOverrides array has exactly 1 element ---"

OVERRIDES_COUNT=$(jq '.skillOverrides | length' "$OPENCODE_MAPPINGS" 2>/dev/null)
assert_eq "$OVERRIDES_COUNT" "1" \
  "AC-7b: skillOverrides array length is exactly 1"

# --- AC-7c: The single element is sw-guard ---

echo "--- The single skillOverride is sw-guard ---"

FIRST_OVERRIDE=$(jq -r '.skillOverrides[0]' "$OPENCODE_MAPPINGS" 2>/dev/null)
assert_eq "$FIRST_OVERRIDE" "sw-guard" \
  "AC-7c: skillOverrides[0] is 'sw-guard'"

# --- AC-7d: sw-build is NOT in skillOverrides ---

echo "--- sw-build is not in skillOverrides ---"

BUILD_INDEX=$(jq '.skillOverrides | index("sw-build")' "$OPENCODE_MAPPINGS" 2>/dev/null)
assert_eq "$BUILD_INDEX" "null" \
  "AC-7d: sw-build is not present in skillOverrides array"

# ═══════════════════════════════════════════════════════════════════════
# AC-8: Existing opencode build tests pass with updated assertions
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-8: Opencode build tests pass with updated assertions ==="
echo ""

# Disable errexit inherited from sourcing build.sh, so subshell failures
# do not silently abort this test script.
set +e

# The opencode build test file must exit 0 (all its assertions pass).
# This catches stale references to the deleted sw-build adapter override.
# Run once and capture both exit code and output (the build test runs actual builds).

BUILD_TEST_FULL_OUTPUT=$(bash "$ROOT_DIR/tests/test-opencode-build.sh" < /dev/null 2>&1)
BUILD_TEST_EXIT=$?
BUILD_TEST_LAST_LINE=$(echo "$BUILD_TEST_FULL_OUTPUT" | tail -1)

if [ "$BUILD_TEST_EXIT" -eq 0 ]; then
  pass "AC-8: test-opencode-build.sh exits 0"
else
  fail "AC-8: test-opencode-build.sh exits 0"
fi

if echo "$BUILD_TEST_LAST_LINE" | grep -q "0 failed"; then
  pass "AC-8: test-opencode-build.sh reports 0 failures"
else
  fail "AC-8: test-opencode-build.sh reports 0 failures (got: $BUILD_TEST_LAST_LINE)"
fi

# AC-8 specifics: verify the test file itself was updated correctly.
# The AC-10 override loop must iterate only sw-guard (not sw-build).

AC10_LOOP_LINE=$(grep -n 'for override_skill in' "$ROOT_DIR/tests/test-opencode-build.sh" || true)
if echo "$AC10_LOOP_LINE" | grep -q 'sw-build'; then
  fail "AC-8: test-opencode-build.sh AC-10 loop still includes sw-build"
else
  pass "AC-8: test-opencode-build.sh AC-10 loop does not include sw-build"
fi

if echo "$AC10_LOOP_LINE" | grep -q 'sw-guard'; then
  pass "AC-8: test-opencode-build.sh AC-10 loop includes sw-guard"
else
  fail "AC-8: test-opencode-build.sh AC-10 loop missing sw-guard"
fi

# The test file must have a NEW section that verifies the dist opencode sw-build
# has no markers, no Task CRUD tool references in body, and preserved TDD content.
# These checks must be about the dist sw-build file specifically (not just
# the general frontmatter tool stripping that already exists).

BUILD_TEST_CONTENT=$(cat "$ROOT_DIR/tests/test-opencode-build.sh")

# Must check the dist sw-build body for platform markers (not just frontmatter tools).
# The check must reference sw-build in the context of platform marker checking.
if echo "$BUILD_TEST_CONTENT" | grep -q 'sw-build.*platform:\|platform:.*sw-build'; then
  pass "AC-8: test-opencode-build.sh checks dist sw-build for platform markers"
else
  fail "AC-8: test-opencode-build.sh missing platform marker check for dist sw-build body"
fi

# Must check the dist sw-build body for Task CRUD tool references.
# This is distinct from the frontmatter stripped-tools check (AC-7 section).
# We look for a body-level check that greps for TaskCreate in the sw-build body content.
if echo "$BUILD_TEST_CONTENT" | grep -q 'OC_BUILD_BODY\|oc_build_body\|extract_body.*sw-build\|sw-build.*body.*Task'; then
  pass "AC-8: test-opencode-build.sh checks dist sw-build body for Task CRUD references"
else
  fail "AC-8: test-opencode-build.sh missing body-level Task CRUD check for dist sw-build"
fi

# Must verify TDD content (RED/GREEN/REFACTOR) is preserved in the dist sw-build output.
# This is a new section, not something that existed before. Check for TDD terms
# in the context of sw-build dist verification.
if echo "$BUILD_TEST_CONTENT" | grep -q 'OC_BUILD_BODY.*RED\|OC_BUILD_BODY.*GREEN\|OC_BUILD_BODY.*REFACTOR\|sw-build.*RED\|sw-build.*GREEN\|sw-build.*REFACTOR\|TDD.*sw-build\|sw-build.*TDD'; then
  pass "AC-8: test-opencode-build.sh has TDD content preservation checks for dist sw-build"
else
  fail "AC-8: test-opencode-build.sh missing TDD content preservation checks for dist sw-build"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-9: Opencode overrides test updated for new pattern
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-9: Opencode overrides test updated for new pattern ==="
echo ""

# The overrides test file must exit 0 (all its assertions pass).
# Run once and capture both exit code and output.

OVERRIDE_TEST_FULL_OUTPUT=$(bash "$ROOT_DIR/tests/test-opencode-overrides.sh" < /dev/null 2>&1)
OVERRIDE_TEST_EXIT=$?
OVERRIDE_TEST_LAST_LINE=$(echo "$OVERRIDE_TEST_FULL_OUTPUT" | tail -1)

if [ "$OVERRIDE_TEST_EXIT" -eq 0 ]; then
  pass "AC-9: test-opencode-overrides.sh exits 0"
else
  fail "AC-9: test-opencode-overrides.sh exits 0"
fi

if echo "$OVERRIDE_TEST_LAST_LINE" | grep -q "0 failed"; then
  pass "AC-9: test-opencode-overrides.sh reports 0 failures"
else
  fail "AC-9: test-opencode-overrides.sh reports 0 failures (got: $OVERRIDE_TEST_LAST_LINE)"
fi

# AC-9 specifics: verify the overrides test checks the new pattern.

OVERRIDE_TEST_CONTENT=$(cat "$ROOT_DIR/tests/test-opencode-overrides.sh")

# (a) Must verify adapters/opencode/skills/sw-build/SKILL.md does NOT exist.
# The test must treat non-existence as a PASS (not a failure).
# We check for a "! -f" test pattern with a corresponding pass() call,
# which distinguishes the new pattern from the old one that treated non-existence as fail.
if echo "$OVERRIDE_TEST_CONTENT" | grep -q '! -f.*sw-build'; then
  pass "AC-9a: test-opencode-overrides.sh has ! -f check for sw-build override"
else
  fail "AC-9a: test-opencode-overrides.sh missing ! -f check that sw-build override does not exist"
fi

# (b) Must verify core/skills/sw-build/SKILL.md contains platform:claude-code marker
if echo "$OVERRIDE_TEST_CONTENT" | grep -q 'platform:claude-code'; then
  pass "AC-9b: test-opencode-overrides.sh checks for platform:claude-code in core sw-build"
else
  fail "AC-9b: test-opencode-overrides.sh missing check for platform:claude-code in core sw-build"
fi

# (c) Must verify skillOverrides does not contain sw-build
if echo "$OVERRIDE_TEST_CONTENT" | grep -q 'skillOverrides.*sw-build\|sw-build.*skillOverrides'; then
  pass "AC-9c: test-opencode-overrides.sh checks skillOverrides excludes sw-build"
else
  fail "AC-9c: test-opencode-overrides.sh missing check that skillOverrides excludes sw-build"
fi

# The sw-guard tests must be unchanged -- verify they still exist
if echo "$OVERRIDE_TEST_CONTENT" | grep -q 'sw-guard.*SKILL.md'; then
  pass "AC-9: test-opencode-overrides.sh still has sw-guard tests"
else
  fail "AC-9: test-opencode-overrides.sh lost sw-guard tests (should be unchanged)"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-10: Build regression — both platforms still build successfully
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-10: Build regression — both platforms still build successfully ==="
echo ""

# Run a fresh build of both platforms
echo "--- Running build.sh all ---"
BUILD_ALL_OUTPUT=$(bash "$ROOT_DIR/build/build.sh" all 2>&1)
BUILD_ALL_EXIT=$?

assert_eq "$BUILD_ALL_EXIT" "0" \
  "AC-10a: build.sh all exits 0"

if [ "$BUILD_ALL_EXIT" -ne 0 ]; then
  echo "    build output (last 10 lines):"
  echo "$BUILD_ALL_OUTPUT" | tail -10 | sed 's/^/    /'
fi

# --- AC-10b: claude-code dist has exactly 19 skill directories ---

echo "--- claude-code dist skill directory count ---"

CC_SKILL_COUNT=0
if [ -d "$ROOT_DIR/dist/claude-code/skills" ]; then
  CC_SKILL_COUNT=$(find "$ROOT_DIR/dist/claude-code/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
fi
assert_eq "$CC_SKILL_COUNT" "19" \
  "AC-10b: claude-code dist contains 19 skill directories"

# --- AC-10c: claude-code dist has exactly 6 agent files ---

echo "--- claude-code dist agent file count ---"

CC_AGENT_COUNT=0
if [ -d "$ROOT_DIR/dist/claude-code/agents" ]; then
  CC_AGENT_COUNT=$(find "$ROOT_DIR/dist/claude-code/agents" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')
fi
assert_eq "$CC_AGENT_COUNT" "6" \
  "AC-10c: claude-code dist contains 6 agent files"

# --- AC-10d: claude-code dist has exactly 19 protocol files ---

echo "--- claude-code dist protocol file count ---"

CC_PROTOCOL_COUNT=0
if [ -d "$ROOT_DIR/dist/claude-code/protocols" ]; then
  CC_PROTOCOL_COUNT=$(find "$ROOT_DIR/dist/claude-code/protocols" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')
fi
assert_eq "$CC_PROTOCOL_COUNT" "19" \
  "AC-10d: claude-code dist contains 19 protocol files"

# --- AC-10e: opencode dist has exactly 19 skill directories ---

echo "--- opencode dist skill directory count ---"

OC_SKILL_COUNT=0
if [ -d "$ROOT_DIR/dist/opencode/skills" ]; then
  OC_SKILL_COUNT=$(find "$ROOT_DIR/dist/opencode/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
fi
assert_eq "$OC_SKILL_COUNT" "19" \
  "AC-10e: opencode dist contains 19 skill directories"

# --- AC-10f: opencode dist has exactly 6 agent files ---

echo "--- opencode dist agent file count ---"

OC_AGENT_COUNT=0
if [ -d "$ROOT_DIR/dist/opencode/agents" ]; then
  OC_AGENT_COUNT=$(find "$ROOT_DIR/dist/opencode/agents" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')
fi
assert_eq "$OC_AGENT_COUNT" "6" \
  "AC-10f: opencode dist contains 6 agent files"

# --- AC-10g: opencode dist has exactly 19 protocol files ---

echo "--- opencode dist protocol file count ---"

OC_PROTOCOL_COUNT=0
if [ -d "$ROOT_DIR/dist/opencode/protocols" ]; then
  OC_PROTOCOL_COUNT=$(find "$ROOT_DIR/dist/opencode/protocols" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')
fi
assert_eq "$OC_PROTOCOL_COUNT" "19" \
  "AC-10g: opencode dist contains 19 protocol files"

# ═══════════════════════════════════════════════════════════════════════
# AC-11: Documentation reflects platform markers and override changes
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-11: Documentation reflects platform markers and override changes ==="
echo ""

DESIGN_DOC="$ROOT_DIR/DESIGN.md"

# --- AC-11a: DESIGN.md mentions platform markers as a build transformation step ---

echo "--- DESIGN.md mentions platform markers concept ---"

if grep -qi 'platform' "$DESIGN_DOC" 2>/dev/null; then
  # "platform" alone is too weak -- it could match "cross-platform" etc.
  # We need it to reference platform markers as part of the build/transformation pipeline.
  # Check for the concept of platform markers in a build context.
  if grep -qi 'platform.*marker\|marker.*platform\|platform.*strip\|strip.*platform\|platform.*section\|platform.*transform\|platform.*block' "$DESIGN_DOC" 2>/dev/null; then
    pass "AC-11a: DESIGN.md references platform markers concept"
  else
    fail "AC-11a: DESIGN.md references platform markers concept (found 'platform' but not in marker/transform context)"
  fi
else
  fail "AC-11a: DESIGN.md references platform markers concept (word 'platform' not found at all)"
fi

# --- AC-11a extra: The platform markers mention is in a build system context ---
# A sloppy implementation might mention "platform markers" in a random place
# without connecting it to the build/transformation pipeline.

echo "--- DESIGN.md describes platform markers as a build transformation step ---"

# Check that "platform" and a build-related term appear in the same section
# (within 10 lines of each other, or in a section with "build" in the heading)
if grep -qi 'build.*platform\|platform.*build\|transform.*platform\|platform.*transform' "$DESIGN_DOC" 2>/dev/null; then
  pass "AC-11a extra: DESIGN.md connects platform markers to build/transform pipeline"
else
  fail "AC-11a extra: DESIGN.md connects platform markers to build/transform pipeline"
fi

# --- AC-11b: DESIGN.md does NOT list sw-build as a skill override ---
# grep for sw-build appearing near "override" -- should not match

echo "--- DESIGN.md does not list sw-build as a skill override ---"

if grep -qi 'sw-build.*override\|override.*sw-build' "$DESIGN_DOC" 2>/dev/null; then
  fail "AC-11b: DESIGN.md should not reference sw-build as an override"
  echo "    found: $(grep -i 'sw-build.*override\|override.*sw-build' "$DESIGN_DOC")"
else
  pass "AC-11b: DESIGN.md does not reference sw-build as an override"
fi

# --- AC-11c: If DESIGN.md mentions skillOverrides, it only references sw-guard ---

echo "--- If DESIGN.md mentions skillOverrides, only sw-guard is listed ---"

SKILL_OVERRIDE_LINES=$(grep -i 'skillOverrides\|skill.override' "$DESIGN_DOC" 2>/dev/null || true)
if [ -n "$SKILL_OVERRIDE_LINES" ]; then
  # skillOverrides is mentioned -- verify sw-build is NOT referenced alongside it
  if echo "$SKILL_OVERRIDE_LINES" | grep -qi 'sw-build'; then
    fail "AC-11c: DESIGN.md skillOverrides mention includes sw-build (should only be sw-guard)"
    echo "    found: $SKILL_OVERRIDE_LINES"
  else
    pass "AC-11c: DESIGN.md skillOverrides does not include sw-build"
  fi
else
  # No mention of skillOverrides at all -- acceptable
  pass "AC-11c: DESIGN.md does not mention skillOverrides (acceptable)"
fi

# --- AC-11d: If DESIGN.md or CLAUDE.md reference the adapter skill override pattern,
#     they note that sw-build is derived from core via conditional markers, not overrides ---

echo "--- Docs note sw-build is derived via markers, not overrides ---"

CLAUDE_DOC="$ROOT_DIR/CLAUDE.md"

# Check DESIGN.md
DESIGN_ADAPTER_REFS=$(grep -i 'adapter.*override\|override.*adapter\|skill.*override' "$DESIGN_DOC" 2>/dev/null || true)
if [ -n "$DESIGN_ADAPTER_REFS" ]; then
  # If adapter override pattern is mentioned, sw-build must NOT be listed as an override
  if echo "$DESIGN_ADAPTER_REFS" | grep -qi 'sw-build'; then
    fail "AC-11d: DESIGN.md adapter override reference incorrectly includes sw-build"
  else
    pass "AC-11d: DESIGN.md adapter override references do not include sw-build"
  fi
else
  pass "AC-11d: DESIGN.md does not reference adapter override pattern (acceptable)"
fi

# Check CLAUDE.md
CLAUDE_ADAPTER_REFS=$(grep -i 'adapter.*override\|override.*adapter\|skill.*override' "$CLAUDE_DOC" 2>/dev/null || true)
if [ -n "$CLAUDE_ADAPTER_REFS" ]; then
  if echo "$CLAUDE_ADAPTER_REFS" | grep -qi 'sw-build'; then
    fail "AC-11d: CLAUDE.md adapter override reference incorrectly includes sw-build"
  else
    pass "AC-11d: CLAUDE.md adapter override references do not include sw-build"
  fi
else
  pass "AC-11d: CLAUDE.md does not reference adapter override pattern (acceptable)"
fi

# ─── Summary ──────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
