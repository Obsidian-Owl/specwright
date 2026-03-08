#!/usr/bin/env bash
#
# Tests for AC-6 through AC-11: Opencode build script integration tests
#
# Runs the actual build and inspects dist/opencode/ output:
#   AC-6:  Correct output structure (dirs, file counts)
#   AC-7:  Frontmatter tool names lowercased, stripped tools absent
#   AC-8:  Agent definitions translated (mode: subagent, full model IDs)
#   AC-9:  Protocol path references rewritten
#   AC-10: Skill overrides applied correctly
#   AC-11: Claude Code build not regressed
#
# Dependencies: bash, jq, diff
# Usage: ./tests/test-opencode-build.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/build/build.sh"
DIST_DIR="$ROOT_DIR/dist"
OC_DIST="$DIST_DIR/opencode"
CC_DIST="$DIST_DIR/claude-code"
MAPPING="$ROOT_DIR/build/mappings/opencode.json"

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
extract_body() {
  local file="$1"
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  tail -n +"$((closing_line + 2))" "$file"
}

# Extract allowed-tools list items from YAML frontmatter
extract_allowed_tools() {
  local fm="$1"
  echo "$fm" | sed -n '/^allowed-tools:/,/^[a-z]/{ /^  - /p }' | sed 's/^  - //'
}

# ─── Pre-flight ──────────────────────────────────────────────────────

echo "=== AC-6 through AC-11: Opencode build integration tests ==="
echo ""

if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "ABORT: build script not found or not executable at $BUILD_SCRIPT"
  exit 1
fi

if [ ! -f "$MAPPING" ]; then
  echo "ABORT: opencode mapping file not found at $MAPPING"
  exit 1
fi

# ─── Clean pre-existing dist to avoid stale state ────────────────────

echo "--- Setup: cleaning dist/ ---"
rm -rf "$DIST_DIR"

# ═══════════════════════════════════════════════════════════════════════
# Run the opencode build
# ═══════════════════════════════════════════════════════════════════════

echo "--- Running: build.sh opencode ---"

BUILD_OUTPUT=$("$BUILD_SCRIPT" opencode 2>&1) || {
  fail "build.sh opencode exited with non-zero status"
  echo "  Build output:"
  echo "$BUILD_OUTPUT" | sed 's/^/    /'
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (build failed, cannot continue)"
  # Clean up
  rm -rf "$DIST_DIR"
  exit 1
}

pass "build.sh opencode exits successfully"

# ═══════════════════════════════════════════════════════════════════════
# AC-6: Build produces correct Opencode output structure
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-6: Output structure ==="

# ─── dist/opencode/ exists ────────────────────────────────────────────

echo "--- Top-level directory ---"

if [ -d "$OC_DIST" ]; then
  pass "dist/opencode/ directory exists"
else
  fail "dist/opencode/ directory does not exist"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (no output directory)"
  rm -rf "$DIST_DIR"
  exit 1
fi

# ─── Required files at top level ──────────────────────────────────────

echo "--- Required top-level files ---"

for file in package.json plugin.ts README.md; do
  if [ -f "$OC_DIST/$file" ]; then
    pass "$file exists in dist/opencode/"
  else
    fail "$file missing from dist/opencode/"
  fi
done

# ─── package.json is from adapter (not empty, not from core) ─────────

if [ -f "$OC_DIST/package.json" ]; then
  # Must be valid JSON
  if jq empty "$OC_DIST/package.json" 2>/dev/null; then
    pass "package.json is valid JSON"
  else
    fail "package.json is not valid JSON"
  fi

  # Must match the adapter's package.json exactly
  if diff -q "$OC_DIST/package.json" "$ROOT_DIR/adapters/opencode/package.json" &>/dev/null; then
    pass "package.json matches adapter source"
  else
    fail "package.json does NOT match adapters/opencode/package.json"
  fi
fi

# ─── plugin.ts is from adapter ───────────────────────────────────────

if [ -f "$OC_DIST/plugin.ts" ]; then
  if diff -q "$OC_DIST/plugin.ts" "$ROOT_DIR/adapters/opencode/plugin.ts" &>/dev/null; then
    pass "plugin.ts matches adapter source"
  else
    fail "plugin.ts does NOT match adapters/opencode/plugin.ts"
  fi
fi

# ─── commands/ directory ──────────────────────────────────────────────

echo "--- commands/ directory ---"

if [ -d "$OC_DIST/commands" ]; then
  pass "commands/ directory exists"
else
  fail "commands/ directory missing from dist/opencode/"
fi

