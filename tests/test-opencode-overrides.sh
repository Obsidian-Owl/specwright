#!/usr/bin/env bash
#
# Tests for AC-5: Opencode skill overrides replace platform-specific content
#
# Validates two override SKILL.md files against the spec:
#
# sw-guard override:
#   - File exists at adapters/opencode/skills/sw-guard/SKILL.md
#   - Valid YAML frontmatter with name: sw-guard and description
#   - Has all 6 standard sections (Goal, Inputs, Outputs, Constraints, Protocol References, Failure Modes)
#   - Does NOT contain .claude/settings.json, .claude/settings.local.json, or PostToolUse
#   - References opencode.json or Opencode plugin events
#   - Is NOT identical to core/skills/sw-guard/SKILL.md
#
# sw-build override:
#   - File exists at adapters/opencode/skills/sw-build/SKILL.md
#   - Valid YAML frontmatter with name: sw-build and description
#   - Has all 6 standard sections
#   - Does NOT contain TaskCreate, TaskUpdate, TaskList, TaskGet (including frontmatter)
#   - Does NOT contain "Claude Code tasks" (case insensitive)
#   - Preserves TDD content (RED, GREEN, REFACTOR, tester, executor)
#   - Preserves agent delegation content (specwright-tester, specwright-executor)
#   - Is NOT identical to core/skills/sw-build/SKILL.md
#   - Frontmatter allowed-tools does NOT include TaskCreate/TaskUpdate/TaskList/TaskGet
#
# Cross-checks:
#   - Both files are 500+ bytes
#   - Both files have substantial body content beyond frontmatter
#   - The two override files are not copies of each other
#
# Dependencies: bash
# Usage: ./tests/test-opencode-overrides.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GUARD_OVERRIDE="$ROOT_DIR/adapters/opencode/skills/sw-guard/SKILL.md"
BUILD_OVERRIDE="$ROOT_DIR/adapters/opencode/skills/sw-build/SKILL.md"
GUARD_CORE="$ROOT_DIR/core/skills/sw-guard/SKILL.md"
BUILD_CORE="$ROOT_DIR/core/skills/sw-build/SKILL.md"

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
# Prints the frontmatter lines (excluding the --- delimiters) to stdout.
# Returns 1 if frontmatter is missing or malformed.
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
# Returns 1 if frontmatter is missing.
extract_body() {
  local file="$1"
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  tail -n +"$((closing_line + 2))" "$file"
}

# ─── Pre-flight ──────────────────────────────────────────────────────

echo "=== AC-5: Opencode skill overrides ==="
echo ""

# Verify core files exist (needed for comparison)
if [ ! -f "$GUARD_CORE" ]; then
  echo "ABORT: core sw-guard SKILL.md not found at $GUARD_CORE"
  exit 1
fi
if [ ! -f "$BUILD_CORE" ]; then
  echo "ABORT: core sw-build SKILL.md not found at $BUILD_CORE"
  exit 1
fi

# ═══════════════════════════════════════════════════════════════════════
# sw-guard override
# ═══════════════════════════════════════════════════════════════════════

echo "--- sw-guard: file existence ---"

if [ -f "$GUARD_OVERRIDE" ]; then
  pass "sw-guard override SKILL.md exists"
else
  fail "sw-guard override SKILL.md does not exist at $GUARD_OVERRIDE"
  # Record remaining failures but skip content checks
fi

# ─── sw-guard: YAML frontmatter ──────────────────────────────────────

echo "--- sw-guard: YAML frontmatter ---"

