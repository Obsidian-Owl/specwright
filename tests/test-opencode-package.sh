#!/usr/bin/env bash
#
# Tests for AC-1: Opencode package.json is publish-ready
#
# Validates adapters/opencode/package.json against the spec:
# - File existence and valid JSON
# - name is exactly "@obsidian-owl/opencode-specwright" (scoped)
# - publishConfig.access is "public"
# - files array contains exactly the 6 required entries
# - version matches adapters/claude-code/.claude-plugin/plugin.json
# - main points to plugin.ts
# - description is a non-empty string
# - keywords is a non-empty array of strings
# - README.md exists and is non-empty
#
# Dependencies: bash, jq
# Usage: ./tests/test-opencode-package.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PKG="$ROOT_DIR/adapters/opencode/package.json"
PLUGIN_JSON="$ROOT_DIR/adapters/claude-code/.claude-plugin/plugin.json"
README="$ROOT_DIR/adapters/opencode/README.md"

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

echo "=== AC-1: Opencode package.json is publish-ready ==="
echo ""

# Check jq is available
if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

# Verify the source of truth exists so we can do dynamic version checks
if [ ! -f "$PLUGIN_JSON" ]; then
  echo "ABORT: plugin.json not found at $PLUGIN_JSON (needed for version comparison)"
  exit 1
fi

# ─── 1. File existence ──────────────────────────────────────────────

echo "--- File existence ---"

if [ -f "$PKG" ]; then
  pass "package.json exists"
else
  fail "package.json does not exist at $PKG"
  echo ""
  echo "RESULT: 0 passed, 1 failed (cannot continue without file)"
  exit 1
fi

# ─── 2. Valid JSON ──────────────────────────────────────────────────

echo "--- Valid JSON ---"

if jq empty "$PKG" 2>/dev/null; then
  pass "package.json is valid JSON"
else
  fail "package.json is not valid JSON"
  echo ""
  echo "RESULT: 1 passed, 1 failed (cannot continue with invalid JSON)"
  exit 1
fi

# Verify it's a JSON object, not an array or scalar
PKG_TYPE=$(jq -r 'type' "$PKG")
assert_eq "$PKG_TYPE" "object" "package.json root is a JSON object"

# ─── 3. Name field (scoped) ─────────────────────────────────────────

echo "--- Name ---"

NAME=$(jq -r '.name' "$PKG")
assert_eq "$NAME" "@obsidian-owl/opencode-specwright" "name is '@obsidian-owl/opencode-specwright'"

# Guard against old unscoped name
NAME_NOT_UNSCOPED=$(jq -r '.name != "opencode-specwright"' "$PKG")
assert_eq "$NAME_NOT_UNSCOPED" "true" "name is NOT the old unscoped 'opencode-specwright'"

# Guard against name being the claude-code plugin name
NAME_NOT_SPECWRIGHT=$(jq -r '.name != "specwright"' "$PKG")
assert_eq "$NAME_NOT_SPECWRIGHT" "true" "name is NOT 'specwright' (must be opencode-specific)"

# Guard against wrong scope
NAME_NOT_WRONG_SCOPE=$(jq -r '.name != "@obsidian-owl/specwright"' "$PKG")
assert_eq "$NAME_NOT_WRONG_SCOPE" "true" "name is NOT '@obsidian-owl/specwright' (must include 'opencode' prefix)"

# Guard against null
NAME_TYPE=$(jq -r '.name | type' "$PKG")
assert_eq "$NAME_TYPE" "string" "name is a string (not null or number)"

# Verify the scope prefix is correct
NAME_HAS_SCOPE=$(jq -r '.name | startswith("@obsidian-owl/")' "$PKG")
assert_eq "$NAME_HAS_SCOPE" "true" "name starts with '@obsidian-owl/' scope"

# ─── 4. publishConfig ───────────────────────────────────────────────

echo "--- publishConfig ---"

# Field must exist
HAS_PUBLISH_CONFIG=$(jq 'has("publishConfig")' "$PKG")
assert_eq "$HAS_PUBLISH_CONFIG" "true" "publishConfig field exists"

# publishConfig must be an object (not a string, null, or array)
PUBLISH_CONFIG_TYPE=$(jq -r '.publishConfig | type' "$PKG")
assert_eq "$PUBLISH_CONFIG_TYPE" "object" "publishConfig is an object (not string/null/array)"

# publishConfig.access must exist
HAS_ACCESS=$(jq '.publishConfig | has("access")' "$PKG")
assert_eq "$HAS_ACCESS" "true" "publishConfig.access field exists"

# publishConfig.access must be exactly "public"
ACCESS_VALUE=$(jq -r '.publishConfig.access' "$PKG")
assert_eq "$ACCESS_VALUE" "public" "publishConfig.access is 'public'"