# Exactly 14 command files
if [ -d "$OC_DIST/commands" ]; then
  CMD_COUNT=$(find "$OC_DIST/commands" -maxdepth 1 -name '*.md' -type f | wc -l)
  assert_eq "$CMD_COUNT" "14" "commands/ has exactly 14 .md files"

  # Spot-check specific command files exist
  for cmd in sw-init sw-build sw-verify sw-ship sw-guard; do
    if [ -f "$OC_DIST/commands/${cmd}.md" ]; then
      pass "commands/${cmd}.md exists"
    else
      fail "commands/${cmd}.md missing"
    fi
  done

  # commands/ content must match adapter source
  if diff -rq "$OC_DIST/commands/" "$ROOT_DIR/adapters/opencode/commands/" &>/dev/null; then
    pass "commands/ matches adapter source"
  else
    fail "commands/ does NOT match adapters/opencode/commands/"
  fi
fi

# ─── skills/ directory ───────────────────────────────────────────────

echo "--- skills/ directory ---"

if [ -d "$OC_DIST/skills" ]; then
  pass "skills/ directory exists"
else
  fail "skills/ directory missing from dist/opencode/"
fi

if [ -d "$OC_DIST/skills" ]; then
  # 19 skill directories
  SKILL_DIR_COUNT=$(find "$OC_DIST/skills" -mindepth 1 -maxdepth 1 -type d | wc -l)
  assert_eq "$SKILL_DIR_COUNT" "19" "skills/ has exactly 19 subdirectories"

  # Each has SKILL.md
  SKILL_FILE_COUNT=0
  MISSING_SKILLS=""
  for skill_dir in "$OC_DIST"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    if [ -f "$skill_dir/SKILL.md" ]; then
      SKILL_FILE_COUNT=$((SKILL_FILE_COUNT + 1))
    else
      MISSING_SKILLS="$MISSING_SKILLS $skill_name"
    fi
  done
  assert_eq "$SKILL_FILE_COUNT" "19" "all 19 skill directories contain SKILL.md"
  if [ -n "$MISSING_SKILLS" ]; then
    fail "skills missing SKILL.md:$MISSING_SKILLS"
  fi

  # Verify specific skill directories exist (spot-check)
  for skill in sw-init sw-build sw-design sw-plan sw-verify sw-ship sw-guard sw-learn sw-research sw-debug sw-pivot sw-doctor sw-status sw-audit gate-build gate-tests gate-security gate-wiring gate-spec; do
    if [ -d "$OC_DIST/skills/$skill" ]; then
      pass "skills/$skill/ directory exists"
    else
      fail "skills/$skill/ directory missing"
    fi
  done
fi

# ─── agents/ directory ───────────────────────────────────────────────

echo "--- agents/ directory ---"

if [ -d "$OC_DIST/agents" ]; then
  pass "agents/ directory exists"
else
  fail "agents/ directory missing from dist/opencode/"
fi

if [ -d "$OC_DIST/agents" ]; then
  AGENT_COUNT=$(find "$OC_DIST/agents" -maxdepth 1 -name '*.md' -type f | wc -l)
  assert_eq "$AGENT_COUNT" "6" "agents/ has exactly 6 .md files"

  # Verify specific agent files
  for agent in specwright-architect specwright-build-fixer specwright-executor specwright-researcher specwright-reviewer specwright-tester; do
    if [ -f "$OC_DIST/agents/${agent}.md" ]; then
      pass "agents/${agent}.md exists"
    else
      fail "agents/${agent}.md missing"
    fi
  done
fi

# ─── protocols/ directory ────────────────────────────────────────────

echo "--- protocols/ directory ---"

if [ -d "$OC_DIST/protocols" ]; then
  pass "protocols/ directory exists"
else
  fail "protocols/ directory missing from dist/opencode/"
fi

if [ -d "$OC_DIST/protocols" ]; then
  PROTO_COUNT=$(find "$OC_DIST/protocols" -maxdepth 1 -name '*.md' -type f | wc -l)
  assert_eq "$PROTO_COUNT" "18" "protocols/ has exactly 18 .md files"

  # Spot-check specific protocol files
  for proto in state.md git.md delegation.md recovery.md evidence.md; do
    if [ -f "$OC_DIST/protocols/$proto" ]; then
      pass "protocols/$proto exists"
    else
      fail "protocols/$proto missing"
    fi
  done
fi

# ─── README.md ────────────────────────────────────────────────────────

echo "--- README.md ---"

if [ -f "$OC_DIST/README.md" ]; then
  pass "README.md exists in dist/opencode/"
  # Should match root README
  if diff -q "$OC_DIST/README.md" "$ROOT_DIR/README.md" &>/dev/null; then
    pass "README.md matches root README.md"
  else
    fail "README.md does NOT match root README.md"
  fi
fi

# ─── No unexpected directories (no hooks, no .claude-plugin) ─────────

echo "--- No unexpected content ---"

if [ -d "$OC_DIST/hooks" ]; then
  fail "dist/opencode/hooks/ exists but should NOT (hooks are Claude Code-specific)"
else
  pass "no hooks/ directory in dist/opencode/"
fi

if [ -d "$OC_DIST/.claude-plugin" ]; then
  fail "dist/opencode/.claude-plugin/ exists but should NOT (Claude Code-specific)"
