#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Tests for sw-sync documentation updates (AC8)
#
# Validates that DESIGN.md, CLAUDE.md, and AGENTS.md are updated to include
# sw-sync in skill tables, directory structures, and counts.
#
# Boundary classification: Internal (core docs validated via file reads
# and pattern matching, no mocks).
#
# Dependencies: bash, grep
# Usage: bash tests/test-sw-sync-docs.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DESIGN_FILE="$ROOT_DIR/DESIGN.md"
CLAUDE_ADAPTER="$ROOT_DIR/adapters/claude-code/CLAUDE.md"

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

# ═══════════════════════════════════════════════════════════════════════
# Pre-flight: required files must exist
# ═══════════════════════════════════════════════════════════════════════

echo "=== AC8: sw-sync documentation updates ==="
echo ""

if [ ! -f "$DESIGN_FILE" ]; then
  fail "DESIGN.md exists at repo root"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (DESIGN.md missing, cannot continue)"
  exit 1
fi

if [ ! -f "$CLAUDE_ADAPTER" ]; then
  fail "adapters/claude-code/CLAUDE.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (CLAUDE.md missing, cannot continue)"
  exit 1
fi

DESIGN_CONTENT=$(cat "$DESIGN_FILE")
CLAUDE_CONTENT=$(cat "$CLAUDE_ADAPTER")

# ═══════════════════════════════════════════════════════════════════════
# AC8.1: DESIGN.md skill table includes sw-sync
# ═══════════════════════════════════════════════════════════════════════

echo "--- DESIGN.md skill table ---"

# Extract the user-facing skills table (between "### User-Facing" and next heading)
DESIGN_UF_TABLE=$(echo "$DESIGN_CONTENT" | sed -n '/^### User-Facing/,/^### /p')

# sw-sync must appear in the user-facing skills table
if echo "$DESIGN_UF_TABLE" | grep -q '| `sw-sync`'; then
  pass "DESIGN.md user-facing skill table contains sw-sync row"
else
  fail "DESIGN.md user-facing skill table contains sw-sync row"
fi

# The row must have a purpose column (not just the skill name)
# Match: | `sw-sync` | <some non-empty text> |
if echo "$DESIGN_UF_TABLE" | grep -qE '\| `sw-sync` \| .+ \|'; then
  pass "DESIGN.md sw-sync row has purpose text"
else
  fail "DESIGN.md sw-sync row has purpose text"
fi

# The row must have a key innovation column (three pipe-delimited columns)
# Match: | `sw-sync` | <purpose> | <innovation> |
if echo "$DESIGN_UF_TABLE" | grep -qE '\| `sw-sync` \| .+ \| .+ \|'; then
  pass "DESIGN.md sw-sync row has key innovation text"
else
  fail "DESIGN.md sw-sync row has key innovation text"
fi

# sw-sync must NOT appear in the internal gate skills table (it's user-facing)
DESIGN_GATE_TABLE=$(echo "$DESIGN_CONTENT" | sed -n '/^### Internal Gate Skills/,/^## /p')
if echo "$DESIGN_GATE_TABLE" | grep -q 'sw-sync'; then
  fail "sw-sync must NOT appear in internal gate skills table"
else
  pass "sw-sync does not appear in internal gate skills table"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC8.2: DESIGN.md directory structure includes sw-sync/
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "--- DESIGN.md directory structure ---"

# Extract directory structure block (between "## Directory Structure" and next ##)
DESIGN_DIR_SECTION=$(echo "$DESIGN_CONTENT" | sed -n '/^## Directory Structure/,/^## /p')

# sw-sync/ must appear as a directory entry
if echo "$DESIGN_DIR_SECTION" | grep -q 'sw-sync/'; then
  pass "DESIGN.md directory structure lists sw-sync/"
else
  fail "DESIGN.md directory structure lists sw-sync/"
fi

# sw-sync/ must appear in the user-facing section (before gate- entries)
# Verify ordering: sw-sync should appear among user-facing skills, before gate-build
SYNC_LINE=$(echo "$DESIGN_DIR_SECTION" | grep -n 'sw-sync/' | head -1 | cut -d: -f1)
GATE_LINE=$(echo "$DESIGN_DIR_SECTION" | grep -n 'gate-build/' | head -1 | cut -d: -f1)
if [ -n "$SYNC_LINE" ] && [ -n "$GATE_LINE" ] && [ "$SYNC_LINE" -lt "$GATE_LINE" ]; then
  pass "sw-sync/ appears before gate skills in directory structure"
