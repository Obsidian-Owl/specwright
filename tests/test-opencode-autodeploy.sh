#!/usr/bin/env bash
#
# Tests for AC-2, AC-3, AC-4: Opencode plugin auto-deploy feature
#
# Validates adapters/opencode/plugin.ts contains auto-deploy logic:
#   AC-2: On version mismatch, copies assets to split targets, writes .plugin-version
#   AC-3: Uses import.meta.dir for package root resolution (no hardcoded paths)
#   AC-4: Handles errors gracefully (creates dirs, skips missing sources, try/catch)
#
# These tests perform static analysis of plugin.ts source code to verify
# the auto-deploy feature is implemented with the correct structure and
# behavioral contracts.
#
# Dependencies: bash
# Usage: ./tests/test-opencode-autodeploy.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PLUGIN="$ROOT_DIR/adapters/opencode/plugin.ts"

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

assert_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$PLUGIN"; then
    pass "$label"
  else
    fail "$label (pattern not found: $pattern)"
  fi
}

assert_not_grep() {
  local pattern="$1"
  local label="$2"
  if grep -qE "$pattern" "$PLUGIN"; then
    fail "$label (pattern found but should not be: $pattern)"
  else
    pass "$label"
  fi
}

# ---- Pre-flight ----

echo "=== AC-2, AC-3, AC-4: Opencode plugin auto-deploy ==="
echo ""

if [ ! -f "$PLUGIN" ]; then
  fail "plugin.ts does not exist at $PLUGIN"
  echo ""
  echo "RESULT: 0 passed, 1 failed (cannot continue without file)"
  exit 1
fi

# =========================================================================
# AC-2: Auto-deploy copies assets to correct split targets on version mismatch
# =========================================================================

echo "--- AC-2: Deploy function exists ---"

# There must be a deploy function or clearly named deploy block.
# A lazy implementation might skip this entirely.
# Accept: deployAssets, deploy, autoDeploy, runDeploy, performDeploy, doDeploy
assert_grep '(function\s+(deploy|deployAssets|autoDeploy|runDeploy|performDeploy|doDeploy)|const\s+(deploy|deployAssets|autoDeploy|runDeploy|performDeploy|doDeploy)\s*=|(async\s+)?function\s+\w*[Dd]eploy)' \
  "deploy function or named deploy block exists"

echo "--- AC-2: .plugin-version path referenced ---"

# The plugin must reference .plugin-version for version tracking.
# Without this, there is no version mismatch detection.
assert_grep '\.plugin-version' \
  "references .plugin-version file path"

# Must reference .plugin-version in the context of .specwright/ directory
# (the file lives at .specwright/.plugin-version)
assert_grep '\.specwright.*\.plugin-version|\.plugin-version.*\.specwright' \
  ".plugin-version is associated with .specwright/ directory"

echo "--- AC-2: All four split deployment targets referenced ---"

# Each deployment target must be referenced. A lazy implementation that
# copies to only one or two targets would be caught here.

# Target 1: .opencode/commands
assert_grep '\.opencode.*commands|commands.*\.opencode' \
  "references .opencode/commands deployment target"

# Target 2: .specwright/skills
assert_grep '\.specwright.*skills|skills.*\.specwright' \
  "references .specwright/skills deployment target"

# Target 3: .specwright/protocols
assert_grep '\.specwright.*protocols|protocols.*\.specwright' \
  "references .specwright/protocols deployment target"

# Target 4: .specwright/agents
assert_grep '\.specwright.*agents|agents.*\.specwright' \
  "references .specwright/agents deployment target"

echo "--- AC-2: Deployment targets appear as path string literals ---"

# Verify target directory names appear as explicit string literals in code
# (quoted or in template literals), not just as substrings of other words.
# This catches an implementation that mentions targets only in comments.
# Strip comments first.
PLUGIN_NO_COMMENTS=$(grep -v '^\s*//' "$PLUGIN" | grep -v '^\s*\*')

for target in commands skills protocols agents; do
  # Must appear as a quoted string like 'commands', "skills", or in a path like '/agents'
  if echo "$PLUGIN_NO_COMMENTS" | grep -qE "['\"\`]${target}['\"\`/]|['\"\`/]${target}['\"\`]|['\"\`]\.?(opencode|specwright)/${target}"; then
    pass "'$target' appears as a string literal in code (not just comments)"
  else
    fail "'$target' does not appear as a string literal in code (expected in path construction)"
  fi
done

echo "--- AC-2: Recursive copy mechanism ---"

