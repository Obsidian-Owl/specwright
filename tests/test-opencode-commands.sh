#!/usr/bin/env bash
#
# Tests for AC-4: Command files exist for all 14 user-facing skills
#
# Validates adapters/opencode/commands/ against the spec:
# - Directory existence
# - Exactly 14 .md files, one per user-facing skill
# - Each expected file exists by name
# - Each file has valid YAML frontmatter with description field
# - Description values are non-empty and distinct
# - Body (after frontmatter) contains $ARGUMENTS
# - No gate skill command files exist
# - No unexpected .md files beyond the 14 expected
#
# Dependencies: bash
# Usage: ./tests/test-opencode-commands.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CMD_DIR="$ROOT_DIR/adapters/opencode/commands"

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

# ─── Pre-flight ──────────────────────────────────────────────────────

echo "=== AC-4: Opencode command files ==="
echo ""

# The 14 user-facing skills (commands expected)
EXPECTED_COMMANDS=(
  sw-init
  sw-design
  sw-plan
  sw-build
  sw-verify
  sw-ship
  sw-status
  sw-guard
  sw-learn
  sw-research
  sw-debug
  sw-pivot
  sw-doctor
  sw-audit
)

# The 5 gate skills (commands must NOT exist)
GATE_SKILLS=(
  gate-build
  gate-tests
  gate-security
  gate-wiring
  gate-spec
)

# ─── 1. Directory existence ──────────────────────────────────────────

echo "--- Directory existence ---"

if [ -d "$CMD_DIR" ]; then
  pass "commands/ directory exists"
else
  fail "commands/ directory does not exist at $CMD_DIR"
  echo ""
  echo "RESULT: 0 passed, 1 failed (cannot continue without directory)"
  exit 1
fi

# ─── 2. Exact file count ─────────────────────────────────────────────

echo "--- File count ---"

MD_COUNT=$(find "$CMD_DIR" -maxdepth 1 -name '*.md' -type f | wc -l)
assert_eq "$MD_COUNT" "14" "exactly 14 .md files in commands/"

# ─── 3. Each expected command file exists ─────────────────────────────

echo "--- Expected files ---"

for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  if [ -f "$FILE" ]; then
    pass "${skill}.md exists"
  else
    fail "${skill}.md does not exist"
  fi
done

# ─── 4. No gate skill command files ──────────────────────────────────

echo "--- No gate skill commands ---"

for gate in "${GATE_SKILLS[@]}"; do
  FILE="$CMD_DIR/${gate}.md"
  if [ -f "$FILE" ]; then
    fail "${gate}.md exists but should NOT (gate skills must not have commands)"
  else
    pass "${gate}.md correctly absent"
  fi
done

# ─── 5. No unexpected files ──────────────────────────────────────────

echo "--- No unexpected files ---"

# Build a list of expected filenames for comparison
UNEXPECTED=0
while IFS= read -r filepath; do
  filename=$(basename "$filepath")
  FOUND_EXPECTED=false
  for skill in "${EXPECTED_COMMANDS[@]}"; do
    if [ "$filename" = "${skill}.md" ]; then
      FOUND_EXPECTED=true
      break
    fi
  done
  if [ "$FOUND_EXPECTED" = false ]; then
    fail "unexpected file: $filename"
    UNEXPECTED=$((UNEXPECTED + 1))
  fi
done < <(find "$CMD_DIR" -maxdepth 1 -name '*.md' -type f)

if [ "$UNEXPECTED" -eq 0 ]; then
  pass "no unexpected .md files in commands/"
fi

# ─── 6. YAML frontmatter structure ───────────────────────────────────

echo "--- YAML frontmatter ---"