if [ -f "$GUARD_OVERRIDE" ]; then
  # Must start with ---
  GUARD_FIRST=$(head -n 1 "$GUARD_OVERRIDE")
  if [ "$GUARD_FIRST" = "---" ]; then
    pass "sw-guard starts with --- (frontmatter opening)"
  else
    fail "sw-guard does not start with --- (got: '$GUARD_FIRST')"
  fi

  # Must have a closing ---
  GUARD_CLOSING=$(tail -n +2 "$GUARD_OVERRIDE" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -n "$GUARD_CLOSING" ] && [ "$GUARD_CLOSING" -gt 0 ]; then
    pass "sw-guard has closing --- (frontmatter end)"
  else
    fail "sw-guard has no closing --- (frontmatter never closed)"
  fi

  GUARD_FM=$(extract_frontmatter "$GUARD_OVERRIDE" || true)

  # name: sw-guard
  if echo "$GUARD_FM" | grep -qE '^name:\s*sw-guard\s*$'; then
    pass "sw-guard frontmatter has name: sw-guard"
  else
    fail "sw-guard frontmatter missing or wrong name field (expected 'name: sw-guard')"
  fi

  # description: (must exist and be non-empty)
  if echo "$GUARD_FM" | grep -qE '^description:'; then
    pass "sw-guard frontmatter has description field"
  else
    fail "sw-guard frontmatter missing description field"
  fi

  # description value must be non-trivial (at least 10 chars after "description:")
  GUARD_DESC=$(echo "$GUARD_FM" | grep -E '^description:' | sed 's/^description:\s*//' | sed "s/^['\">]*//" | xargs)
  GUARD_DESC_LEN=${#GUARD_DESC}
  if [ "$GUARD_DESC_LEN" -ge 10 ]; then
    pass "sw-guard description is meaningful ($GUARD_DESC_LEN chars)"
  else
    # description might be multi-line YAML (using >- or |), check for that
    if echo "$GUARD_FM" | grep -qE '^description:\s*[>|]-?\s*$'; then
      # Multi-line YAML -- check the next line for content
      GUARD_DESC_NEXT=$(echo "$GUARD_FM" | grep -A1 '^description:' | tail -1 | xargs)
      if [ ${#GUARD_DESC_NEXT} -ge 10 ]; then
        pass "sw-guard description is meaningful (multi-line YAML, next line: ${#GUARD_DESC_NEXT} chars)"
      else
        fail "sw-guard description is too short even in multi-line form"
      fi
    else
      fail "sw-guard description is suspiciously short ($GUARD_DESC_LEN chars: '$GUARD_DESC')"
    fi
  fi
fi

# ─── sw-guard: standard SKILL.md sections ────────────────────────────

echo "--- sw-guard: standard sections ---"

if [ -f "$GUARD_OVERRIDE" ]; then
  GUARD_BODY=$(extract_body "$GUARD_OVERRIDE" || true)

  for section in "Goal" "Inputs" "Outputs" "Constraints" "Protocol References" "Failure Modes"; do
    if echo "$GUARD_BODY" | grep -qE "^##\s+${section}"; then
      pass "sw-guard has ## $section section"
    else
      fail "sw-guard missing ## $section section"
    fi
  done
fi

# ─── sw-guard: must NOT reference Claude Code settings ────────────────

echo "--- sw-guard: no Claude Code settings references ---"

if [ -f "$GUARD_OVERRIDE" ]; then
  # .claude/settings.json
  if grep -qF '.claude/settings.json' "$GUARD_OVERRIDE"; then
    fail "sw-guard references .claude/settings.json (must be removed)"
  else
    pass "sw-guard does NOT reference .claude/settings.json"
  fi

  # .claude/settings.local.json
  if grep -qF '.claude/settings.local.json' "$GUARD_OVERRIDE"; then
    fail "sw-guard references .claude/settings.local.json (must be removed)"
  else
    pass "sw-guard does NOT reference .claude/settings.local.json"
  fi

  # PostToolUse
  if grep -qF 'PostToolUse' "$GUARD_OVERRIDE"; then
    fail "sw-guard references PostToolUse (must be removed)"
  else
    pass "sw-guard does NOT reference PostToolUse"
  fi

  # Also check for settings.json without the .claude/ prefix (catch partial removal)
  # Only flag if it looks like a Claude Code settings reference, not generic
  if grep -qE '(\.claude.*settings|settings\.json.*session|session.*settings\.json)' "$GUARD_OVERRIDE"; then
    fail "sw-guard still references Claude Code settings patterns"
  else
    pass "sw-guard has no Claude Code settings patterns"
  fi
fi

# ─── sw-guard: must reference opencode.json or Opencode plugin events ─

echo "--- sw-guard: Opencode references ---"

if [ -f "$GUARD_OVERRIDE" ]; then
  # Must reference opencode.json OR opencode plugin events
  HAS_OPENCODE_JSON=false
  HAS_OPENCODE_PLUGIN=false

  if grep -qF 'opencode.json' "$GUARD_OVERRIDE"; then
    HAS_OPENCODE_JSON=true
  fi

  # Check for Opencode plugin event references (tool.execute.after, session.created, etc.)
  if grep -qEi '(opencode\s+plugin|plugin\s+event|tool\.execute)' "$GUARD_OVERRIDE"; then
    HAS_OPENCODE_PLUGIN=true
  fi

  if [ "$HAS_OPENCODE_JSON" = true ] || [ "$HAS_OPENCODE_PLUGIN" = true ]; then
    pass "sw-guard references opencode.json or Opencode plugin events"
  else
    fail "sw-guard does NOT reference opencode.json or Opencode plugin events"
  fi

  # Verify the reference is in a meaningful context (not just a comment or stray mention)
  # The opencode.json reference should appear in Outputs or Constraints (where settings config is discussed)
  if [ "$HAS_OPENCODE_JSON" = true ]; then
    GUARD_BODY_TRIMMED=$(extract_body "$GUARD_OVERRIDE" || true)
    if echo "$GUARD_BODY_TRIMMED" | grep -qF 'opencode.json'; then
      pass "sw-guard references opencode.json in the body (not just frontmatter)"
    else
      fail "sw-guard only references opencode.json in frontmatter, not body (should be in Outputs/Constraints)"
    fi
  fi
fi

# ─── sw-guard: not identical to core ──────────────────────────────────

echo "--- sw-guard: divergence from core ---"

if [ -f "$GUARD_OVERRIDE" ]; then
  if diff -q "$GUARD_OVERRIDE" "$GUARD_CORE" &>/dev/null; then
    fail "sw-guard override is identical to core version (must have platform-specific changes)"
  else
    pass "sw-guard override differs from core version"
  fi

  # Verify it's not just a trivial one-line diff (e.g., only changed the name)
  GUARD_DIFF_LINES=$(diff "$GUARD_OVERRIDE" "$GUARD_CORE" 2>/dev/null | grep -c '^[<>]' || true)
  if [ "$GUARD_DIFF_LINES" -ge 4 ]; then
    pass "sw-guard has substantial differences from core ($GUARD_DIFF_LINES differing lines)"
  else
    fail "sw-guard has only $GUARD_DIFF_LINES differing lines from core (too similar -- likely not enough platform changes)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# sw-build override
# ═══════════════════════════════════════════════════════════════════════

echo "--- sw-build: file existence ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  pass "sw-build override SKILL.md exists"
else
  fail "sw-build override SKILL.md does not exist at $BUILD_OVERRIDE"
fi

# ─── sw-build: YAML frontmatter ──────────────────────────────────────

echo "--- sw-build: YAML frontmatter ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  # Must start with ---
  BUILD_FIRST=$(head -n 1 "$BUILD_OVERRIDE")
  if [ "$BUILD_FIRST" = "---" ]; then
    pass "sw-build starts with --- (frontmatter opening)"
  else
    fail "sw-build does not start with --- (got: '$BUILD_FIRST')"
  fi

  # Must have a closing ---
  BUILD_CLOSING=$(tail -n +2 "$BUILD_OVERRIDE" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -n "$BUILD_CLOSING" ] && [ "$BUILD_CLOSING" -gt 0 ]; then
    pass "sw-build has closing --- (frontmatter end)"
  else
    fail "sw-build has no closing --- (frontmatter never closed)"
  fi

  BUILD_FM=$(extract_frontmatter "$BUILD_OVERRIDE" || true)

  # name: sw-build
  if echo "$BUILD_FM" | grep -qE '^name:\s*sw-build\s*$'; then
    pass "sw-build frontmatter has name: sw-build"
  else
    fail "sw-build frontmatter missing or wrong name field (expected 'name: sw-build')"
  fi

  # description: (must exist and be non-empty)
  if echo "$BUILD_FM" | grep -qE '^description:'; then
    pass "sw-build frontmatter has description field"
  else
    fail "sw-build frontmatter missing description field"
  fi

  # description value must be non-trivial
  BUILD_DESC=$(echo "$BUILD_FM" | grep -E '^description:' | sed 's/^description:\s*//' | sed "s/^['\">]*//" | xargs)
  BUILD_DESC_LEN=${#BUILD_DESC}
  if [ "$BUILD_DESC_LEN" -ge 10 ]; then
    pass "sw-build description is meaningful ($BUILD_DESC_LEN chars)"
  else
    if echo "$BUILD_FM" | grep -qE '^description:\s*[>|]-?\s*$'; then
      BUILD_DESC_NEXT=$(echo "$BUILD_FM" | grep -A1 '^description:' | tail -1 | xargs)
      if [ ${#BUILD_DESC_NEXT} -ge 10 ]; then
        pass "sw-build description is meaningful (multi-line YAML, next line: ${#BUILD_DESC_NEXT} chars)"
      else
        fail "sw-build description is too short even in multi-line form"
      fi
    else
      fail "sw-build description is suspiciously short ($BUILD_DESC_LEN chars: '$BUILD_DESC')"
    fi
  fi
fi

# ─── sw-build: standard SKILL.md sections ────────────────────────────

echo "--- sw-build: standard sections ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_BODY=$(extract_body "$BUILD_OVERRIDE" || true)

  for section in "Goal" "Inputs" "Outputs" "Constraints" "Protocol References" "Failure Modes"; do
    if echo "$BUILD_BODY" | grep -qE "^##\s+${section}"; then
      pass "sw-build has ## $section section"
    else
      fail "sw-build missing ## $section section"
    fi
  done
fi

# ─── sw-build: must NOT reference Claude Code task tools ──────────────

echo "--- sw-build: no Claude Code task tool references ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  # TaskCreate must NOT appear anywhere (frontmatter or body)
  if grep -qF 'TaskCreate' "$BUILD_OVERRIDE"; then
    fail "sw-build references TaskCreate (must be removed)"
  else
    pass "sw-build does NOT reference TaskCreate"
  fi

  # TaskUpdate must NOT appear anywhere
  if grep -qF 'TaskUpdate' "$BUILD_OVERRIDE"; then
    fail "sw-build references TaskUpdate (must be removed)"
  else
    pass "sw-build does NOT reference TaskUpdate"
  fi

  # TaskList must NOT appear anywhere
  if grep -qF 'TaskList' "$BUILD_OVERRIDE"; then
    fail "sw-build references TaskList (must be removed)"
  else
    pass "sw-build does NOT reference TaskList"
  fi

  # TaskGet must NOT appear anywhere
  if grep -qF 'TaskGet' "$BUILD_OVERRIDE"; then
    fail "sw-build references TaskGet (must be removed)"
  else
    pass "sw-build does NOT reference TaskGet"
  fi

  # "Claude Code tasks" case-insensitive must NOT appear
  if grep -qi 'Claude Code tasks' "$BUILD_OVERRIDE"; then
    fail "sw-build references 'Claude Code tasks' (must be removed)"
  else
    pass "sw-build does NOT reference 'Claude Code tasks'"
  fi
fi

# ─── sw-build: frontmatter allowed-tools must not include Task CRUD ───

echo "--- sw-build: frontmatter allowed-tools ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_FM=$(extract_frontmatter "$BUILD_OVERRIDE" || true)

  # Check that allowed-tools section exists
  if echo "$BUILD_FM" | grep -qE '^allowed-tools:'; then
    pass "sw-build frontmatter has allowed-tools field"
  else
    fail "sw-build frontmatter missing allowed-tools field"
  fi

  # Extract the allowed-tools list items (lines starting with "  - ")
  # These are YAML list items under allowed-tools:
  BUILD_TOOLS=$(echo "$BUILD_FM" | sed -n '/^allowed-tools:/,/^[a-z]/{ /^  - /p }')

  for banned_tool in TaskCreate TaskUpdate TaskList TaskGet; do
    if echo "$BUILD_TOOLS" | grep -qF "$banned_tool"; then
      fail "sw-build frontmatter allowed-tools includes $banned_tool (must be stripped)"
    else
      pass "sw-build frontmatter allowed-tools does NOT include $banned_tool"
    fi
  done

  # Verify allowed-tools still has useful tools (not accidentally emptied)
  BUILD_TOOL_COUNT=$(echo "$BUILD_TOOLS" | grep -c '^\s*-' || true)
  if [ "$BUILD_TOOL_COUNT" -ge 3 ]; then
    pass "sw-build allowed-tools has $BUILD_TOOL_COUNT tools (not accidentally emptied)"
  else
    fail "sw-build allowed-tools has only $BUILD_TOOL_COUNT tools (may have been over-stripped)"
  fi
fi

# ─── sw-build: must preserve TDD content ─────────────────────────────

echo "--- sw-build: TDD content preserved ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_BODY=$(extract_body "$BUILD_OVERRIDE" || true)

  # Must reference RED phase
  if echo "$BUILD_BODY" | grep -qF 'RED'; then
    pass "sw-build body references RED phase"
  else
    fail "sw-build body does NOT reference RED phase (TDD content missing)"
  fi

  # Must reference GREEN phase
  if echo "$BUILD_BODY" | grep -qF 'GREEN'; then
    pass "sw-build body references GREEN phase"
  else
    fail "sw-build body does NOT reference GREEN phase (TDD content missing)"
  fi

  # Must reference REFACTOR phase
  if echo "$BUILD_BODY" | grep -qF 'REFACTOR'; then
    pass "sw-build body references REFACTOR phase"
  else
    fail "sw-build body does NOT reference REFACTOR phase (TDD content missing)"
  fi

  # Must reference the tester role
  if echo "$BUILD_BODY" | grep -qi 'tester'; then
    pass "sw-build body references tester"
  else
    fail "sw-build body does NOT reference tester (TDD delegation content missing)"
  fi

  # Must reference the executor role
  if echo "$BUILD_BODY" | grep -qi 'executor'; then
    pass "sw-build body references executor"
  else
    fail "sw-build body does NOT reference executor (TDD delegation content missing)"
  fi

  # TDD cycle section header should exist
  if echo "$BUILD_BODY" | grep -qE 'TDD\s+(cycle|Cycle)'; then
    pass "sw-build body has TDD cycle section"
  else
    fail "sw-build body missing TDD cycle section"
  fi
fi

# ─── sw-build: must preserve agent delegation ────────────────────────

echo "--- sw-build: agent delegation preserved ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_BODY=$(extract_body "$BUILD_OVERRIDE" || true)

  # Must reference specwright-tester agent
  if echo "$BUILD_BODY" | grep -qF 'specwright-tester'; then
    pass "sw-build body references specwright-tester agent"
  else
    fail "sw-build body does NOT reference specwright-tester agent"
  fi

  # Must reference specwright-executor agent
  if echo "$BUILD_BODY" | grep -qF 'specwright-executor'; then
    pass "sw-build body references specwright-executor agent"
  else
    fail "sw-build body does NOT reference specwright-executor agent"
  fi

  # Must reference delegation protocol
  if echo "$BUILD_BODY" | grep -qF 'protocols/delegation.md'; then
    pass "sw-build body references protocols/delegation.md"
  else
    fail "sw-build body does NOT reference protocols/delegation.md"
  fi
fi

# ─── sw-build: must NOT have Claude Code task tracking section ────────

echo "--- sw-build: no Claude Code task tracking ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_BODY=$(extract_body "$BUILD_OVERRIDE" || true)

  # The core version has a "Task tracking" section with Claude Code-specific task API
  # The override should NOT have the disambiguation note about TaskCreate vs Task
  if echo "$BUILD_BODY" | grep -qi 'TaskCreate.*TaskUpdate.*visual.*progress'; then
    fail "sw-build body still has Claude Code task tracking disambiguation (should be removed)"
  else
    pass "sw-build body does NOT have Claude Code task tracking disambiguation"
  fi

  # The core mentions "Claude Code tasks from spec/plan" -- this should be gone
  if echo "$BUILD_BODY" | grep -qi 'create.*Claude Code tasks'; then
    fail "sw-build body still mentions creating Claude Code tasks"
  else
    pass "sw-build body does NOT mention creating Claude Code tasks"
  fi
fi

# ─── sw-build: not identical to core ──────────────────────────────────

echo "--- sw-build: divergence from core ---"

if [ -f "$BUILD_OVERRIDE" ]; then
  if diff -q "$BUILD_OVERRIDE" "$BUILD_CORE" &>/dev/null; then
    fail "sw-build override is identical to core version (must have platform-specific changes)"
  else
    pass "sw-build override differs from core version"
  fi

  # Verify it's not just a trivial one-line diff
  BUILD_DIFF_LINES=$(diff "$BUILD_OVERRIDE" "$BUILD_CORE" 2>/dev/null | grep -c '^[<>]' || true)
  if [ "$BUILD_DIFF_LINES" -ge 4 ]; then
    pass "sw-build has substantial differences from core ($BUILD_DIFF_LINES differing lines)"
  else
    fail "sw-build has only $BUILD_DIFF_LINES differing lines from core (too similar -- likely not enough platform changes)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# Cross-checks (catch lazy implementations)
# ═══════════════════════════════════════════════════════════════════════

echo "--- Cross-checks ---"

# ─── File size checks (these are substantial skill files, not stubs) ──

if [ -f "$GUARD_OVERRIDE" ]; then
  GUARD_SIZE=$(wc -c < "$GUARD_OVERRIDE")
  if [ "$GUARD_SIZE" -ge 500 ]; then
    pass "sw-guard override is 500+ bytes ($GUARD_SIZE bytes)"
  else
    fail "sw-guard override is only $GUARD_SIZE bytes (expected 500+ for a real skill file)"
  fi
else
  fail "sw-guard override missing (cannot check size)"
fi

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_SIZE=$(wc -c < "$BUILD_OVERRIDE")
  if [ "$BUILD_SIZE" -ge 500 ]; then
    pass "sw-build override is 500+ bytes ($BUILD_SIZE bytes)"
  else
    fail "sw-build override is only $BUILD_SIZE bytes (expected 500+ for a real skill file)"
  fi
else
  fail "sw-build override missing (cannot check size)"
fi

# ─── Body content substantiality ─────────────────────────────────────

if [ -f "$GUARD_OVERRIDE" ]; then
  GUARD_BODY_SIZE=$(extract_body "$GUARD_OVERRIDE" | wc -c || echo "0")
  GUARD_FM_SIZE=$(extract_frontmatter "$GUARD_OVERRIDE" | wc -c || echo "0")
  if [ "$GUARD_BODY_SIZE" -gt "$GUARD_FM_SIZE" ]; then
    pass "sw-guard body ($GUARD_BODY_SIZE bytes) is larger than frontmatter ($GUARD_FM_SIZE bytes)"
  else
    fail "sw-guard body ($GUARD_BODY_SIZE bytes) is NOT larger than frontmatter ($GUARD_FM_SIZE bytes) -- content may be missing"
  fi
fi

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_BODY_SIZE=$(extract_body "$BUILD_OVERRIDE" | wc -c || echo "0")
  BUILD_FM_SIZE=$(extract_frontmatter "$BUILD_OVERRIDE" | wc -c || echo "0")
  if [ "$BUILD_BODY_SIZE" -gt "$BUILD_FM_SIZE" ]; then
    pass "sw-build body ($BUILD_BODY_SIZE bytes) is larger than frontmatter ($BUILD_FM_SIZE bytes)"
  else
    fail "sw-build body ($BUILD_BODY_SIZE bytes) is NOT larger than frontmatter ($BUILD_FM_SIZE bytes) -- content may be missing"
  fi
fi

# ─── The two overrides must not be copies of each other ──────────────

if [ -f "$GUARD_OVERRIDE" ] && [ -f "$BUILD_OVERRIDE" ]; then
  if diff -q "$GUARD_OVERRIDE" "$BUILD_OVERRIDE" &>/dev/null; then
    fail "sw-guard and sw-build overrides are identical (each should be distinct)"
  else
    pass "sw-guard and sw-build overrides are distinct files"
  fi
fi

# ─── Neither override should be a copy of the wrong core file ────────

if [ -f "$GUARD_OVERRIDE" ]; then
  if diff -q "$GUARD_OVERRIDE" "$BUILD_CORE" &>/dev/null; then
    fail "sw-guard override is identical to core sw-build (wrong file copied)"
  else
    pass "sw-guard override is NOT a copy of core sw-build"
  fi
fi

if [ -f "$BUILD_OVERRIDE" ]; then
  if diff -q "$BUILD_OVERRIDE" "$GUARD_CORE" &>/dev/null; then
    fail "sw-build override is identical to core sw-guard (wrong file copied)"
  else
    pass "sw-build override is NOT a copy of core sw-guard"
  fi
fi

# ─── Line count sanity (real skill files have many lines) ─────────────

if [ -f "$GUARD_OVERRIDE" ]; then
  GUARD_LINES=$(wc -l < "$GUARD_OVERRIDE")
  if [ "$GUARD_LINES" -ge 20 ]; then
    pass "sw-guard override has $GUARD_LINES lines (non-trivial)"
  else
    fail "sw-guard override has only $GUARD_LINES lines (suspiciously short for a skill file)"
  fi
fi

if [ -f "$BUILD_OVERRIDE" ]; then
  BUILD_LINES=$(wc -l < "$BUILD_OVERRIDE")
  if [ "$BUILD_LINES" -ge 40 ]; then
    pass "sw-build override has $BUILD_LINES lines (non-trivial)"
  else
    fail "sw-build override has only $BUILD_LINES lines (suspiciously short -- core has 181 lines)"
  fi
fi

# ─── Summary ────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