else
  if [ -z "$SYNC_LINE" ]; then
    fail "sw-sync/ appears before gate skills in directory structure (sw-sync/ not found)"
  else
    fail "sw-sync/ appears before gate skills in directory structure (wrong position)"
  fi
fi

# sw-sync/ must be labeled as user-facing (matching the pattern of other user-facing entries)
if echo "$DESIGN_DIR_SECTION" | grep 'sw-sync/' | grep -qi 'user-facing\|User-facing'; then
  pass "sw-sync/ directory entry is labeled as user-facing"
else
  # Not all entries have the label inline; check if it's in the user-facing block
  # The comment "# User-facing" appears on the first entry only; position check suffices
  # If sw-sync is after the user-facing comment and before gate entries, it's correctly placed
  if [ -n "$SYNC_LINE" ] && [ -n "$GATE_LINE" ] && [ "$SYNC_LINE" -lt "$GATE_LINE" ]; then
    pass "sw-sync/ directory entry is in user-facing section (by position)"
  else
    fail "sw-sync/ directory entry is labeled as user-facing"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# AC8.3: DESIGN.md skill counts are updated
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "--- DESIGN.md skill counts ---"

# Total skills heading must say 21
SKILLS_HEADING=$(echo "$DESIGN_CONTENT" | grep '^## Skills')
if echo "$SKILLS_HEADING" | grep -q 'Skills (21)'; then
  pass "DESIGN.md heading says 'Skills (21)'"
else
  ACTUAL_COUNT=$(echo "$SKILLS_HEADING" | grep -oE '[0-9]+' || echo "none")
  fail "DESIGN.md heading says 'Skills (21)' (got count: $ACTUAL_COUNT)"
fi

# User-facing heading must say 15
UF_HEADING=$(echo "$DESIGN_CONTENT" | grep '^### User-Facing')
if echo "$UF_HEADING" | grep -q 'User-Facing (15)'; then
  pass "DESIGN.md heading says 'User-Facing (15)'"
else
  ACTUAL_UF=$(echo "$UF_HEADING" | grep -oE '[0-9]+' || echo "none")
  fail "DESIGN.md heading says 'User-Facing (15)' (got count: $ACTUAL_UF)"
fi

# Internal gate skills count should remain 6 (sw-sync is NOT a gate)
GATE_HEADING=$(echo "$DESIGN_CONTENT" | grep '^### Internal Gate Skills')
if echo "$GATE_HEADING" | grep -q 'Internal Gate Skills (6)'; then
  pass "DESIGN.md gate skills count remains 6"
else
  ACTUAL_GATE=$(echo "$GATE_HEADING" | grep -oE '[0-9]+' || echo "none")
  fail "DESIGN.md gate skills count remains 6 (got: $ACTUAL_GATE)"
fi

# The directory structure comment should also say 21 skills
DIR_SKILLS_LINE=$(echo "$DESIGN_DIR_SECTION" | grep 'SKILL.md files')
if echo "$DIR_SKILLS_LINE" | grep -q '21 skills'; then
  pass "DESIGN.md directory structure comment says '21 skills'"
else
  ACTUAL_DIR_COUNT=$(echo "$DIR_SKILLS_LINE" | grep -oE '[0-9]+ skills' || echo "none")
  fail "DESIGN.md directory structure comment says '21 skills' (got: $ACTUAL_DIR_COUNT)"
fi

# Cross-check: count of actual user-facing rows in the table matches 15
UF_ROW_COUNT=$(echo "$DESIGN_UF_TABLE" | grep -cE '^\| `sw-' || true)
assert_eq "$UF_ROW_COUNT" "15" "DESIGN.md user-facing table has exactly 15 skill rows"

# ═══════════════════════════════════════════════════════════════════════
# AC8.4: CLAUDE.md skill table includes sw-sync
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "--- CLAUDE.md skill table ---"

# sw-sync must appear in the CLAUDE.md skill table
if echo "$CLAUDE_CONTENT" | grep -q '| `sw-sync`'; then
  pass "CLAUDE.md skill table contains sw-sync row"
else
  fail "CLAUDE.md skill table contains sw-sync row"
fi