for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  [ ! -f "$FILE" ] && continue

  # File must start with --- on line 1
  FIRST_LINE=$(head -n 1 "$FILE")
  if [ "$FIRST_LINE" = "---" ]; then
    pass "${skill}.md starts with --- (frontmatter opening)"
  else
    fail "${skill}.md does not start with --- (got: '$FIRST_LINE')"
    continue
  fi

  # Must have a closing --- after line 1
  # Find the line number of the closing ---
  CLOSING_LINE=$(tail -n +2 "$FILE" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -n "$CLOSING_LINE" ] && [ "$CLOSING_LINE" -gt 0 ]; then
    pass "${skill}.md has closing --- (frontmatter end at line $((CLOSING_LINE + 1)))"
  else
    fail "${skill}.md has no closing --- (frontmatter never closed)"
    continue
  fi

  # Extract frontmatter content (between the two --- delimiters)
  # CLOSING_LINE is relative to line 2 of the file
  FRONTMATTER=$(head -n "$((CLOSING_LINE + 1))" "$FILE" | tail -n +"2" | head -n "$((CLOSING_LINE - 1))")

  # Frontmatter must contain description field
  if echo "$FRONTMATTER" | grep -qE '^description:'; then
    pass "${skill}.md frontmatter has description field"
  else
    fail "${skill}.md frontmatter missing description field"
  fi
done

# ─── 7. Description values are non-empty ─────────────────────────────

echo "--- Non-empty descriptions ---"