else
  pass "no .claude-plugin/ directory in dist/opencode/"
fi

if [ -f "$OC_DIST/CLAUDE.md" ]; then
  fail "dist/opencode/CLAUDE.md exists but should NOT (Claude Code-specific)"
else
  pass "no CLAUDE.md in dist/opencode/"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-7: Frontmatter tool names are correctly transformed
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-7: Frontmatter tool name transformation ==="

# Pick non-overridden skills that have allowed-tools in core
# sw-init has: Read, Write, Bash, Glob, Grep, AskUserQuestion
# sw-verify should have tools too
# sw-design should have tools

echo "--- Tool transformation in non-overridden skills ---"

# Test sw-init (not overridden, has well-known tool list)
if [ -f "$OC_DIST/skills/sw-init/SKILL.md" ]; then
  INIT_FM=$(extract_frontmatter "$OC_DIST/skills/sw-init/SKILL.md" || true)
  INIT_TOOLS=$(extract_allowed_tools "$INIT_FM")

  # Verify lowercased tools are present
  for expected_tool in read write bash glob grep question; do
    if echo "$INIT_TOOLS" | grep -qx "$expected_tool"; then
      pass "sw-init allowed-tools contains '$expected_tool' (lowercased)"
    else
      fail "sw-init allowed-tools missing '$expected_tool' (expected lowercased tool)"
    fi
  done

  # Verify old Claude Code names are NOT present
  for old_tool in Read Write Bash Glob Grep AskUserQuestion; do
    if echo "$INIT_TOOLS" | grep -qx "$old_tool"; then
      fail "sw-init allowed-tools still contains '$old_tool' (should be transformed)"
    else
      pass "sw-init allowed-tools does NOT contain '$old_tool' (correctly transformed)"
    fi
  done
fi

# Test sw-design (if it has tools)
if [ -f "$OC_DIST/skills/sw-design/SKILL.md" ]; then
  DESIGN_FM=$(extract_frontmatter "$OC_DIST/skills/sw-design/SKILL.md" || true)
  DESIGN_TOOLS=$(extract_allowed_tools "$DESIGN_FM")

  if [ -n "$DESIGN_TOOLS" ]; then
    # No tool in allowed-tools should start with uppercase (except Task which maps from Agent)
    UPPERCASE_TOOLS=$(echo "$DESIGN_TOOLS" | grep -E '^[A-Z]' | grep -v '^Task$' || true)
    if [ -z "$UPPERCASE_TOOLS" ]; then
      pass "sw-design allowed-tools has no uppercase tool names (except Task)"
    else
      fail "sw-design allowed-tools still has uppercase tools: $UPPERCASE_TOOLS"
    fi
  fi
fi

# Test sw-verify (another non-overridden skill)
if [ -f "$OC_DIST/skills/sw-verify/SKILL.md" ]; then
  VERIFY_FM=$(extract_frontmatter "$OC_DIST/skills/sw-verify/SKILL.md" || true)
  VERIFY_TOOLS=$(extract_allowed_tools "$VERIFY_FM")

  if [ -n "$VERIFY_TOOLS" ]; then
    # Should contain lowercased tools
    if echo "$VERIFY_TOOLS" | grep -qx "read"; then
      pass "sw-verify allowed-tools contains 'read'"
    else
      fail "sw-verify allowed-tools missing 'read'"
    fi

    if echo "$VERIFY_TOOLS" | grep -qx "Read"; then
      fail "sw-verify allowed-tools still contains 'Read' (should be transformed to 'read')"
    else
      pass "sw-verify allowed-tools does NOT contain 'Read'"
    fi
  fi
fi

# ─── Stripped tools absent from ALL non-overridden skills ─────────────

echo "--- Stripped tools absent from frontmatter ---"

STRIPPED_FOUND=0
for skill_dir in "$OC_DIST"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [ ! -f "$skill_file" ] && continue

  # Skip overridden skills (they have their own content)
  if [ "$skill_name" = "sw-guard" ] || [ "$skill_name" = "sw-build" ]; then
    continue
  fi

  FM=$(extract_frontmatter "$skill_file" || true)
  TOOLS=$(extract_allowed_tools "$FM")

  for stripped in TaskCreate TaskUpdate TaskList TaskGet; do
    if echo "$TOOLS" | grep -qx "$stripped"; then
      fail "$skill_name allowed-tools still contains '$stripped' (should be stripped)"
      STRIPPED_FOUND=$((STRIPPED_FOUND + 1))
    fi
  done
done

if [ "$STRIPPED_FOUND" -eq 0 ]; then
  pass "no non-overridden skill has TaskCreate/TaskUpdate/TaskList/TaskGet in allowed-tools"
fi

# ─── Skill body prose is NOT transformed ──────────────────────────────

echo "--- Skill body prose NOT transformed ---"