# The deploy must use a recursive copy (cpSync with recursive, cp -r, etc.)
# Without recursive copy, nested directory structures will not be deployed.
assert_grep '(cpSync|copyFileSync.*recursive|fs\.cp|fse\.copy|recursiv)' \
  "uses recursive copy mechanism (cpSync, fs.cp, or similar)"

# Specifically, cpSync should be called with recursive option
# (cpSync without {recursive: true} only copies single files)
assert_grep 'recursive.*true|recursive:\s*true' \
  "recursive option is set to true (not shallow copy)"

echo "--- AC-2: Version comparison logic ---"

# The plugin must read the existing version and compare it to the current version.
# A lazy implementation might always deploy or never deploy.

# Must read the current plugin version from somewhere (package.json, constant, import)
assert_grep '(version|VERSION|pluginVersion|currentVersion|packageVersion)' \
  "references a version value for comparison"

# Must have comparison logic (==, ===, !==, !=, localeCompare, or startsWith)
# to decide whether to deploy
assert_grep '(===?\s|!==?\s|!==?\s|localeCompare|\.trim\(\)\s*===)' \
  "has equality comparison operator (for version check)"

# Must have more read operations than the original (which has 1 in readWorkflow + 1 in continuation)
# Deploy needs to read .plugin-version + possibly package.json for version
READ_INVOCATIONS=$(grep -v '^\s*import' "$PLUGIN" | grep -cE '(readFileSync|readFile|Bun\.file)\s*\(' || true)
if [ "$READ_INVOCATIONS" -ge 3 ]; then
  pass "has at least 3 read invocations (original 2 + deploy version check): found $READ_INVOCATIONS"
else
  fail "has fewer than 3 read invocations (original 2 + deploy needs .plugin-version read): found $READ_INVOCATIONS"
fi

echo "--- AC-2: Version file is written after deploy ---"

# After successful deploy, .plugin-version must be written with current version.
# Check that writeFileSync (or equivalent) is INVOKED (not just imported) for .plugin-version.
# Count actual write invocations (exclude import lines)
WRITE_INVOCATIONS=$(grep -v '^\s*import' "$PLUGIN" | grep -cE '(writeFileSync|writeFile|Bun\.write)\s*\(' || true)
if [ "$WRITE_INVOCATIONS" -ge 2 ]; then
  pass "has at least 2 write invocations (continuation.md + .plugin-version): found $WRITE_INVOCATIONS"
else
  fail "has fewer than 2 write invocations (need continuation.md + .plugin-version): found $WRITE_INVOCATIONS"
fi

# Specifically, there must be a write near .plugin-version
VERSION_WRITE_CONTEXT=$(grep -B3 -A3 'plugin-version' "$PLUGIN" || true)
if echo "$VERSION_WRITE_CONTEXT" | grep -qE '(writeFileSync|writeFile|Bun\.write)'; then
  pass ".plugin-version has a write operation nearby"
else
  fail ".plugin-version has no write operation nearby (version file must be written after deploy)"
fi

echo "--- AC-2: Existing directories cleaned before copy ---"

# The spec requires "Existing Specwright-managed directories are cleaned before copy."
# Must use rmSync, rm -rf, or similar removal before copying.
assert_grep '(rmSync|rmdirSync|rm\s*\(|removeSync|fs\.rm)' \
  "uses directory removal API (rmSync, rmdirSync, or fs.rm) for pre-deploy cleaning"

# The removal must be recursive (to clean entire directory trees)
# Count occurrences of recursive: true -- need at least 2 contexts (remove + copy)
RECURSIVE_COUNT=$(grep -cE 'recursive' "$PLUGIN" || true)
if [ "$RECURSIVE_COUNT" -ge 2 ]; then
  pass "recursive option appears at least twice (remove + copy): found $RECURSIVE_COUNT"
else
  fail "recursive option appears fewer than 2 times (need for both remove and copy): found $RECURSIVE_COUNT"
fi

# The removal must happen with force: true (to avoid ENOENT on first run)
assert_grep 'force.*true|force:\s*true' \
  "uses force: true on removal (avoids ENOENT on clean install)"

echo "--- AC-2: Version match skips deployment ---"

# When versions match, no files should be copied.
# The logic must read the installed version and compare against current.
# Look for a pattern where .plugin-version content is compared to a version value.
# A lazy implementation might always deploy or always skip.
# We need evidence that the code reads .plugin-version AND compares it.
VERSION_READ_CONTEXT=$(grep -B2 -A2 'plugin-version' "$PLUGIN" || true)
if echo "$VERSION_READ_CONTEXT" | grep -qE '(readFileSync|readFile|Bun\.file|existsSync)'; then
  pass ".plugin-version is read (not just written)"