# Guard against "restricted" (npm default for scoped packages)
ACCESS_NOT_RESTRICTED=$(jq -r '.publishConfig.access != "restricted"' "$PKG")
assert_eq "$ACCESS_NOT_RESTRICTED" "true" "publishConfig.access is NOT 'restricted'"

# publishConfig.access must be a string
ACCESS_TYPE=$(jq -r '.publishConfig.access | type' "$PKG")
assert_eq "$ACCESS_TYPE" "string" "publishConfig.access is a string (not boolean or null)"

# ─── 5. files array ─────────────────────────────────────────────────

echo "--- files ---"

# files field must exist
HAS_FILES=$(jq 'has("files")' "$PKG")
assert_eq "$HAS_FILES" "true" "files field exists"

# files must be an array
FILES_TYPE=$(jq -r '.files | type' "$PKG")
assert_eq "$FILES_TYPE" "array" "files is an array (not string/object/null)"

# files must have exactly 6 entries
FILES_LEN=$(jq '.files | length' "$PKG")
assert_eq "$FILES_LEN" "6" "files array has exactly 6 entries"

# Each required entry must be present
REQUIRED_FILES=("skills/" "protocols/" "agents/" "commands/" "plugin.ts" "README.md")
for entry in "${REQUIRED_FILES[@]}"; do
  ENTRY_PRESENT=$(jq --arg e "$entry" '[(.files // [])[] | select(. == $e)] | length' "$PKG")
  assert_eq "$ENTRY_PRESENT" "1" "files array contains '$entry'"
done

# Guard: no duplicates in files array
FILES_UNIQUE_LEN=$(jq '(.files // []) | unique | length' "$PKG")
assert_eq "$FILES_UNIQUE_LEN" "$FILES_LEN" "files array has no duplicates"

# Guard: all entries are strings (not numbers, objects, nulls)
FILES_ALL_STRINGS=$(jq '[(.files // [])[] | type] | all(. == "string")' "$PKG")
assert_eq "$FILES_ALL_STRINGS" "true" "all files entries are strings"

# Guard: no empty strings in files array
FILES_EMPTY_COUNT=$(jq '[(.files // [])[] | select(. == "")] | length' "$PKG")
assert_eq "$FILES_EMPTY_COUNT" "0" "no files entry is an empty string"

# Guard: no extra entries beyond the required 6
# (Already covered by exact count of 6 + all 6 present, but let's be explicit)
FILES_SORTED=$(jq -c '[(.files // [])[] | .] | sort' "$PKG")
EXPECTED_SORTED='["README.md","agents/","commands/","plugin.ts","protocols/","skills/"]'
assert_eq "$FILES_SORTED" "$EXPECTED_SORTED" "files array contains exactly the 6 required entries (sorted comparison)"

# Guard against common wrong entries -- trailing-slash variants matter
FILES_HAS_SKILLS_NO_SLASH=$(jq '[(.files // [])[] | select(. == "skills")] | length' "$PKG")
assert_eq "$FILES_HAS_SKILLS_NO_SLASH" "0" "files does NOT contain 'skills' without trailing slash (must be 'skills/')"

FILES_HAS_PROTOCOLS_NO_SLASH=$(jq '[(.files // [])[] | select(. == "protocols")] | length' "$PKG")
assert_eq "$FILES_HAS_PROTOCOLS_NO_SLASH" "0" "files does NOT contain 'protocols' without trailing slash (must be 'protocols/')"

FILES_HAS_AGENTS_NO_SLASH=$(jq '[(.files // [])[] | select(. == "agents")] | length' "$PKG")
assert_eq "$FILES_HAS_AGENTS_NO_SLASH" "0" "files does NOT contain 'agents' without trailing slash (must be 'agents/')"

FILES_HAS_COMMANDS_NO_SLASH=$(jq '[(.files // [])[] | select(. == "commands")] | length' "$PKG")
assert_eq "$FILES_HAS_COMMANDS_NO_SLASH" "0" "files does NOT contain 'commands' without trailing slash (must be 'commands/')"

# ─── 6. Version field ──────────────────────────────────────────────

echo "--- Version ---"

# Read the expected version dynamically from the Claude Code plugin.json
EXPECTED_VERSION=$(jq -r '.version' "$PLUGIN_JSON")