# The body text should keep its original prose (tool names in prose should NOT be lowercased)
# Check a skill that mentions tool names in its body
if [ -f "$OC_DIST/skills/sw-init/SKILL.md" ]; then
  INIT_BODY=$(extract_body "$OC_DIST/skills/sw-init/SKILL.md" || true)

  # The body content should exist and be substantial
  INIT_BODY_LEN=${#INIT_BODY}
  if [ "$INIT_BODY_LEN" -gt 100 ]; then
    pass "sw-init body has substantial content ($INIT_BODY_LEN chars)"
  else
    fail "sw-init body is too short ($INIT_BODY_LEN chars) -- may have been damaged by transformation"
  fi
fi

# ─── Comprehensive: check ALL non-overridden skills have transformed tools ─

echo "--- All non-overridden skills: no uppercase Claude Code tools in frontmatter ---"

UNTRANSFORMED_COUNT=0
for skill_dir in "$OC_DIST"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [ ! -f "$skill_file" ] && continue

  # Skip overridden skills
  if [ "$skill_name" = "sw-guard" ] || [ "$skill_name" = "sw-build" ]; then
    continue
  fi

  FM=$(extract_frontmatter "$skill_file" || true)
  TOOLS=$(extract_allowed_tools "$FM")
  [ -z "$TOOLS" ] && continue

  # Check each tool that should have been transformed
  for old_tool in Read Write Edit Bash Glob Grep WebSearch WebFetch AskUserQuestion Agent; do
    if echo "$TOOLS" | grep -qx "$old_tool"; then
      fail "$skill_name allowed-tools still contains '$old_tool' (should be transformed)"
      UNTRANSFORMED_COUNT=$((UNTRANSFORMED_COUNT + 1))
    fi
  done
done

if [ "$UNTRANSFORMED_COUNT" -eq 0 ]; then
  pass "all non-overridden skills have fully transformed allowed-tools"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-8: Agent definitions are translated
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-8: Agent translation ==="

echo "--- mode: subagent in all agents ---"

if [ -d "$OC_DIST/agents" ]; then
  for agent_file in "$OC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    FM=$(extract_frontmatter "$agent_file" || true)

    # Must have mode: subagent
    if echo "$FM" | grep -qE '^mode:\s*subagent\s*$'; then
      pass "$agent_name has mode: subagent"
    else
      fail "$agent_name missing mode: subagent in frontmatter"
    fi
  done
fi

echo "--- Full model IDs in all agents ---"

if [ -d "$OC_DIST/agents" ]; then
  for agent_file in "$OC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    FM=$(extract_frontmatter "$agent_file" || true)

    # Must have model: with full ID
    MODEL_VALUE=$(echo "$FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)

    if [ -z "$MODEL_VALUE" ]; then
      fail "$agent_name has no model field in frontmatter"
      continue
    fi

    # Must be a full model ID, not shorthand
    case "$MODEL_VALUE" in
      claude-opus-4-6|claude-sonnet-4-6)
        pass "$agent_name has full model ID: $MODEL_VALUE"
        ;;
      opus|sonnet)
        fail "$agent_name has shorthand model '$MODEL_VALUE' (should be full ID like 'claude-opus-4-6')"
        ;;
      *)
        fail "$agent_name has unexpected model value: '$MODEL_VALUE'"
        ;;
    esac
  done
fi

echo "--- Specific model mappings ---"