DESCRIPTIONS=()
for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  [ ! -f "$FILE" ] && continue

  # Extract the description value from frontmatter
  CLOSING_LINE=$(tail -n +2 "$FILE" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  [ -z "$CLOSING_LINE" ] && continue

  FRONTMATTER=$(head -n "$((CLOSING_LINE + 1))" "$FILE" | tail -n +"2" | head -n "$((CLOSING_LINE - 1))")

  # Get the description value (everything after "description: " or "description: \"...\"")
  DESC_VALUE=$(echo "$FRONTMATTER" | grep -E '^description:' | sed 's/^description:\s*//' | sed 's/^["'"'"']//' | sed 's/["'"'"']$//' | xargs)

  if [ -n "$DESC_VALUE" ] && [ "$DESC_VALUE" != "null" ] && [ "$DESC_VALUE" != '""' ]; then
    pass "${skill}.md has non-empty description: '$DESC_VALUE'"
    DESCRIPTIONS+=("$DESC_VALUE")
  else
    fail "${skill}.md has empty or null description"
  fi

  # Description should be meaningful (at least 5 chars, not just "x" or "test")
  DESC_LEN=${#DESC_VALUE}
  if [ "$DESC_LEN" -ge 5 ]; then
    pass "${skill}.md description is at least 5 chars (meaningful)"
  else
    fail "${skill}.md description is suspiciously short ($DESC_LEN chars: '$DESC_VALUE')"
  fi
done

# ─── 8. Descriptions are distinct ────────────────────────────────────

echo "--- Distinct descriptions ---"

# A lazy implementation might use the same description for all commands
if [ ${#DESCRIPTIONS[@]} -ge 2 ]; then
  UNIQUE_DESCS=$(printf '%s\n' "${DESCRIPTIONS[@]}" | sort -u | wc -l)
  TOTAL_DESCS=${#DESCRIPTIONS[@]}
  assert_eq "$UNIQUE_DESCS" "$TOTAL_DESCS" "all $TOTAL_DESCS descriptions are unique (no duplicates)"
fi

# ─── 9. Body contains $ARGUMENTS ─────────────────────────────────────

echo "--- \$ARGUMENTS in body ---"

for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  [ ! -f "$FILE" ] && continue

  # Find the closing frontmatter delimiter
  CLOSING_LINE=$(tail -n +2 "$FILE" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  [ -z "$CLOSING_LINE" ] && continue

  # Extract body (everything after the closing ---)
  # CLOSING_LINE is relative to line 2, so actual line is CLOSING_LINE + 1
  BODY=$(tail -n +"$((CLOSING_LINE + 2))" "$FILE")

  # Body must contain $ARGUMENTS (literal dollar sign + ARGUMENTS)
  if echo "$BODY" | grep -qF '$ARGUMENTS'; then
    pass "${skill}.md body contains \$ARGUMENTS"
  else
    fail "${skill}.md body does not contain \$ARGUMENTS"
  fi

  # $ARGUMENTS must be in the BODY, not in the frontmatter
  # (catch lazy impl that puts it in frontmatter instead of body)
  FRONTMATTER=$(head -n "$((CLOSING_LINE + 1))" "$FILE" | tail -n +"2" | head -n "$((CLOSING_LINE - 1))")
  if echo "$FRONTMATTER" | grep -qF '$ARGUMENTS'; then
    fail "${skill}.md has \$ARGUMENTS in frontmatter (should be in body only)"
  else
    pass "${skill}.md \$ARGUMENTS is in body, not frontmatter"
  fi
done

# ─── 10. Body is non-empty ───────────────────────────────────────────

echo "--- Non-empty body ---"

for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  [ ! -f "$FILE" ] && continue

  CLOSING_LINE=$(tail -n +2 "$FILE" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  [ -z "$CLOSING_LINE" ] && continue

  BODY=$(tail -n +"$((CLOSING_LINE + 2))" "$FILE")
  BODY_TRIMMED=$(echo "$BODY" | tr -d '[:space:]')

  if [ ${#BODY_TRIMMED} -gt 10 ]; then
    pass "${skill}.md has non-trivial body content (${#BODY_TRIMMED} non-ws chars)"
  else
    fail "${skill}.md body is empty or trivial (${#BODY_TRIMMED} non-ws chars)"
  fi
done

# ─── 11. Filename matches skill name convention ──────────────────────

echo "--- Filename convention ---"

# All files must be lowercase with hyphens (matching skill names exactly)
while IFS= read -r filepath; do
  filename=$(basename "$filepath" .md)
  if echo "$filename" | grep -qE '^[a-z]+-[a-z]+$'; then
    pass "$filename follows lowercase-hyphen naming"
  else
    fail "$filename does not follow lowercase-hyphen naming convention"
  fi
done < <(find "$CMD_DIR" -maxdepth 1 -name '*.md' -type f)

# ─── 12. Cross-checks (catch lazy implementations) ──────────────────

echo "--- Cross-checks ---"

# Files should not be identical to each other (catch copy-paste of one file)
if [ ${#EXPECTED_COMMANDS[@]} -ge 2 ]; then
  FIRST_FILE="$CMD_DIR/${EXPECTED_COMMANDS[0]}.md"
  IDENTICAL_COUNT=0
  for skill in "${EXPECTED_COMMANDS[@]:1}"; do
    FILE="$CMD_DIR/${skill}.md"
    [ ! -f "$FILE" ] && continue
    [ ! -f "$FIRST_FILE" ] && continue
    if diff -q "$FIRST_FILE" "$FILE" &>/dev/null; then
      IDENTICAL_COUNT=$((IDENTICAL_COUNT + 1))
      fail "${EXPECTED_COMMANDS[0]}.md and ${skill}.md are identical (each should be distinct)"
    fi
  done
  if [ "$IDENTICAL_COUNT" -eq 0 ]; then
    pass "command files are not all identical copies"
  fi
fi

# Each file should reference its own skill name in the body or frontmatter
for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  [ ! -f "$FILE" ] && continue
  if grep -qF "$skill" "$FILE"; then
    pass "${skill}.md references its own skill name ($skill)"
  else
    fail "${skill}.md does not reference its own skill name ($skill)"
  fi
done

# Files should not be empty (0 bytes)
for skill in "${EXPECTED_COMMANDS[@]}"; do
  FILE="$CMD_DIR/${skill}.md"
  [ ! -f "$FILE" ] && continue
  FILESIZE=$(wc -c < "$FILE")
  if [ "$FILESIZE" -gt 0 ]; then
    pass "${skill}.md is non-empty ($FILESIZE bytes)"
  else
    fail "${skill}.md is 0 bytes"
  fi
done

# No subdirectories in commands/ (commands are flat files)
SUBDIR_COUNT=$(find "$CMD_DIR" -mindepth 1 -type d | wc -l)
assert_eq "$SUBDIR_COUNT" "0" "no subdirectories in commands/ (flat structure)"

# No non-.md files in commands/
NON_MD_COUNT=$(find "$CMD_DIR" -maxdepth 1 -type f ! -name '*.md' | wc -l)
assert_eq "$NON_MD_COUNT" "0" "no non-.md files in commands/"

# ─── Summary ────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