# Sanity check: the version we read should look like a semver
if [[ ! "$EXPECTED_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]]; then
  echo "ABORT: plugin.json version '$EXPECTED_VERSION' does not look like semver"
  exit 1
fi

ACTUAL_VERSION=$(jq -r '.version' "$PKG")
assert_eq "$ACTUAL_VERSION" "$EXPECTED_VERSION" "version matches plugin.json ($EXPECTED_VERSION)"

# Verify version is a string, not a number
VERSION_TYPE=$(jq -r '.version | type' "$PKG")
assert_eq "$VERSION_TYPE" "string" "version is a string (not number or null)"

# Verify version is not empty
VERSION_LEN=$(jq -r '.version | length' "$PKG")
if [ "$VERSION_LEN" -gt 0 ]; then
  pass "version is non-empty"
else
  fail "version is empty string"
fi

# ─── 7. Main field ─────────────────────────────────────────────────

echo "--- Main ---"

MAIN=$(jq -r '.main' "$PKG")
assert_eq "$MAIN" "plugin.ts" "main points to 'plugin.ts'"

# Guard against common wrong values
MAIN_NOT_INDEX=$(jq -r '.main != "index.js"' "$PKG")
assert_eq "$MAIN_NOT_INDEX" "true" "main is NOT 'index.js'"

MAIN_NOT_INDEX_TS=$(jq -r '.main != "index.ts"' "$PKG")
assert_eq "$MAIN_NOT_INDEX_TS" "true" "main is NOT 'index.ts'"

# Verify main is a string
MAIN_TYPE=$(jq -r '.main | type' "$PKG")
assert_eq "$MAIN_TYPE" "string" "main is a string (not null)"

# ─── 8. Description field ──────────────────────────────────────────

echo "--- Description ---"

DESC_TYPE=$(jq -r '.description | type' "$PKG")
assert_eq "$DESC_TYPE" "string" "description is a string"

DESC_LEN=$(jq -r '.description | length' "$PKG")
if [ "$DESC_LEN" -gt 0 ]; then
  pass "description is non-empty"
else
  fail "description is empty string (length=$DESC_LEN)"
fi

# Description should be meaningful -- at least 10 chars (not just "x" or "test")
if [ "$DESC_LEN" -ge 10 ]; then
  pass "description is at least 10 characters (meaningful)"
else
  fail "description is suspiciously short ($DESC_LEN chars)"
fi

# Guard against description being null
DESC_NULL=$(jq '.description == null' "$PKG")
assert_eq "$DESC_NULL" "false" "description is not null"

# ─── 9. Keywords field ─────────────────────────────────────────────

echo "--- Keywords ---"

KW_TYPE=$(jq -r '.keywords | type' "$PKG")
assert_eq "$KW_TYPE" "array" "keywords is an array"

KW_LEN=$(jq '.keywords | length' "$PKG")
if [ "$KW_LEN" -gt 0 ]; then
  pass "keywords array is non-empty (has $KW_LEN entries)"
else
  fail "keywords array is empty"
fi

# Verify all keyword entries are strings (not numbers, objects, or nulls)
KW_ALL_STRINGS=$(jq '[.keywords[] | type] | all(. == "string")' "$PKG")
assert_eq "$KW_ALL_STRINGS" "true" "all keyword entries are strings"

# Verify no keyword is an empty string
KW_EMPTY_COUNT=$(jq '[.keywords[] | select(. == "")] | length' "$PKG")
assert_eq "$KW_EMPTY_COUNT" "0" "no keyword is an empty string"

# Guard against keywords being null
KW_NULL=$(jq '.keywords == null' "$PKG")
assert_eq "$KW_NULL" "false" "keywords is not null"

# ─── 10. README.md ─────────────────────────────────────────────────

echo "--- README.md ---"

if [ -f "$README" ]; then
  pass "README.md exists"
else
  fail "README.md does not exist at $README"
  # Don't exit -- report all failures
fi

if [ -f "$README" ]; then
  README_SIZE=$(wc -c < "$README")
  if [ "$README_SIZE" -gt 0 ]; then
    pass "README.md is non-empty ($README_SIZE bytes)"
  else
    fail "README.md exists but is empty (0 bytes)"
  fi

  # Must have some meaningful content, not just whitespace
  README_CONTENT=$(tr -d '[:space:]' < "$README" | wc -c)
  if [ "$README_CONTENT" -gt 10 ]; then
    pass "README.md has meaningful content (>10 non-whitespace chars)"
  else
    fail "README.md has only whitespace or trivial content ($README_CONTENT non-whitespace chars)"
  fi
fi

# ─── 11. Cross-checks (catch lazy implementations) ──────────────────

echo "--- Cross-checks ---"

# package.json should NOT be identical to the Claude Code plugin.json
if diff -q "$PKG" "$PLUGIN_JSON" &>/dev/null; then
  fail "package.json is identical to plugin.json (should be a distinct package)"
else
  pass "package.json is not a copy of plugin.json"
fi

# package.json should have the required fields present as top-level keys
for field in name version main description keywords publishConfig files; do
  HAS_FIELD=$(jq "has(\"$field\")" "$PKG")
  assert_eq "$HAS_FIELD" "true" "package.json has '$field' field"
done

# Verify the file doesn't have a "skills" field (that's plugin.json structure, not npm package.json)
HAS_SKILLS=$(jq 'has("skills")' "$PKG")
assert_eq "$HAS_SKILLS" "false" "package.json does NOT have a 'skills' field (that's plugin.json, not npm)"

# ─── Summary ────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