else
  fail ".plugin-version is not read (version comparison requires reading existing version)"
fi

# The version comparison must lead to a skip/return when matched
# Check that 'version' appears near an equality operator
VERSION_COMPARE=$(echo "$PLUGIN_NO_COMMENTS" | grep -E 'version.*===|===.*version|version.*!==|!==.*version|version.*==|==.*version' || true)
if [ -n "$VERSION_COMPARE" ]; then
  pass "version value is compared with equality operator"
else
  fail "no version comparison found (must compare existing vs current version)"
fi

# =========================================================================
# AC-3: Auto-deploy resolves package root correctly
# =========================================================================

echo ""
echo "--- AC-3: Uses import.meta.dir for package root ---"

# The spec explicitly requires import.meta.dir for finding sibling asset dirs.
# This is a Bun-specific API. Must not use __dirname (Node.js CJS).
assert_grep 'import\.meta\.dir' \
  "uses import.meta.dir for package root resolution"

# import.meta.dir must be used in path construction (not just referenced in a comment)
if echo "$PLUGIN_NO_COMMENTS" | grep -qE 'import\.meta\.dir'; then
  pass "import.meta.dir appears in code (not just comments)"
else
  fail "import.meta.dir only appears in comments (must be used in code)"
fi

echo "--- AC-3: No hardcoded cache/install paths ---"

# Must NOT hardcode any specific install location.
# These are all paths a lazy implementation might hardcode.
assert_not_grep '~/\.cache/opencode' \
  "does NOT hardcode ~/.cache/opencode path"

assert_not_grep '\$HOME/\.cache' \
  "does NOT hardcode \$HOME/.cache path"

assert_not_grep 'node_modules.*specwright|specwright.*node_modules' \
  "does NOT hardcode node_modules path to specwright"

assert_not_grep '/usr/local/lib' \
  "does NOT hardcode /usr/local/lib path"

assert_not_grep '\.npm' \
  "does NOT reference .npm directory"

assert_not_grep '__dirname' \
  "does NOT use __dirname (CJS pattern, should use import.meta.dir)"

assert_not_grep 'import\.meta\.url.*fileURLToPath' \
  "does NOT use fileURLToPath(import.meta.url) pattern (should use import.meta.dir directly)"

echo "--- AC-3: Package root used to locate source assets ---"

# import.meta.dir must be used to construct source asset paths, either directly
# via join(import.meta.dir, ...) or by passing it as a function argument.
if grep -qE '(join|resolve)\s*\(\s*import\.meta\.dir' "$PLUGIN" || \
   grep -qE '(deployAssets|deploy)\s*\(\s*import\.meta\.dir' "$PLUGIN"; then
  pass "import.meta.dir is passed to path construction (direct join or function arg)"
else
  fail "import.meta.dir is not used in path construction (need join or function call)"
fi

# =========================================================================
# AC-4: Auto-deploy handles errors gracefully
# =========================================================================

echo ""
echo "--- AC-4: Creates directories if missing ---"

# Must create .specwright/ and .opencode/ if they don't exist.
# mkdirSync with recursive:true is the standard pattern.
assert_grep '(mkdirSync|mkdir|fs\.mkdir)' \
  "uses mkdirSync or mkdir for directory creation"

# mkdirSync must use recursive: true (to create parent dirs)
# Check that mkdirSync appears near recursive
MKDIR_LINES=$(grep -n 'mkdirSync\|mkdir' "$PLUGIN" | grep -v '^\s*//' || true)
if echo "$MKDIR_LINES" | grep -qE 'recursive'; then
  pass "mkdirSync uses recursive option"
else
  # Could also be on the next line, check broader context
  MKDIR_WITH_CONTEXT=$(grep -A2 'mkdirSync\|mkdir' "$PLUGIN" | grep -v '^\s*//' || true)
  if echo "$MKDIR_WITH_CONTEXT" | grep -qE 'recursive'; then
    pass "mkdirSync uses recursive option (in nearby context)"
  else
    fail "mkdirSync does not appear to use recursive option"
  fi
fi

echo "--- AC-4: Skips missing source directories ---"

# If a source directory (skills/, protocols/, agents/, commands/) doesn't exist
# in the package, the deploy should skip it with a warning rather than crash.
# Must check existsSync (or similar) before copying each source.