# specwright-tester uses opus in core -> should be claude-opus-4-6
if [ -f "$OC_DIST/agents/specwright-tester.md" ]; then
  TESTER_FM=$(extract_frontmatter "$OC_DIST/agents/specwright-tester.md" || true)
  TESTER_MODEL=$(echo "$TESTER_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$TESTER_MODEL" "claude-opus-4-6" "specwright-tester model is claude-opus-4-6"
fi

# specwright-executor uses sonnet in core -> should be claude-sonnet-4-6
if [ -f "$OC_DIST/agents/specwright-executor.md" ]; then
  EXECUTOR_FM=$(extract_frontmatter "$OC_DIST/agents/specwright-executor.md" || true)
  EXECUTOR_MODEL=$(echo "$EXECUTOR_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$EXECUTOR_MODEL" "claude-sonnet-4-6" "specwright-executor model is claude-sonnet-4-6"
fi

# specwright-architect uses opus in core -> should be claude-opus-4-6
if [ -f "$OC_DIST/agents/specwright-architect.md" ]; then
  ARCH_FM=$(extract_frontmatter "$OC_DIST/agents/specwright-architect.md" || true)
  ARCH_MODEL=$(echo "$ARCH_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$ARCH_MODEL" "claude-opus-4-6" "specwright-architect model is claude-opus-4-6"
fi

# specwright-build-fixer uses sonnet in core -> should be claude-sonnet-4-6
if [ -f "$OC_DIST/agents/specwright-build-fixer.md" ]; then
  FIXER_FM=$(extract_frontmatter "$OC_DIST/agents/specwright-build-fixer.md" || true)
  FIXER_MODEL=$(echo "$FIXER_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$FIXER_MODEL" "claude-sonnet-4-6" "specwright-build-fixer model is claude-sonnet-4-6"
fi

echo "--- Agent body content preserved ---"

# Agent body should not be empty or mangled
if [ -d "$OC_DIST/agents" ]; then
  for agent_file in "$OC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    BODY=$(extract_body "$agent_file" || true)
    BODY_LEN=${#BODY}

    if [ "$BODY_LEN" -gt 100 ]; then
      pass "$agent_name has substantial body content ($BODY_LEN chars)"
    else
      fail "$agent_name body is too short ($BODY_LEN chars) -- may have been damaged"
    fi
  done
fi

echo "--- Agent frontmatter structure preserved ---"

# Agent files must still have name and description
if [ -d "$OC_DIST/agents" ]; then
  for agent_file in "$OC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    FM=$(extract_frontmatter "$agent_file" || true)

    if echo "$FM" | grep -qE '^name:'; then
      pass "$agent_name frontmatter has name field"
    else
      fail "$agent_name frontmatter missing name field"
    fi

    if echo "$FM" | grep -qE '^description:'; then
      pass "$agent_name frontmatter has description field"
    else
      fail "$agent_name frontmatter missing description field"
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-9: Protocol path references are rewritten
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-9: Protocol path rewriting ==="

echo "--- Protocol references rewritten in skills ---"

# Count distinct rewritten protocol references across all skills
REWRITTEN_PROTOCOLS=0
DISTINCT_PROTOCOLS=""

for skill_dir in "$OC_DIST"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [ ! -f "$skill_file" ] && continue

  # Skip overridden skills (they have their own content)
  if [ "$skill_name" = "sw-guard" ] || [ "$skill_name" = "sw-build" ]; then
    continue
  fi

  # Check for rewritten references: .specwright/protocols/
  REFS=$(grep -oE '\.specwright/protocols/[a-z-]+\.md' "$skill_file" 2>/dev/null || true)
  if [ -n "$REFS" ]; then
    while IFS= read -r ref; do
      # Track distinct protocol references
      PROTO_NAME=$(echo "$ref" | sed 's|\.specwright/protocols/||')
      if ! echo "$DISTINCT_PROTOCOLS" | grep -qF "$PROTO_NAME"; then
        DISTINCT_PROTOCOLS="$DISTINCT_PROTOCOLS $PROTO_NAME"
        REWRITTEN_PROTOCOLS=$((REWRITTEN_PROTOCOLS + 1))
      fi
    done <<< "$REFS"
  fi
done

# Must have at least 5 distinct protocol references rewritten
if [ "$REWRITTEN_PROTOCOLS" -ge 5 ]; then
  pass "at least 5 distinct protocol references rewritten ($REWRITTEN_PROTOCOLS found:$DISTINCT_PROTOCOLS)"
else
  fail "fewer than 5 distinct protocol references rewritten (found $REWRITTEN_PROTOCOLS:$DISTINCT_PROTOCOLS)"
fi

# ─── Specific protocol rewrites spot-checked ──────────────────────────

echo "--- Specific protocol rewrites ---"

# sw-init references protocols/state.md, protocols/context.md, protocols/git.md, protocols/landscape.md
if [ -f "$OC_DIST/skills/sw-init/SKILL.md" ]; then
  INIT_CONTENT=$(cat "$OC_DIST/skills/sw-init/SKILL.md")

  if echo "$INIT_CONTENT" | grep -qF '.specwright/protocols/state.md'; then
    pass "sw-init: protocols/state.md -> .specwright/protocols/state.md"
  else
    fail "sw-init: protocols/state.md NOT rewritten to .specwright/protocols/state.md"
  fi

  if echo "$INIT_CONTENT" | grep -qF '.specwright/protocols/git.md'; then
    pass "sw-init: protocols/git.md -> .specwright/protocols/git.md"
  else
    fail "sw-init: protocols/git.md NOT rewritten to .specwright/protocols/git.md"
  fi

  if echo "$INIT_CONTENT" | grep -qF '.specwright/protocols/context.md'; then
    pass "sw-init: protocols/context.md -> .specwright/protocols/context.md"
  else
    fail "sw-init: protocols/context.md NOT rewritten to .specwright/protocols/context.md"
  fi
fi

# sw-verify references protocols/stage-boundary.md, protocols/evidence.md
if [ -f "$OC_DIST/skills/sw-verify/SKILL.md" ]; then
  VERIFY_CONTENT=$(cat "$OC_DIST/skills/sw-verify/SKILL.md")

  if echo "$VERIFY_CONTENT" | grep -qF '.specwright/protocols/stage-boundary.md'; then
    pass "sw-verify: protocols/stage-boundary.md -> .specwright/protocols/stage-boundary.md"
  else
    fail "sw-verify: protocols/stage-boundary.md NOT rewritten"
  fi

  if echo "$VERIFY_CONTENT" | grep -qF '.specwright/protocols/evidence.md'; then
    pass "sw-verify: protocols/evidence.md -> .specwright/protocols/evidence.md"
  else
    fail "sw-verify: protocols/evidence.md NOT rewritten"
  fi
fi

# ─── Bare "protocols/" references should NOT remain in non-overridden skills ─

echo "--- No bare protocols/ references remain ---"

BARE_REFS_FOUND=0
for skill_dir in "$OC_DIST"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [ ! -f "$skill_file" ] && continue

  # Skip overridden skills
  if [ "$skill_name" = "sw-guard" ] || [ "$skill_name" = "sw-build" ]; then
    continue
  fi

  # Look for bare "protocols/" NOT preceded by ".specwright/"
  # Use grep with negative lookbehind equivalent: find "protocols/" but exclude ".specwright/protocols/"
  BARE=$(grep -nE 'protocols/' "$skill_file" | grep -v '\.specwright/protocols/' || true)
  if [ -n "$BARE" ]; then
    fail "$skill_name still has bare protocols/ references (not rewritten):"
    echo "$BARE" | head -3 | sed 's/^/      /'
    BARE_REFS_FOUND=$((BARE_REFS_FOUND + 1))
  fi
done

if [ "$BARE_REFS_FOUND" -eq 0 ]; then
  pass "no non-overridden skill has bare protocols/ references"
fi

# ─── Protocol files themselves are NOT modified ───────────────────────

echo "--- Protocol files not modified ---"

if [ -d "$OC_DIST/protocols" ]; then
  MODIFIED_PROTOS=0
  for proto_file in "$OC_DIST"/protocols/*.md; do
    proto_name=$(basename "$proto_file")
    core_proto="$ROOT_DIR/core/protocols/$proto_name"
    if [ -f "$core_proto" ]; then
      if ! diff -q "$proto_file" "$core_proto" &>/dev/null; then
        fail "protocols/$proto_name was modified (should be copied verbatim from core)"
        MODIFIED_PROTOS=$((MODIFIED_PROTOS + 1))
      fi
    fi
  done

  if [ "$MODIFIED_PROTOS" -eq 0 ]; then
    pass "all protocol files match core originals (not modified)"
  fi

  # Spot-check a specific protocol
  if [ -f "$OC_DIST/protocols/state.md" ] && [ -f "$ROOT_DIR/core/protocols/state.md" ]; then
    if diff -q "$OC_DIST/protocols/state.md" "$ROOT_DIR/core/protocols/state.md" &>/dev/null; then
      pass "protocols/state.md is identical to core (not modified)"
    else
      fail "protocols/state.md differs from core (should NOT be modified)"
    fi
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-10: Skill overrides applied correctly
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-10: Skill overrides ==="

echo "--- Overridden skills match adapter versions ---"

# sw-guard override
if [ -f "$OC_DIST/skills/sw-guard/SKILL.md" ] && [ -f "$ROOT_DIR/adapters/opencode/skills/sw-guard/SKILL.md" ]; then
  if diff -q "$OC_DIST/skills/sw-guard/SKILL.md" "$ROOT_DIR/adapters/opencode/skills/sw-guard/SKILL.md" &>/dev/null; then
    pass "dist sw-guard/SKILL.md matches adapters/opencode/skills/sw-guard/SKILL.md"
  else
    fail "dist sw-guard/SKILL.md does NOT match adapter version"
  fi
else
  [ ! -f "$OC_DIST/skills/sw-guard/SKILL.md" ] && fail "dist sw-guard/SKILL.md missing"
  [ ! -f "$ROOT_DIR/adapters/opencode/skills/sw-guard/SKILL.md" ] && fail "adapter sw-guard/SKILL.md missing"
fi

# sw-build override
if [ -f "$OC_DIST/skills/sw-build/SKILL.md" ] && [ -f "$ROOT_DIR/adapters/opencode/skills/sw-build/SKILL.md" ]; then
  if diff -q "$OC_DIST/skills/sw-build/SKILL.md" "$ROOT_DIR/adapters/opencode/skills/sw-build/SKILL.md" &>/dev/null; then
    pass "dist sw-build/SKILL.md matches adapters/opencode/skills/sw-build/SKILL.md"
  else
    fail "dist sw-build/SKILL.md does NOT match adapter version"
  fi
else
  [ ! -f "$OC_DIST/skills/sw-build/SKILL.md" ] && fail "dist sw-build/SKILL.md missing"
  [ ! -f "$ROOT_DIR/adapters/opencode/skills/sw-build/SKILL.md" ] && fail "adapter sw-build/SKILL.md missing"
fi

echo "--- Overridden skills do NOT match core (catch: override not applied) ---"

# sw-guard must differ from core
if [ -f "$OC_DIST/skills/sw-guard/SKILL.md" ] && [ -f "$ROOT_DIR/core/skills/sw-guard/SKILL.md" ]; then
  if diff -q "$OC_DIST/skills/sw-guard/SKILL.md" "$ROOT_DIR/core/skills/sw-guard/SKILL.md" &>/dev/null; then
    fail "dist sw-guard matches core (override was NOT applied)"
  else
    pass "dist sw-guard differs from core (override was applied)"
  fi
fi

# sw-build must differ from core
if [ -f "$OC_DIST/skills/sw-build/SKILL.md" ] && [ -f "$ROOT_DIR/core/skills/sw-build/SKILL.md" ]; then
  if diff -q "$OC_DIST/skills/sw-build/SKILL.md" "$ROOT_DIR/core/skills/sw-build/SKILL.md" &>/dev/null; then
    fail "dist sw-build matches core (override was NOT applied)"
  else
    pass "dist sw-build differs from core (override was applied)"
  fi
fi

echo "--- Non-overridden skills match core with transforms ---"

# Pick a few non-overridden skills and verify they are NOT identical to core
# (because transforms should have been applied)
# But also verify they are NOT identical to the overridden skills
for skill in sw-init sw-verify sw-learn sw-status; do
  dist_skill="$OC_DIST/skills/$skill/SKILL.md"
  core_skill="$ROOT_DIR/core/skills/$skill/SKILL.md"
  if [ -f "$dist_skill" ] && [ -f "$core_skill" ]; then
    # Should differ from core because tool transforms were applied
    if diff -q "$dist_skill" "$core_skill" &>/dev/null; then
      fail "dist $skill/SKILL.md is identical to core (transforms were NOT applied)"
    else
      pass "dist $skill/SKILL.md differs from core (transforms were applied)"
    fi
  fi
done

echo "--- Non-overridden skills preserve core structure ---"

# Non-overridden skills should still have the same markdown structure as core
# (just with transformed frontmatter tools and protocol refs)
for skill in sw-init sw-verify; do
  dist_skill="$OC_DIST/skills/$skill/SKILL.md"
  core_skill="$ROOT_DIR/core/skills/$skill/SKILL.md"
  if [ -f "$dist_skill" ] && [ -f "$core_skill" ]; then
    # Same number of ## headers
    DIST_HEADERS=$(grep -c '^## ' "$dist_skill" || true)
    CORE_HEADERS=$(grep -c '^## ' "$core_skill" || true)
    assert_eq "$DIST_HEADERS" "$CORE_HEADERS" "$skill has same number of ## headers as core ($CORE_HEADERS)"

    # Same name in frontmatter
    DIST_FM=$(extract_frontmatter "$dist_skill" || true)
    DIST_NAME=$(echo "$DIST_FM" | grep -E '^name:' | sed 's/^name:\s*//' | xargs)
    assert_eq "$DIST_NAME" "$skill" "$skill frontmatter name is '$skill'"
  fi
done

# ═══════════════════════════════════════════════════════════════════════
# AC-11: Claude Code build not regressed
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-11: Claude Code build regression ==="

echo "--- Running: build.sh claude-code ---"

CC_BUILD_OUTPUT=$("$BUILD_SCRIPT" claude-code 2>&1) || {
  fail "build.sh claude-code exited with non-zero status (REGRESSION)"
  echo "  Build output:"
  echo "$CC_BUILD_OUTPUT" | sed 's/^/    /'
}

if [ -d "$CC_DIST" ]; then
  pass "build.sh claude-code still produces dist/claude-code/"
else
  fail "build.sh claude-code did NOT produce dist/claude-code/ (REGRESSION)"
fi

echo "--- Claude Code output validation ---"

if [ -d "$CC_DIST" ]; then
  # skills/ with 19 dirs
  CC_SKILL_COUNT=$(find "$CC_DIST/skills" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
  assert_eq "$CC_SKILL_COUNT" "19" "claude-code skills/ has 19 subdirectories"

  # agents/ with 6 files
  CC_AGENT_COUNT=$(find "$CC_DIST/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l)
  assert_eq "$CC_AGENT_COUNT" "6" "claude-code agents/ has 6 files"

  # protocols/ with 18 files
  CC_PROTO_COUNT=$(find "$CC_DIST/protocols" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l)
  assert_eq "$CC_PROTO_COUNT" "18" "claude-code protocols/ has 18 files"

  # Claude Code-specific: hooks/ and .claude-plugin/ exist
  if [ -d "$CC_DIST/hooks" ]; then
    pass "claude-code has hooks/ directory"
  else
    fail "claude-code missing hooks/ directory (REGRESSION)"
  fi

  if [ -d "$CC_DIST/.claude-plugin" ]; then
    pass "claude-code has .claude-plugin/ directory"
  else
    fail "claude-code missing .claude-plugin/ directory (REGRESSION)"
  fi

  if [ -f "$CC_DIST/CLAUDE.md" ]; then
    pass "claude-code has CLAUDE.md"
  else
    fail "claude-code missing CLAUDE.md (REGRESSION)"
  fi

  # Claude Code skills should NOT have lowercased tools (identity mapping)
  if [ -f "$CC_DIST/skills/sw-init/SKILL.md" ]; then
    CC_INIT_FM=$(extract_frontmatter "$CC_DIST/skills/sw-init/SKILL.md" || true)
    CC_INIT_TOOLS=$(extract_allowed_tools "$CC_INIT_FM")

    if echo "$CC_INIT_TOOLS" | grep -qx "Read"; then
      pass "claude-code sw-init still has 'Read' (not lowercased -- identity mapping)"
    else
      fail "claude-code sw-init missing 'Read' (REGRESSION: tools were incorrectly transformed)"
    fi

    if echo "$CC_INIT_TOOLS" | grep -qx "Bash"; then
      pass "claude-code sw-init still has 'Bash' (not lowercased -- identity mapping)"
    else
      fail "claude-code sw-init missing 'Bash' (REGRESSION: tools were incorrectly transformed)"
    fi
  fi

  # Claude Code agents should NOT have mode: subagent
  if [ -f "$CC_DIST/agents/specwright-tester.md" ]; then
    CC_TESTER_FM=$(extract_frontmatter "$CC_DIST/agents/specwright-tester.md" || true)
    if echo "$CC_TESTER_FM" | grep -qE '^mode:'; then
      fail "claude-code specwright-tester has mode: field (REGRESSION -- should not be added)"
    else
      pass "claude-code specwright-tester does NOT have mode: field"
    fi

    # Should still have shorthand model names
    CC_TESTER_MODEL=$(echo "$CC_TESTER_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
    assert_eq "$CC_TESTER_MODEL" "opus" "claude-code specwright-tester still has shorthand model 'opus'"
  fi

  # Claude Code protocol refs should NOT be rewritten
  if [ -f "$CC_DIST/skills/sw-init/SKILL.md" ]; then
    if grep -qF '.specwright/protocols/' "$CC_DIST/skills/sw-init/SKILL.md"; then
      fail "claude-code sw-init has .specwright/protocols/ references (REGRESSION -- should not be rewritten)"
    else
      pass "claude-code sw-init does NOT have .specwright/protocols/ references"
    fi

    if grep -qF 'protocols/state.md' "$CC_DIST/skills/sw-init/SKILL.md"; then
      pass "claude-code sw-init has bare protocols/state.md reference (correct for claude-code)"
    else
      fail "claude-code sw-init missing protocols/state.md reference (REGRESSION)"
    fi
  fi
fi

echo "--- build.sh 'all' includes opencode ---"

# Clean and rebuild with 'all'
rm -rf "$DIST_DIR"

ALL_BUILD_OUTPUT=$("$BUILD_SCRIPT" all 2>&1) || {
  fail "build.sh all exited with non-zero status"
}

if [ -d "$OC_DIST" ]; then
  pass "build.sh all produces dist/opencode/"
else
  fail "build.sh all does NOT produce dist/opencode/ (opencode not included in 'all' target)"
fi

if [ -d "$CC_DIST" ]; then
  pass "build.sh all produces dist/claude-code/"
else
  fail "build.sh all does NOT produce dist/claude-code/ (claude-code dropped from 'all' target)"
fi

echo "--- build.sh accepts 'opencode' argument ---"

# Verify the script accepts 'opencode' without error
rm -rf "$DIST_DIR"
if "$BUILD_SCRIPT" opencode &>/dev/null; then
  pass "build.sh opencode accepted as valid argument"
else
  fail "build.sh opencode rejected as invalid argument"
fi

echo "--- Source files not modified by build ---"

# Core files should not be modified by the build process
# Check a few core skill files haven't been altered
for skill in sw-init sw-build sw-verify; do
  core_skill="$ROOT_DIR/core/skills/$skill/SKILL.md"
  if [ -f "$core_skill" ]; then
    # Core files should still have uppercase tool names
    CORE_FM=$(extract_frontmatter "$core_skill" || true)
    CORE_TOOLS=$(extract_allowed_tools "$CORE_FM")
    if [ -n "$CORE_TOOLS" ]; then
      if echo "$CORE_TOOLS" | grep -qx "Read"; then
        pass "core/$skill/SKILL.md still has 'Read' (not modified by build)"
      else
        fail "core/$skill/SKILL.md modified by build -- 'Read' is gone"
      fi
    fi
  fi
done

# Core agent files should still have shorthand model names
if [ -f "$ROOT_DIR/core/agents/specwright-tester.md" ]; then
  CORE_TESTER_FM=$(extract_frontmatter "$ROOT_DIR/core/agents/specwright-tester.md" || true)
  CORE_TESTER_MODEL=$(echo "$CORE_TESTER_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$CORE_TESTER_MODEL" "opus" "core specwright-tester.md still has 'opus' (not modified by build)"
fi

# ─── Cleanup ─────────────────────────────────────────────────────────

echo ""
echo "--- Cleanup ---"
rm -rf "$DIST_DIR"
pass "dist/ cleaned up"

# ─── Summary ─────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