# The row must have a purpose description (not just the skill name)
if echo "$CLAUDE_CONTENT" | grep -qE '\| `sw-sync` \| .+ \|'; then
  pass "CLAUDE.md sw-sync row has purpose description"
else
  fail "CLAUDE.md sw-sync row has purpose description"
fi

# Purpose must mention sync/synchronize/clean -- not be a copy-paste of another skill
if echo "$CLAUDE_CONTENT" | grep '`sw-sync`' | grep -qiE 'sync|synchroniz|clean|stale|prune|branch'; then
  pass "CLAUDE.md sw-sync purpose mentions sync-related concept"
else
  fail "CLAUDE.md sw-sync purpose mentions sync-related concept"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC8.5: CLAUDE.md skill count (row count consistency)
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "--- CLAUDE.md skill count consistency ---"

# Count total skill rows in CLAUDE.md table
# All skills in CLAUDE.md follow the pattern: | `sw-*` |
CLAUDE_SKILL_ROWS=$(echo "$CLAUDE_CONTENT" | grep -cE '^\| `sw-' || true)

# Should be 15 user-facing skills (14 existing + sw-sync)
assert_eq "$CLAUDE_SKILL_ROWS" "15" "CLAUDE.md has exactly 15 skill rows"

# ═══════════════════════════════════════════════════════════════════════
# AC8.6: AGENTS.md includes sw-sync
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "--- AGENTS.md ---"

AGENTS_FILE="$ROOT_DIR/AGENTS.md"
if [ ! -f "$AGENTS_FILE" ]; then
  fail "AGENTS.md exists"
else
  AGENTS_CONTENT=$(cat "$AGENTS_FILE")

  if echo "$AGENTS_CONTENT" | grep -q '| `sw-sync`'; then
    pass "AGENTS.md skill table includes sw-sync row"
  else
    fail "AGENTS.md skill table includes sw-sync row"
  fi

  if echo "$AGENTS_CONTENT" | grep '`sw-sync`' | grep -qiE 'sync|clean|stale|prune|branch|housekeeping'; then
    pass "AGENTS.md sw-sync purpose mentions sync-related concept"
  else
    fail "AGENTS.md sw-sync purpose mentions sync-related concept"
  fi

  AGENTS_SYNC_ROWS=$(echo "$AGENTS_CONTENT" | grep -c '| `sw-sync`' || true)
  if [ "$AGENTS_SYNC_ROWS" -eq 1 ]; then
    pass "exactly one sw-sync row in AGENTS.md"
  else
    fail "exactly one sw-sync row in AGENTS.md (found $AGENTS_SYNC_ROWS)"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# Cross-cutting: consistency between DESIGN.md, CLAUDE.md, and AGENTS.md
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "--- Cross-document consistency ---"

# sw-sync must appear in ALL THREE files
DESIGN_HAS=$(echo "$DESIGN_CONTENT" | grep -c '`sw-sync`' || true)
CLAUDE_HAS=$(echo "$CLAUDE_CONTENT" | grep -c '`sw-sync`' || true)

if [ "$DESIGN_HAS" -ge 1 ] && [ "$CLAUDE_HAS" -ge 1 ]; then
  pass "sw-sync referenced in both DESIGN.md and CLAUDE.md"
else
  fail "sw-sync referenced in both DESIGN.md and CLAUDE.md (DESIGN=$DESIGN_HAS, CLAUDE=$CLAUDE_HAS)"
fi

# Verify no duplicate sw-sync rows in DESIGN.md user-facing table
DESIGN_SYNC_ROWS=$(echo "$DESIGN_UF_TABLE" | grep -c '| `sw-sync`' || true)
if [ "$DESIGN_SYNC_ROWS" -eq 1 ]; then
  pass "exactly one sw-sync row in DESIGN.md user-facing table"
else
  fail "exactly one sw-sync row in DESIGN.md user-facing table (found $DESIGN_SYNC_ROWS)"
fi

# Verify no duplicate sw-sync rows in CLAUDE.md
CLAUDE_SYNC_ROWS=$(echo "$CLAUDE_CONTENT" | grep -c '| `sw-sync`' || true)
if [ "$CLAUDE_SYNC_ROWS" -eq 1 ]; then
  pass "exactly one sw-sync row in CLAUDE.md"
else
  fail "exactly one sw-sync row in CLAUDE.md (found $CLAUDE_SYNC_ROWS)"
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
