#!/usr/bin/env bash
#
# Tests for AC-3: Opencode plugin entry point handles lifecycle events
#
# Validates adapters/opencode/plugin.ts against the spec:
# - File existence
# - Exports a plugin function (default or named export)
# - Handles session.created: reads workflow.json, outputs recovery summary
# - Handles session.compacted: writes continuation.md with state snapshot
# - Handles session.idle: warns if work is in progress
# - Does NOT use CLAUDE_PLUGIN_ROOT or any Claude Code-specific paths
# - Uses only standard Node.js/Bun APIs (fs, path)
# - Contains work status checking logic
# - Does NOT use process.exit (Opencode plugins don't exit)
# - References progress tracking (tasksCompleted/tasksTotal)
# - Basic structural validity
#
# Dependencies: bash
# Usage: ./tests/test-opencode-plugin.sh
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

# ─── Pre-flight ──────────────────────────────────────────────────────

echo "=== AC-3: Opencode plugin entry point ==="
echo ""

# ─── 1. File existence ──────────────────────────────────────────────

echo "--- File existence ---"

if [ -f "$PLUGIN" ]; then
  pass "plugin.ts exists"
else
  fail "plugin.ts does not exist at $PLUGIN"
  echo ""
  echo "RESULT: 0 passed, 1 failed (cannot continue without file)"
  exit 1
fi

# Verify file is non-empty
FILESIZE=$(wc -c < "$PLUGIN")
if [ "$FILESIZE" -gt 50 ]; then
  pass "plugin.ts is non-trivial (${FILESIZE} bytes)"
else
  fail "plugin.ts is too small to be a real implementation (${FILESIZE} bytes)"
fi

# ─── 2. Exports a plugin function ───────────────────────────────────

echo "--- Plugin function export ---"

# Must have a default export (Opencode plugins export default async function)
# Accept: export default, export default async function, export default function,
#         export default async (, module.exports
if grep -qE '(export\s+default|module\.exports)' "$PLUGIN"; then
  pass "has a default export or module.exports"
else
  fail "no default export or module.exports found"
fi

# The exported function should be async (Opencode plugin functions are async)
assert_grep 'async' "exported function is async"

# The function must accept a context parameter (ctx, context, etc.)
# This is the Opencode plugin context object
assert_grep '(ctx|context|plugin|options)\s*[:\)]' "function accepts a context/parameter object"

# ─── 3. Event: session.created ──────────────────────────────────────

echo "--- Event: session.created ---"

assert_grep 'session\.created' "references session.created event"

# session.created must read workflow.json to check for active work
assert_grep 'workflow\.json' "references workflow.json path (state file)"

# The handler must produce a recovery summary -- check for output/summary/message logic
# The Claude Code equivalent builds a summary string with work details
assert_grep '(summary|recovery|resume|progress|[Ww]ork\s+in\s+progress)' \
  "session.created handler references recovery/summary/progress concept"

# Must read the file (not just reference the path string)
assert_grep '(readFile|readFileSync|readTextFile|Bun\.file|fs\.)' \
  "uses a file-reading API (not just string reference to workflow.json)"

# Must parse JSON from the workflow file
assert_grep '(JSON\.parse|\.json\(\))' \
  "parses JSON from workflow state file"

# ─── 4. Event: session.compacted ────────────────────────────────────

echo "--- Event: session.compacted ---"

assert_grep 'session\.compacted' "references session.compacted event"

# session.compacted must write continuation.md
assert_grep 'continuation\.md' "references continuation.md path"

# Must actually write the file (not just reference the name)
assert_grep '(writeFile|writeFileSync|Bun\.write|fs\.write)' \
  "uses a file-writing API for continuation.md"

# The continuation content should include state snapshot information
# Check that the handler builds content with current state, next steps, etc.
assert_grep '(snapshot|[Cc]urrent\s+[Ss]tate|[Nn]ext\s+[Ss]tep|continuation|[Ss]tatus)' \
  "session.compacted handler builds state snapshot content"

# ─── 5. Event: session.idle ─────────────────────────────────────────

echo "--- Event: session.idle ---"

assert_grep 'session\.idle' "references session.idle event"

# session.idle must warn about active work -- check for warning/active work logic
assert_grep '(warn|active|in.progress|[Ww]ork)' \
  "session.idle handler includes warning or active work check"

# ─── 6. No CLAUDE_PLUGIN_ROOT ───────────────────────────────────────

echo "--- No Claude Code-specific paths ---"

assert_not_grep 'CLAUDE_PLUGIN_ROOT' \
  "does NOT reference CLAUDE_PLUGIN_ROOT"

