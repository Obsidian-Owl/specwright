#!/usr/bin/env bash
#
# Tests for Codex build output.
#
# Validates build/build.sh codex:
# - Build succeeds and produces dist/codex
# - Required files/directories exist
# - Commands are present for all user-facing skills
# - Source and packaged commands use the plugin-native specwright:sw-* contract
# - Hook assets are packaged
# - Task tracking tools stripped from skills frontmatter
# - Agent model shorthand translated to Codex model IDs
# - Platform markers stripped from output
# - build.sh all includes codex target
#
# Dependencies: bash, jq
# Usage: ./tests/test-codex-build.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail
trap 'rm -rf "$DIST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/build/build.sh"
DIST_DIR="$ROOT_DIR/dist"
CX_DIST="$DIST_DIR/codex"

PASS=0
FAIL=0
CODEX_COMMANDS="sw-init sw-research sw-design sw-plan sw-build sw-verify sw-ship sw-debug sw-pivot sw-doctor sw-guard sw-status sw-adopt sw-learn sw-audit sw-sync sw-review"

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

extract_frontmatter() {
  local file="$1"
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  head -n "$((closing_line + 1))" "$file" | tail -n +"2" | head -n "$((closing_line - 1))"
}

extract_allowed_tools() {
  local fm="$1"
  echo "$fm" | sed -n '/^allowed-tools:/,/^[a-z]/{/^  - /p;}' | sed 's/^  - //'
}

echo "=== Codex build integration tests ==="
echo ""

if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "ABORT: build script not executable at $BUILD_SCRIPT"
  exit 1
fi

echo "--- Running: build.sh codex ---"
rm -rf "$DIST_DIR"
BUILD_OUTPUT=$("$BUILD_SCRIPT" codex 2>&1) || {
  fail "build.sh codex exited non-zero"
  printf '%s\n' "$BUILD_OUTPUT" | sed 's/^/    /'
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
}
pass "build.sh codex exits successfully"

echo "--- Output structure ---"
if [ -d "$CX_DIST" ]; then
  pass "dist/codex exists"
else
  fail "dist/codex missing"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

for dir in skills protocols agents commands hooks .codex-plugin; do
  if [ -d "$CX_DIST/$dir" ]; then
    pass "$dir directory exists"
  else
    fail "$dir directory missing"
  fi
done

if [ -f "$DIST_DIR/shared/specwright-state-paths.mjs" ]; then
  pass "dist/shared/specwright-state-paths.mjs exists"
else
  fail "dist/shared/specwright-state-paths.mjs missing"
fi

for file in README.md hooks.json .codex-plugin/plugin.json; do
  if [ -f "$CX_DIST/$file" ]; then
    pass "$file exists"
  else
    fail "$file missing"
  fi
done

if [ -f "$CX_DIST/.codex-plugin/plugin.json" ]; then
  if jq empty "$CX_DIST/.codex-plugin/plugin.json" 2>/dev/null; then
    pass "plugin.json is valid JSON"
  else
    fail "plugin.json is invalid JSON"
  fi
  assert_eq "$(jq -r '.name' "$CX_DIST/.codex-plugin/plugin.json")" "specwright" "plugin name is specwright"
fi

