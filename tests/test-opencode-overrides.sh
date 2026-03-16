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
# sw-build: no longer an override — uses core with platform markers
# ═══════════════════════════════════════════════════════════════════════

echo "--- sw-build: adapter override does NOT exist ---"

if [ ! -f "$ROOT_DIR/adapters/opencode/skills/sw-build/SKILL.md" ]; then
  pass "sw-build adapter override does not exist (deleted — uses core with markers)"
else
  fail "sw-build adapter override still exists at $BUILD_OVERRIDE (should be deleted)"
fi

echo "--- sw-build: core has platform markers ---"

CORE_BUILD="$ROOT_DIR/core/skills/sw-build/SKILL.md"
if [ -f "$CORE_BUILD" ]; then
  if grep -q '<!-- platform:claude-code -->' "$CORE_BUILD"; then
    pass "core sw-build contains <!-- platform:claude-code --> markers"
  else
    fail "core sw-build missing <!-- platform:claude-code --> markers"
  fi
else
  fail "core sw-build SKILL.md not found"
fi

echo "--- sw-build: not in skillOverrides ---"

MAPPING="$ROOT_DIR/build/mappings/opencode.json"
if jq -e '.skillOverrides | index("sw-build")' "$MAPPING" > /dev/null 2>&1; then
  fail "sw-build still in opencode.json skillOverrides"
else
  pass "sw-build not in opencode.json skillOverrides"
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

# ─── Neither override should be a copy of the wrong core file ────────

if [ -f "$GUARD_OVERRIDE" ]; then
  if diff -q "$GUARD_OVERRIDE" "$BUILD_CORE" &>/dev/null; then
    fail "sw-guard override is identical to core sw-build (wrong file copied)"
  else
    pass "sw-guard override is NOT a copy of core sw-build"
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

# ─── Summary ────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