assert_not_grep '\$\{CLAUDE_PLUGIN_ROOT\}' \
  "does NOT use \${CLAUDE_PLUGIN_ROOT} template"

# Must not reference .claude/ directory paths (Claude Code settings location)
assert_not_grep '\.claude/' \
  "does NOT reference .claude/ paths"

# Must not reference .claude-plugin directory
assert_not_grep '\.claude-plugin' \
  "does NOT reference .claude-plugin directory"

# Must not reference claude-code-specific config files
assert_not_grep 'settings\.json' \
  "does NOT reference settings.json (Claude Code config)"

assert_not_grep 'hooks\.json' \
  "does NOT reference hooks.json (Claude Code hooks config)"

# ─── 7. No Claude Code-specific imports ─────────────────────────────

echo "--- No Claude Code-specific imports ---"

# Must not import from Claude Code adapter paths
assert_not_grep "from\s+['\"].*claude-code" \
  "does NOT import from claude-code modules"

assert_not_grep "require\s*\(\s*['\"].*claude-code" \
  "does NOT require claude-code modules"

# Must not import from the hooks directory
assert_not_grep "from\s+['\"].*hooks/" \
  "does NOT import from hooks/ directory"

# ─── 8. Uses standard Node/Bun APIs ─────────────────────────────────

echo "--- Standard APIs ---"

# Must import or use fs module (for reading workflow.json, writing continuation.md)
assert_grep "(from\s+['\"]fs['\"]|from\s+['\"]node:fs['\"]|require\s*\(\s*['\"]fs['\"]|Bun\.file|Bun\.write)" \
  "imports fs module or uses Bun file APIs"

# Must use path operations (joining paths to .specwright/state/)
assert_grep "(from\s+['\"]path['\"]|from\s+['\"]node:path['\"]|require\s*\(\s*['\"]path['\"]|path\.join|path\.resolve|join\s*\(|resolve\s*\()" \
  "uses path module or path operations"

# ─── 9. Work status checking logic ──────────────────────────────────

echo "--- Work status logic ---"

# Must check work status to determine if work is "in progress"
# The Claude Code hooks check for status not being shipped/abandoned
assert_grep '(shipped|abandoned|status|currentWork)' \
  "checks work status (shipped, abandoned, or currentWork)"

# Must distinguish between active and inactive work states
# A lazy implementation might skip the status check entirely
assert_grep '(status|currentWork)\b' \
  "references currentWork or status field from workflow state"

# ─── 10. No process.exit ────────────────────────────────────────────

echo "--- No process.exit ---"

# Opencode plugins are async functions that return, not scripts that exit
assert_not_grep 'process\.exit' \
  "does NOT use process.exit (Opencode plugins return, not exit)"

# Also check for Deno.exit or Bun-specific exit calls
assert_not_grep 'Deno\.exit' \
  "does NOT use Deno.exit"

# ─── 11. Progress tracking ──────────────────────────────────────────

echo "--- Progress tracking ---"

# Must reference task completion tracking for the recovery summary
# The Claude Code hooks use tasksCompleted and tasksTotal
assert_grep '(tasksCompleted|tasksTotal|tasks[Cc]ompleted|tasks[Tt]otal|completed|progress)' \
  "references progress tracking (tasksCompleted, tasksTotal, or similar)"

# ─── 12. Structural validity ────────────────────────────────────────

echo "--- Structural validity ---"

# Count opening and closing braces -- they should be balanced
# (Basic syntax check -- not a full parser, but catches obvious errors)
OPEN_BRACES=$(grep -o '{' "$PLUGIN" | wc -l)
CLOSE_BRACES=$(grep -o '}' "$PLUGIN" | wc -l)
if [ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]; then
  pass "braces are balanced ({: $OPEN_BRACES, }: $CLOSE_BRACES)"
else
  fail "braces are unbalanced ({: $OPEN_BRACES, }: $CLOSE_BRACES)"
fi

# Count opening and closing parens
OPEN_PARENS=$(grep -o '(' "$PLUGIN" | wc -l)
CLOSE_PARENS=$(grep -o ')' "$PLUGIN" | wc -l)
if [ "$OPEN_PARENS" -eq "$CLOSE_PARENS" ]; then
  pass "parentheses are balanced ((: $OPEN_PARENS, ): $CLOSE_PARENS)"
else
  fail "parentheses are unbalanced ((: $OPEN_PARENS, ): $CLOSE_PARENS)"
fi

# File should have reasonable length (not a trivial stub)
LINE_COUNT=$(wc -l < "$PLUGIN")
if [ "$LINE_COUNT" -ge 30 ]; then
  pass "plugin.ts has reasonable length (${LINE_COUNT} lines)"
