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

# Source build.sh in a way that loads functions but does not run main logic.
# build.sh uses set -euo pipefail and runs commands at top level,
# so we source it carefully.
source_build_functions() {
  # Temporarily override set -e so sourcing doesn't abort on error
  set +e
  # Source the file; if it has top-level execution guarded by arguments
  # we may need to handle that. For now, just source it.
  source "$BUILD_SCRIPT"
  set -e
}

# Try sourcing -- if strip_platform_sections is not defined, tests will
# fail at the assertion level (not import level), which is correct RED behavior.
source_build_functions 2>/dev/null || true

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

INPUT_FAKE_MARKER="line one
<!-- platform:claude-code -->content on same line
real content
<!-- /platform -->
line two"

# The spec says markers are full lines: <!-- platform:X -->
# If content is on the same line as the marker comment, that line IS the marker
# and should be treated as such (removed for non-matching, removed for matching)
# This test verifies the function processes lines containing marker patterns

INPUT_NOT_MARKER="line one
this is not <!-- platform:claude-code --> a marker
line two"

ACTUAL=$(run_strip "$INPUT_NOT_MARKER" "opencode") || true
# An inline marker fragment should NOT trigger block behavior --
# the marker should be on its own line to be recognized
assert_eq "$ACTUAL" "$INPUT_NOT_MARKER" \
  "inline marker-like text not on its own line: not treated as block delimiter"

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

# ─── Summary ──────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