# Count existsSync calls -- the original code has some, but deploy needs MORE
# (at least 4 additional for source dir checks + 1 for .plugin-version)
EXISTS_COUNT=$(grep -cE 'existsSync|exists\s*\(' "$PLUGIN" || true)
if [ "$EXISTS_COUNT" -ge 5 ]; then
  pass "has at least 5 existence checks (original + deploy source dir checks): found $EXISTS_COUNT"
else
  fail "has fewer than 5 existence checks (need original + deploy source dir checks): found $EXISTS_COUNT"
fi

# Must have console.warn or console.error for missing source directories
assert_grep '(console\.warn|console\.error).*([Ss]kip|[Mm]iss|[Nn]ot found|does not exist|[Ww]arn)|(skip|miss|not.found|does.not.exist|warn).*console\.(warn|error)' \
  "logs warning/error when skipping missing source directories"

echo "--- AC-4: Deploy logic wrapped in try/catch ---"

# The deploy function/block must have its own try/catch so that deploy
# errors don't prevent lifecycle handlers from registering.
# The original code has 5 try blocks (readWorkflow, session.created outer,
# session.created inner for continuation, session.compacted, session.idle).
# Deploy needs at least 1 more, so we require >= 6.
TRY_COUNT=$(grep -cE 'try\s*\{' "$PLUGIN" || true)
if [ "$TRY_COUNT" -ge 6 ]; then
  pass "has at least 6 try blocks (original 5 + deploy): found $TRY_COUNT"
else
  fail "has fewer than 6 try blocks (original has 5, deploy needs its own): found $TRY_COUNT"
fi

echo "--- AC-4: .plugin-version write failure doesn't propagate ---"

# The version file write must be in its own try/catch or otherwise guarded
# so that a write failure doesn't crash the plugin.
# Check that writeFileSync appears near catch or inside a try block
# We verify this by checking the plugin has error handling around version writes.
# A lazy implementation might let version write errors propagate.

# Extract lines around .plugin-version to check for error handling
VERSION_FILE_CONTEXT=$(grep -B5 -A5 'plugin-version' "$PLUGIN" || true)
if echo "$VERSION_FILE_CONTEXT" | grep -qE '(try|catch)'; then
  pass ".plugin-version operations are within try/catch context"
else
  fail ".plugin-version operations are NOT within try/catch (errors would propagate)"
fi

echo "--- AC-4: Plugin still registers lifecycle handlers after deploy error ---"

# The deploy must run BEFORE ctx.on() calls, and errors in deploy must not
# prevent the ctx.on() calls from executing.
# This means deploy cannot be in the same try block as the handler registrations.

# Verify deploy happens before event registration (ordering check).
# Find the line numbers of the deploy call/block and the first ctx.on call.
DEPLOY_LINE=$(grep -nE '(deploy|deployAssets|autoDeploy)\s*\(' "$PLUGIN" | head -1 | cut -d: -f1)
FIRST_ON_LINE=$(grep -nE 'ctx\.on\s*\(' "$PLUGIN" | head -1 | cut -d: -f1)

if [ -n "$DEPLOY_LINE" ] && [ -n "$FIRST_ON_LINE" ]; then
  if [ "$DEPLOY_LINE" -lt "$FIRST_ON_LINE" ]; then
    pass "deploy call (line $DEPLOY_LINE) is before first ctx.on (line $FIRST_ON_LINE)"
  else
    fail "deploy call (line $DEPLOY_LINE) is NOT before first ctx.on (line $FIRST_ON_LINE) -- deploy must run first"
  fi
else
  # Try alternative: look for deploy function definition and invocation pattern
  DEPLOY_FUNC_LINE=$(grep -nE '(function\s+(deploy|deployAssets)|const\s+(deploy|deployAssets))' "$PLUGIN" | head -1 | cut -d: -f1)
  if [ -n "$DEPLOY_FUNC_LINE" ] && [ -n "$FIRST_ON_LINE" ]; then
    # The function definition could be before or after, but the CALL must be before
    fail "deploy function found at line $DEPLOY_FUNC_LINE but no deploy invocation found before ctx.on at line $FIRST_ON_LINE"
  elif [ -z "$DEPLOY_LINE" ] && [ -z "$DEPLOY_FUNC_LINE" ]; then
    fail "no deploy function or invocation found at all"
  else
    fail "could not determine deploy/ctx.on ordering (deploy_line=${DEPLOY_LINE:-none}, first_on_line=${FIRST_ON_LINE:-none})"
  fi
fi

# =========================================================================
# Cross-checks: catch lazy/incomplete implementations
# =========================================================================