else
  fail "plugin.ts is suspiciously short (${LINE_COUNT} lines -- likely a stub)"
fi

# ─── 13. Cross-checks (catch lazy implementations) ──────────────────

echo "--- Cross-checks ---"

# Plugin must NOT be a copy of session-start.mjs
SESSION_START="$ROOT_DIR/adapters/claude-code/hooks/session-start.mjs"
if [ -f "$SESSION_START" ]; then
  if diff -q "$PLUGIN" "$SESSION_START" &>/dev/null; then
    fail "plugin.ts is identical to session-start.mjs (should be a distinct Opencode plugin)"
  else
    pass "plugin.ts is not a copy of session-start.mjs"
  fi
fi

# Plugin must NOT be a copy of session-stop.mjs
SESSION_STOP="$ROOT_DIR/adapters/claude-code/hooks/session-stop.mjs"
if [ -f "$SESSION_STOP" ]; then
  if diff -q "$PLUGIN" "$SESSION_STOP" &>/dev/null; then
    fail "plugin.ts is identical to session-stop.mjs (should be a distinct Opencode plugin)"
  else
    pass "plugin.ts is not a copy of session-stop.mjs"
  fi
fi

# Plugin must handle ALL THREE events (not just one)
# Count distinct event references to ensure all are present
EVENT_COUNT=0
grep -qE 'session\.created' "$PLUGIN" && EVENT_COUNT=$((EVENT_COUNT + 1))
grep -qE 'session\.compacted' "$PLUGIN" && EVENT_COUNT=$((EVENT_COUNT + 1))
grep -qE 'session\.idle' "$PLUGIN" && EVENT_COUNT=$((EVENT_COUNT + 1))
if [ "$EVENT_COUNT" -eq 3 ]; then
  pass "all 3 required events are handled (session.created, session.compacted, session.idle)"
else
  fail "only $EVENT_COUNT of 3 required events found (need session.created, session.compacted, session.idle)"
fi

# The plugin must reference .specwright/state/ path (not some other path)
assert_grep '\.specwright/state' \
  "references .specwright/state/ directory for state files"

# Must have at least TWO file I/O operations (read workflow.json + write continuation.md)
READ_OPS=$(grep -cE '(readFile|readFileSync|readTextFile|Bun\.file)' "$PLUGIN" || true)
WRITE_OPS=$(grep -cE '(writeFile|writeFileSync|Bun\.write)' "$PLUGIN" || true)
if [ "$READ_OPS" -ge 1 ] && [ "$WRITE_OPS" -ge 1 ]; then
  pass "has both read and write file operations (read: $READ_OPS, write: $WRITE_OPS)"
else
  fail "missing file I/O: need at least 1 read and 1 write operation (read: $READ_OPS, write: $WRITE_OPS)"
fi

# The plugin should reference the Opencode context properties (directory, project, etc.)
# This proves it's actually using the Opencode plugin API, not just standalone code
assert_grep '(directory|worktree|project|client)' \
  "references Opencode context properties (directory, worktree, project, or client)"

# Must NOT use console.log with JSON.stringify for output (that's the Claude Code Stop hook pattern)
# Opencode plugins should use context-provided methods or return values
assert_not_grep 'console\.log\s*\(\s*JSON\.stringify' \
  "does NOT use console.log(JSON.stringify(...)) pattern (Claude Code hook pattern)"

# ─── 14. Event handler structure ─────────────────────────────────────

echo "--- Event handler structure ---"

# The plugin should register event handlers using on/subscribe/addEventListener or similar
# OR define handler functions/objects that are mapped to events
assert_grep '(\.on\s*\(|\.subscribe|addEventListener|event|handler|hook)' \
  "registers event handlers (on/subscribe/handler pattern)"

# Each event handler should have error handling (try/catch or .catch)
# A lazy implementation might skip error handling
TRY_COUNT=$(grep -c 'try\s*{' "$PLUGIN" || true)
CATCH_COUNT=$(grep -c 'catch' "$PLUGIN" || true)
if [ "$CATCH_COUNT" -ge 1 ]; then
  pass "has error handling (try/catch or .catch) -- found $CATCH_COUNT catch clauses"
else
  fail "no error handling found (needs try/catch for graceful degradation)"
fi

# ─── 15. Timestamp in continuation ───────────────────────────────────

echo "--- Continuation snapshot format ---"

# The continuation.md should include a timestamp (matching the Claude Code PreCompact hook spec)
# The session-start.mjs checks for "Snapshot: {ISO timestamp}" format
assert_grep '(Snapshot|timestamp|ISO|toISOString|Date|new Date)' \
  "continuation snapshot includes timestamp logic"

# ─── Summary ────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