echo "--- Command coverage ---"
CMD_COUNT=$(find "$CX_DIST/commands" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
assert_eq "$CMD_COUNT" "17" "17 command files are packaged"
for cmd in $CODEX_COMMANDS; do
  if [ -f "$CX_DIST/commands/$cmd.md" ]; then
    pass "commands/$cmd.md exists"
  else
    fail "commands/$cmd.md missing"
  fi
done

echo "--- Command contract ---"
for cmd in $CODEX_COMMANDS; do
  SOURCE_CMD="$ROOT_DIR/adapters/codex/commands/$cmd.md"
  PACKAGED_CMD="$CX_DIST/commands/$cmd.md"
  EXPECTED_SKILL="specwright:$cmd"

  if [ -f "$SOURCE_CMD" ]; then
    if grep -qF '.agents/skills/' "$SOURCE_CMD"; then
      fail "source $cmd command still references .agents/skills/"
    else
      pass "source $cmd command does not reference .agents/skills/"
    fi

    if grep -qF "$EXPECTED_SKILL" "$SOURCE_CMD"; then
      pass "source $cmd command references $EXPECTED_SKILL"
    else
      fail "source $cmd command missing $EXPECTED_SKILL"
    fi
  else
    fail "source $cmd.md missing from adapters/codex/commands/"
  fi

  if [ -f "$PACKAGED_CMD" ]; then
    if grep -qF '.agents/skills/' "$PACKAGED_CMD"; then
      fail "packaged $cmd command still references .agents/skills/"
    else
      pass "packaged $cmd command does not reference .agents/skills/"
    fi

    if grep -qF "$EXPECTED_SKILL" "$PACKAGED_CMD"; then
      pass "packaged $cmd command references $EXPECTED_SKILL"
    else
      fail "packaged $cmd command missing $EXPECTED_SKILL"
    fi
  else
    fail "packaged $cmd command missing from dist/codex/commands/"
  fi
done

echo "--- Hook coverage ---"
for hook in session-start.mjs pre-ship-guard.mjs stop.mjs; do
  if [ -f "$CX_DIST/hooks/$hook" ]; then
    pass "hooks/$hook exists"
  else
    fail "hooks/$hook missing"
  fi
done

for hook in session-start.mjs pre-ship-guard.mjs stop.mjs; do
  if grep -Fq "../../shared/specwright-state-paths.mjs" "$CX_DIST/hooks/$hook" 2>/dev/null; then
    pass "hooks/$hook imports shared resolver"
  else
    fail "hooks/$hook does not import shared resolver"
  fi
done

if [ -f "$CX_DIST/hooks.json" ]; then
  for event in SessionStart PreToolUse Stop; do
    if jq -e --arg e "$event" '.hooks | has($e)' "$CX_DIST/hooks.json" >/dev/null 2>&1; then
      pass "hooks.json includes $event"
    else
      fail "hooks.json missing $event"
    fi
  done
fi

echo "--- Skill transformation ---"
if [ -f "$CX_DIST/skills/sw-build/SKILL.md" ]; then
  SW_BUILD_FM=$(extract_frontmatter "$CX_DIST/skills/sw-build/SKILL.md" || true)
  SW_BUILD_TOOLS=$(extract_allowed_tools "$SW_BUILD_FM")

  if echo "$SW_BUILD_TOOLS" | grep -qx "Read"; then
    pass "sw-build still includes Read (identity tool mapping)"
  else
    fail "sw-build missing Read after build"
  fi

  for stripped in TaskCreate TaskUpdate TaskList TaskGet; do
    if echo "$SW_BUILD_TOOLS" | grep -qx "$stripped"; then
      fail "sw-build still contains stripped tool $stripped"
    else
      pass "sw-build strips $stripped"
    fi
  done
fi

echo "--- Agent model translation ---"
if [ -f "$CX_DIST/agents/specwright-architect.md" ]; then
  ARCH_FM=$(extract_frontmatter "$CX_DIST/agents/specwright-architect.md" || true)
  ARCH_MODEL=$(echo "$ARCH_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$ARCH_MODEL" "gpt-5.4" "specwright-architect model translated to gpt-5.4"
fi

if [ -f "$CX_DIST/agents/specwright-executor.md" ]; then
  EXEC_FM=$(extract_frontmatter "$CX_DIST/agents/specwright-executor.md" || true)
  EXEC_MODEL=$(echo "$EXEC_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$EXEC_MODEL" "gpt-5.3-codex" "specwright-executor model translated to gpt-5.3-codex"
fi

echo "--- Platform markers removed ---"
MARKERS=$(grep -rl '<!-- platform:' "$CX_DIST" 2>/dev/null || true)
if [ -z "$MARKERS" ]; then
  pass "no platform markers remain in dist/codex"
else
  fail "platform markers remain in dist/codex"
fi

echo "--- build.sh all includes codex ---"
rm -rf "$DIST_DIR"
if ! "$BUILD_SCRIPT" all >/dev/null 2>&1; then
  fail "build.sh all exited non-zero"
fi

if [ -d "$DIST_DIR/codex" ]; then
  pass "build.sh all produces dist/codex"
else
  fail "build.sh all missing dist/codex"
fi

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