echo ""
echo "--- Cross-checks ---"

# The plugin must import additional fs APIs needed for deploy
# Original imports: readFileSync, writeFileSync, existsSync, unlinkSync
# Deploy needs: mkdirSync, cpSync, rmSync (or equivalent)
assert_grep '(mkdirSync|mkdir)' \
  "imports or uses mkdirSync (not in original, needed for deploy)"

assert_grep '(cpSync|copyFile|fs\.cp)' \
  "imports or uses cpSync (not in original, needed for deploy)"

assert_grep '(rmSync|rmdirSync|fs\.rm)' \
  "imports or uses rmSync (not in original, needed for deploy)"

# The import line must include the new APIs
IMPORT_LINE=$(grep -E "^import.*from\s+['\"]fs['\"]" "$PLUGIN" || true)
if [ -z "$IMPORT_LINE" ]; then
  IMPORT_LINE=$(grep -E "^import.*from\s+['\"]node:fs['\"]" "$PLUGIN" || true)
fi

if [ -n "$IMPORT_LINE" ]; then
  # Check that the import includes deploy-specific APIs
  for api in mkdirSync cpSync rmSync; do
    if echo "$IMPORT_LINE" | grep -qF "$api"; then
      pass "fs import includes $api"
    else
      # Could be imported on a separate line or from a different module
      if grep -qE "(import.*$api|const.*=.*require.*$api)" "$PLUGIN"; then
        pass "$api is imported (separate import)"
      else
        fail "fs import does NOT include $api (needed for deploy)"
      fi
    fi
  done
else
  fail "could not find fs import line"
fi

# Deploy must reference at least 3 of the 4 source directory names
# as string literals (to build source paths from import.meta.dir).
# This catches an implementation that only deploys to targets but
# doesn't read from source.
SOURCE_DIR_REFS=0
for dir in commands skills protocols agents; do
  # Look for the dir name as a string literal in non-comment code
  if echo "$PLUGIN_NO_COMMENTS" | grep -qE "['\"\`]${dir}['\"\`]|/${dir}['\"\`/]|['\"\`]${dir}/"; then
    SOURCE_DIR_REFS=$((SOURCE_DIR_REFS + 1))
  fi
done
if [ "$SOURCE_DIR_REFS" -ge 4 ]; then
  pass "all 4 asset directory names appear as string literals in code: $SOURCE_DIR_REFS"
else
  fail "fewer than 4 asset directory names appear as string literals ($SOURCE_DIR_REFS found, need 4: commands, skills, protocols, agents)"
fi

# Verify deploy is NOT inside an event handler.
# The deploy must run at plugin load time, not lazily on first event.
# Check that deploy-related code is NOT nested inside a ctx.on callback.
# Strategy: extract lines between first ctx.on and end -- deploy keywords
# should NOT appear there (they should be before).
if [ -n "$FIRST_ON_LINE" ] && [ -n "$DEPLOY_LINE" ]; then
  LINES_AFTER_FIRST_ON=$(tail -n +"$FIRST_ON_LINE" "$PLUGIN")
  if echo "$LINES_AFTER_FIRST_ON" | grep -qE '(deployAssets|autoDeploy|runDeploy|performDeploy|doDeploy)\s*\('; then
    fail "deploy invocation appears AFTER first ctx.on (deploy must run at load time, not inside a handler)"
  else
    pass "no deploy invocation after first ctx.on (deploy runs at load time)"
  fi
elif [ -z "$DEPLOY_LINE" ]; then
  fail "no deploy invocation found (cannot verify ordering)"
fi

# The plugin must not hardcode a specific version string for comparison.
# It should read the version from package.json or derive it dynamically.
# Check for reading package.json or importing version.
if echo "$PLUGIN_NO_COMMENTS" | grep -qE '(package\.json|packageJson|pkg\.version|version.*import|import.*version)'; then
  pass "version appears to be read dynamically (references package.json or imported)"
else
  # Alternative: version could come from a const at the top that's set from package.json
  # Check if there's a readFileSync near package.json
  if echo "$PLUGIN_NO_COMMENTS" | grep -qE 'readFileSync.*package|package.*readFileSync'; then
    pass "version appears to be read from package.json"
  else
    # It could also be an import from package.json (Bun supports this)
    if echo "$PLUGIN_NO_COMMENTS" | grep -qE "import.*from\s+['\"].*package\.json"; then
      pass "version imported from package.json"
    else
      fail "version does not appear to be read dynamically (could be hardcoded)"
    fi
  fi
fi

# ---- Summary ----

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
