#!/usr/bin/env bash
#
# Tests for the Claude Code build output (AC-1 through AC-14)
#
# Runs the actual build and inspects dist/claude-code/ output:
#   AC-1:  File setup, helpers, build invocation, cleanup
#   AC-2:  Correct output structure (dirs, file counts, required files)
#   AC-3:  Identity mapping (tool names unchanged, spot-checks)
#   AC-4:  Agent identity (no mode:subagent, shorthand models, array tools)
#   AC-5:  Protocol refs (bare protocols/ paths, no .specwright/ prefix)
#   AC-6:  Hook files (exist, pass node --check)
#   AC-7:  Plugin manifest (valid JSON, name + version)
#   AC-8:  No platform markers in any file
#   AC-9:  sw-build content (Task tools, "Task tracking", "Mid-build checks")
#   AC-10: No opencode artifacts (no commands/, package.json, plugin.ts)
#   AC-11: Source files not modified by build
#   AC-14: Configured test path executes the multi-worktree runtime harness
#   AC-13: Exit 0 with summary showing 0 failures
#
# Dependencies: bash, jq, node, python, pytest
# Usage: ./tests/test-claude-code-build.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail
trap 'rm -rf "$DIST_DIR"' EXIT

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/build/build.sh"
DIST_DIR="$ROOT_DIR/dist"
CC_DIST="$DIST_DIR/claude-code"
CLAUDE_BUILD_MODE="${SPECWRIGHT_CLAUDE_BUILD_MODE:-full}"
MULTI_WORKTREE_RUNTIME_TEST="$ROOT_DIR/tests/test-multi-worktree-state.sh"
TARGET_MODEL_DOCS_TEST="$ROOT_DIR/tests/test-branch-freshness-target-model-docs.sh"
GIT_FRESHNESS_ENGINE_TEST="$ROOT_DIR/tests/test-git-freshness-engine.sh"
LIFECYCLE_FRESHNESS_TEST="$ROOT_DIR/tests/test-lifecycle-freshness-checkpoints.sh"
WORKFLOW_PROOF_TEST="$ROOT_DIR/tests/test-workflow-proof.sh"
CONFIG_VISIBILITY_DOCS_TEST="$ROOT_DIR/tests/test-config-validation-visibility-docs.sh"
AUDIT_CHAIN_ROOT_MODEL_TEST="$ROOT_DIR/tests/test-audit-chain-root-model.sh"
AUDIT_CHAIN_WORKFLOW_PROOF_TEST="$ROOT_DIR/tests/test-audit-chain-workflow-proof.sh"
AUDIT_CHAIN_MIGRATION_SURFACES_TEST="$ROOT_DIR/tests/test-audit-chain-migration-surfaces.sh"
APPROVAL_LIFECYCLE_TEST="$ROOT_DIR/tests/test-approval-lifecycle-docs.sh"
REVIEW_PACKET_DOCS_TEST="$ROOT_DIR/tests/test-review-packet-docs.sh"
SUPPORT_SURFACE_CUTOVER_TEST="$ROOT_DIR/tests/test-support-surface-cutover-docs.sh"
VERIFY_MUTATION_PROOF_TEST="$ROOT_DIR/tests/test-verify-mutation-proof.sh"

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

assert_path_exists() {
  local path="$1"
  local label="$2"
  if [ -e "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
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

assert_file_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_file_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    fail "$label (found unexpected: '$needle')"
  else
    pass "$label"
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
  echo "$fm" | sed -n '/^allowed-tools:/,/^[^ ]/{/^  - /p;}' | sed 's/^  - //'
}

git_source_status() {
  git --git-dir="$ROOT_DIR/.git" --work-tree="$ROOT_DIR" status --porcelain -- core/ adapters/
}

run_smoke_regression() {
  local label="$1"
  local command="$2"
  local coverage_marker="$3"
  local exit_code=0
  local output

  echo ""
  echo "=== Smoke regression: $label ==="

  output="$(sh -lc "$command" 2>&1)" || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    fail "$label smoke regression fails"
    echo "  Regression output:"
    printf '    %s\n' "${output//$'\n'/$'\n    '}"
    return
  fi

  pass "$label smoke regression passes"

  if printf '%s' "$output" | grep -Fq "$coverage_marker"; then
    pass "$label smoke regression emits $coverage_marker"
  else
    fail "$label smoke regression missing $coverage_marker"
  fi
}

run_operator_surface_workflow_proof_regression() {
  python -m pytest \
    evals/tests/test_closeout_digest_contract.py \
    evals/tests/test_operator_surface_visibility.py \
    evals/tests/test_runtime_mode_paths.py \
    evals/tests/test_recovery_closeout_full_pipeline_contract.py \
    -q || return 1

  python -m pytest \
    evals/tests/test_grader.py \
    -k 'project_visible or verdict_mismatch_fails' \
    -q || return 1

  printf 'COVERAGE: workflow-proof.operator-surface\n'
}

run_smoke_regression_fn() {
  local label="$1"
  local coverage_marker="$2"
  local fn_name="$3"
  local exit_code=0
  local output

  echo ""
  echo "=== Smoke regression: $label ==="

  output="$($fn_name 2>&1)" || exit_code=$?

  if [ "$exit_code" -ne 0 ]; then
    fail "$label smoke regression fails"
    echo "  Regression output:"
    printf '    %s\n' "${output//$'\n'/$'\n    '}"
    return
  fi

  pass "$label smoke regression passes"

  if printf '%s' "$output" | grep -Fq "$coverage_marker"; then
    pass "$label smoke regression emits $coverage_marker"
  else
    fail "$label smoke regression missing $coverage_marker"
  fi
}

run_smoke_checks() {
  echo ""
  echo "=== Smoke: Claude Code structural packaging ==="

  assert_path_exists "$CC_DIST" "smoke build writes dist/claude-code"
  assert_path_exists "$CC_DIST/skills/sw-build/SKILL.md" "smoke build includes sw-build skill"
  assert_path_exists "$CC_DIST/skills/sw-verify/SKILL.md" "smoke build includes sw-verify skill"
  assert_path_exists "$CC_DIST/protocols/context.md" "smoke build includes context protocol"
  assert_path_exists "$CC_DIST/protocols/state.md" "smoke build includes state protocol"
  assert_path_exists "$CC_DIST/protocols/git-freshness.md" "smoke build includes git-freshness protocol"
  assert_path_exists "$CC_DIST/protocols/approvals.md" "smoke build includes approvals protocol"
  assert_path_exists "$CC_DIST/protocols/review-packet.md" "smoke build includes review-packet protocol"
  assert_path_exists "$CC_DIST/agents/specwright-executor.md" "smoke build includes executor agent"
  assert_path_exists "$CC_DIST/hooks/session-start.mjs" "smoke build includes session-start hook"
  assert_path_exists "$CC_DIST/.claude-plugin/plugin.json" "smoke build includes plugin manifest"

  if jq -e '.name == "specwright" and (.version | type == "string" and length > 0)' "$CC_DIST/.claude-plugin/plugin.json" >/dev/null; then
    pass "smoke plugin manifest preserves required fields"
  else
    fail "smoke plugin manifest preserves required fields"
  fi

  if node --check "$CC_DIST/hooks/session-start.mjs" >/dev/null 2>&1; then
    pass "smoke hook payload parses as JavaScript"
  else
    fail "smoke hook payload parses as JavaScript"
  fi

  if rg -n '<!-- platform:' "$CC_DIST" >/dev/null 2>&1; then
    fail "smoke dist does not contain platform markers"
  else
    pass "smoke dist does not contain platform markers"
  fi

  assert_file_contains "$CC_DIST/CLAUDE.md" "approvals.md" "smoke CLAUDE.md indexes approvals protocol"
  assert_file_contains "$CC_DIST/CLAUDE.md" "review-packet.md" "smoke CLAUDE.md indexes review-packet protocol"
  assert_file_contains "$CC_DIST/skills/sw-build/SKILL.md" "Approval checkpoint" "smoke sw-build includes approval checkpoint"
  assert_file_contains "$CC_DIST/skills/sw-verify/SKILL.md" "Approval Lineage" "smoke sw-verify includes approval lineage"
  assert_file_contains "$CC_DIST/protocols/context.md" "projectArtifactsRoot" "smoke context protocol preserves project artifact root"
  assert_file_contains "$CC_DIST/protocols/context.md" "workArtifactsRoot" "smoke context protocol preserves work artifact root"
  assert_file_contains "$CC_DIST/protocols/state.md" "stage-report.md" "smoke state protocol preserves runtime stage report classification"
  assert_file_contains "$CC_DIST/protocols/decision.md" "{stageReportPath}" "smoke decision protocol uses stageReportPath handoff"

  run_smoke_regression \
    "workflow proof" \
    "SPECWRIGHT_WORKFLOW_PROOF_MODE=smoke bash \"$WORKFLOW_PROOF_TEST\"" \
    "COVERAGE: workflow-proof.queue-managed-ship"

  run_smoke_regression \
    "approval lifecycle" \
    "SPECWRIGHT_APPROVAL_LIFECYCLE_MODE=smoke bash \"$APPROVAL_LIFECYCLE_TEST\"" \
    "COVERAGE: approval-lifecycle.fail-closed"

  run_smoke_regression \
    "audit-chain workflow proof" \
    "bash \"$AUDIT_CHAIN_WORKFLOW_PROOF_TEST\"" \
    "COVERAGE: audit-chain.workflow-proof"

  run_smoke_regression \
    "audit-chain migration surfaces" \
    "bash \"$AUDIT_CHAIN_MIGRATION_SURFACES_TEST\"" \
    "COVERAGE: audit-chain.migration-surfaces"

  run_smoke_regression \
    "support-surface cutover" \
    "bash \"$SUPPORT_SURFACE_CUTOVER_TEST\"" \
    "COVERAGE: support-surface.publication-mode-cutover"

  run_smoke_regression_fn \
    "operator-surface workflow proof" \
    "COVERAGE: workflow-proof.operator-surface" \
    "run_operator_surface_workflow_proof_regression"

  run_smoke_regression \
    "verify mutation proof" \
    "bash \"$VERIFY_MUTATION_PROOF_TEST\"" \
    "COVERAGE: verify-mutation.proof-surfaces"

  POST_BUILD_SOURCE_STATUS=$(git_source_status)
  if [ "$POST_BUILD_SOURCE_STATUS" = "$PRE_BUILD_SOURCE_STATUS" ]; then
    pass "smoke build leaves tracked source unchanged"
  else
    fail "smoke build leaves tracked source unchanged"
  fi

  printf 'COVERAGE: claude-build.smoke-structural\n'
}

# ─── Pre-flight ──────────────────────────────────────────────────────

echo "=== AC-1 through AC-14: Claude Code build integration tests ==="
echo ""

case "$CLAUDE_BUILD_MODE" in
  full|smoke) ;;
  *)
    echo "ABORT: unknown SPECWRIGHT_CLAUDE_BUILD_MODE=$CLAUDE_BUILD_MODE"
    exit 1
    ;;
esac

if ! command -v jq &>/dev/null; then
  echo "ABORT: jq is required but not installed"
  exit 1
fi

if ! command -v node &>/dev/null; then
  echo "ABORT: node is required but not installed"
  exit 1
fi

if ! command -v python &>/dev/null; then
  echo "ABORT: python is required but not installed"
  exit 1
fi

if ! python -m pytest --version >/dev/null 2>&1; then
  echo "ABORT: pytest is required but not installed"
  exit 1
fi

if [ ! -x "$BUILD_SCRIPT" ]; then
  echo "ABORT: build script not found or not executable at $BUILD_SCRIPT"
  exit 1
fi

# Capture pre-build source state so AC-11 checks for build-introduced mutations,
# not intentional edits already present on the current branch.
PRE_BUILD_SOURCE_STATUS=$(git_source_status)

# ─── Clean pre-existing dist to avoid stale state ────────────────────

echo "--- Setup: cleaning dist/ ---"
rm -rf "$DIST_DIR"

# ═══════════════════════════════════════════════════════════════════════
# Run the claude-code build
# ═══════════════════════════════════════════════════════════════════════

echo "--- Running: build.sh claude-code ---"

BUILD_OUTPUT=$("$BUILD_SCRIPT" claude-code 2>&1) || {
  fail "build.sh claude-code exited with non-zero status"
  echo "  Build output:"
  # shellcheck disable=SC2001
  echo "$BUILD_OUTPUT" | sed 's/^/    /'
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (build failed, cannot continue)"
  rm -rf "$DIST_DIR"
  exit 1
}

pass "build.sh claude-code exits successfully"

if [ "$CLAUDE_BUILD_MODE" = "smoke" ]; then
  run_smoke_checks
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ] || exit 1
  exit 0
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-2: Build produces correct Claude Code output structure
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-2: Output structure ==="

# ─── dist/claude-code/ exists ─────────────────────────────────────────

echo "--- Top-level directory ---"

if [ -d "$CC_DIST" ]; then
  pass "dist/claude-code/ directory exists"
else
  fail "dist/claude-code/ directory does not exist"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (no output directory)"
  rm -rf "$DIST_DIR"
  exit 1
fi

# ─── skills/ directory: 19 subdirectories each with SKILL.md ─────────

echo "--- skills/ directory ---"

EXPECTED_SKILLS="gate-build gate-security gate-semantic gate-spec gate-tests gate-wiring sw-audit sw-build sw-debug sw-design sw-doctor sw-guard sw-init sw-learn sw-pivot sw-plan sw-research sw-review sw-ship sw-status sw-sync sw-verify"
EXPECTED_SKILL_COUNT=22

if [ -d "$CC_DIST/skills" ]; then
  pass "skills/ directory exists"
else
  fail "skills/ directory missing from dist/claude-code/"
fi

if [ -d "$CC_DIST/skills" ]; then
  # Count only directories that should contain SKILL.md (exclude reference doc directories).
  # Space-delimited list — add new entries separated by spaces (e.g. "lang-building lang-testing").
  REFERENCE_DIRS="lang-building"
  SKILL_DIR_COUNT=0
  for dir in "$CC_DIST"/skills/*/; do
    dir_name=$(basename "$dir")
    case " $REFERENCE_DIRS " in
      *" $dir_name "*) ;; # skip reference doc directories
      *) SKILL_DIR_COUNT=$((SKILL_DIR_COUNT + 1)) ;;
    esac
  done
  assert_eq "$SKILL_DIR_COUNT" "$EXPECTED_SKILL_COUNT" "skills/ has exactly $EXPECTED_SKILL_COUNT skill subdirectories"

  # Each skill directory must have SKILL.md (reference doc directories are excluded)
  SKILL_FILE_COUNT=0
  MISSING_SKILLS=""
  for skill_dir in "$CC_DIST"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    case " $REFERENCE_DIRS " in
      *" $skill_name "*) continue ;; # skip reference doc directories
    esac
    if [ -f "$skill_dir/SKILL.md" ]; then
      SKILL_FILE_COUNT=$((SKILL_FILE_COUNT + 1))
    else
      MISSING_SKILLS="$MISSING_SKILLS $skill_name"
    fi
  done
  if [ -z "$MISSING_SKILLS" ]; then
    pass "all $EXPECTED_SKILL_COUNT skill directories contain SKILL.md"
  else
    fail "skills missing SKILL.md:$MISSING_SKILLS"
  fi

  # Verify every expected skill directory exists
  for skill in $EXPECTED_SKILLS; do
    if [ -d "$CC_DIST/skills/$skill" ]; then
      pass "skills/$skill/ directory exists"
    else
      fail "skills/$skill/ directory missing"
    fi
  done
fi

# ─── agents/ directory: exactly 7 .md files ──────────────────────────

echo "--- agents/ directory ---"

EXPECTED_AGENTS="specwright-architect specwright-build-fixer specwright-executor specwright-integration-tester specwright-researcher specwright-reviewer specwright-tester"
EXPECTED_AGENT_COUNT=7

if [ -d "$CC_DIST/agents" ]; then
  pass "agents/ directory exists"
else
  fail "agents/ directory missing from dist/claude-code/"
fi

if [ -d "$CC_DIST/agents" ]; then
  AGENT_COUNT=$(find "$CC_DIST/agents" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
  assert_eq "$AGENT_COUNT" "$EXPECTED_AGENT_COUNT" "agents/ has exactly $EXPECTED_AGENT_COUNT .md files"

  for agent in $EXPECTED_AGENTS; do
    if [ -f "$CC_DIST/agents/${agent}.md" ]; then
      pass "agents/${agent}.md exists"
    else
      fail "agents/${agent}.md missing"
    fi
  done
fi

# ─── protocols/ directory ─────────────────────────────────────────────

echo "--- protocols/ directory ---"

# Keep the mirror-count check dynamic because protocol additions are frequent.
# Required protocol names are still explicitly spot-checked below.
EXPECTED_PROTO_COUNT=$(find "$ROOT_DIR/core/protocols" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')

if [ -d "$CC_DIST/protocols" ]; then
  pass "protocols/ directory exists"
else
  fail "protocols/ directory missing from dist/claude-code/"
fi

if [ -d "$CC_DIST/protocols" ]; then
  PROTO_COUNT=$(find "$CC_DIST/protocols" -maxdepth 1 -name '*.md' -type f | wc -l | tr -d ' ')
  assert_eq "$PROTO_COUNT" "$EXPECTED_PROTO_COUNT" "protocols/ mirrors the core protocol set"

  # Spot-check specific protocol files
  for proto in state.md git.md git-freshness.md approvals.md review-packet.md delegation.md recovery.md evidence.md stage-boundary.md context.md repo-map.md; do
    if [ -f "$CC_DIST/protocols/$proto" ]; then
      pass "protocols/$proto exists"
    else
      fail "protocols/$proto missing"
    fi
  done

  if [ -f "$CC_DIST/protocols/gate-verdict.md" ]; then
    fail "protocols/gate-verdict.md should not exist after verdict merge"
  else
    pass "protocols/gate-verdict.md removed after verdict merge"
  fi

  if [ -f "$CC_DIST/protocols/semi-formal-reasoning.md" ]; then
    fail "protocols/semi-formal-reasoning.md should not exist after protocol deletion"
  else
    pass "protocols/semi-formal-reasoning.md removed after protocol deletion"
  fi

  if [ -f "$CC_DIST/protocols/convergence.md" ]; then
    fail "protocols/convergence.md should not exist after merge into decision.md"
  else
    pass "protocols/convergence.md removed after merge into decision.md"
  fi

  if [ -f "$CC_DIST/protocols/assumptions.md" ]; then
    fail "protocols/assumptions.md should not exist after merge into decision.md"
  else
    pass "protocols/assumptions.md removed after merge into decision.md"
  fi
fi

# ─── hooks/ directory ─────────────────────────────────────────────────

echo "--- hooks/ directory ---"

if [ -d "$CC_DIST/hooks" ]; then
  pass "hooks/ directory exists"
else
  fail "hooks/ directory missing from dist/claude-code/"
fi

if [ -f "$DIST_DIR/shared/specwright-state-paths.mjs" ]; then
  pass "dist/shared/specwright-state-paths.mjs exists"
else
  fail "dist/shared/specwright-state-paths.mjs missing"
fi

if [ -f "$DIST_DIR/shared/specwright-git-freshness.mjs" ]; then
  pass "dist/shared/specwright-git-freshness.mjs exists"
else
  fail "dist/shared/specwright-git-freshness.mjs missing"
fi

if [ -f "$DIST_DIR/shared/specwright-approvals.mjs" ]; then
  pass "dist/shared/specwright-approvals.mjs exists"
else
  fail "dist/shared/specwright-approvals.mjs missing"
fi

# ─── .claude-plugin/ directory ────────────────────────────────────────

echo "--- .claude-plugin/ directory ---"

if [ -d "$CC_DIST/.claude-plugin" ]; then
  pass ".claude-plugin/ directory exists"
else
  fail ".claude-plugin/ directory missing from dist/claude-code/"
fi

# ─── CLAUDE.md ────────────────────────────────────────────────────────

echo "--- CLAUDE.md ---"

if [ -f "$CC_DIST/CLAUDE.md" ]; then
  pass "CLAUDE.md exists in dist/claude-code/"
  # Must match adapter source
  if diff -q "$CC_DIST/CLAUDE.md" "$ROOT_DIR/adapters/claude-code/CLAUDE.md" &>/dev/null; then
    pass "CLAUDE.md matches adapter source"
  else
    fail "CLAUDE.md does NOT match adapters/claude-code/CLAUDE.md"
  fi
else
  fail "CLAUDE.md missing from dist/claude-code/"
fi

# ─── README.md ────────────────────────────────────────────────────────

echo "--- README.md ---"

if [ -f "$CC_DIST/README.md" ]; then
  pass "README.md exists in dist/claude-code/"
  # Must match root README.md (build copies it)
  if diff -q "$CC_DIST/README.md" "$ROOT_DIR/README.md" &>/dev/null; then
    pass "README.md matches root README.md"
  else
    fail "README.md does NOT match root README.md"
  fi
else
  fail "README.md missing from dist/claude-code/"
fi

echo "--- Worktree-aware root docs ---"

assert_file_contains "$ROOT_DIR/README.md" "git rev-parse --git-common-dir" "README.md documents shared repo state via git-common-dir"
assert_file_contains "$ROOT_DIR/README.md" "git rev-parse --git-dir" "README.md documents per-worktree session state via git-dir"
assert_file_not_contains "$ROOT_DIR/README.md" ".specwright/config.json" "README.md no longer points config at checkout-local .specwright/config.json"

assert_file_contains "$ROOT_DIR/DESIGN.md" "{repoStateRoot}" "DESIGN.md describes the shared repo state root"
assert_file_contains "$ROOT_DIR/DESIGN.md" "{worktreeStateRoot}" "DESIGN.md describes the per-worktree state root"
assert_file_not_contains "$ROOT_DIR/DESIGN.md" ".specwright/worktrees/" "DESIGN.md no longer describes helper worktrees under .specwright/worktrees/"
assert_file_not_contains "$ROOT_DIR/DESIGN.md" "workflow.json # Current state" "DESIGN.md no longer describes a singleton .specwright/state/workflow.json layout"
assert_file_contains "$ROOT_DIR/CLAUDE.md" "git-freshness.md" "root CLAUDE.md lists git-freshness.md in the protocol index"
assert_file_contains "$ROOT_DIR/CLAUDE.md" "approvals.md" "root CLAUDE.md lists approvals.md in the protocol index"
assert_file_contains "$ROOT_DIR/CLAUDE.md" "review-packet.md" "root CLAUDE.md lists review-packet.md in the protocol index"

assert_file_contains "$CC_DIST/CLAUDE.md" "repoStateRoot" "dist CLAUDE.md references the shared repo state root"
assert_file_contains "$CC_DIST/CLAUDE.md" "worktreeStateRoot" "dist CLAUDE.md references the per-worktree state root"
assert_file_contains "$CC_DIST/CLAUDE.md" "git-freshness.md" "dist CLAUDE.md lists git-freshness.md in the protocol index"
assert_file_contains "$CC_DIST/CLAUDE.md" "approvals.md" "dist CLAUDE.md lists approvals.md in the protocol index"
assert_file_contains "$CC_DIST/CLAUDE.md" "review-packet.md" "dist CLAUDE.md lists review-packet.md in the protocol index"
assert_file_not_contains "$CC_DIST/CLAUDE.md" "**\`.specwright/CONSTITUTION.md\`**" "dist CLAUDE.md no longer points anchor docs at checkout-local .specwright/"

# ═══════════════════════════════════════════════════════════════════════
# AC-3: Identity mapping — tool names unchanged, no lowercased tools
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-3: Identity mapping ==="

echo "--- ALL skill files: no tool name matching ^[a-z] in allowed-tools ---"

LOWERCASE_TOOL_FOUND=0
SKILLS_WITH_TOOLS=0
for skill_dir in "$CC_DIST"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [ ! -f "$skill_file" ] && continue

  FM=$(extract_frontmatter "$skill_file" || true)
  TOOLS=$(extract_allowed_tools "$FM")
  [ -z "$TOOLS" ] && continue

  SKILLS_WITH_TOOLS=$((SKILLS_WITH_TOOLS + 1))

  # Every tool must start with uppercase (identity mapping means no transformation)
  LOWERCASE_TOOLS=$(echo "$TOOLS" | grep -E '^[a-z]' || true)
  if [ -n "$LOWERCASE_TOOLS" ]; then
    fail "$skill_name has lowercase tool names: $(echo "$LOWERCASE_TOOLS" | tr '\n' ' ')"
    LOWERCASE_TOOL_FOUND=$((LOWERCASE_TOOL_FOUND + 1))
  fi
done

if [ "$LOWERCASE_TOOL_FOUND" -eq 0 ]; then
  pass "no skill has lowercase tool names in allowed-tools (identity mapping correct)"
fi

# Parser sanity: all skills should have non-empty allowed-tools
if [ "$SKILLS_WITH_TOOLS" -ge "$EXPECTED_SKILL_COUNT" ]; then
  pass "tool parser found allowed-tools in $SKILLS_WITH_TOOLS skills (sanity check)"
else
  fail "tool parser only found allowed-tools in $SKILLS_WITH_TOOLS skills (expected $EXPECTED_SKILL_COUNT, parser may be broken)"
fi

echo "--- Spot-check: sw-init has Read, Write, Bash ---"

if [ -f "$CC_DIST/skills/sw-init/SKILL.md" ]; then
  INIT_FM=$(extract_frontmatter "$CC_DIST/skills/sw-init/SKILL.md" || true)
  INIT_TOOLS=$(extract_allowed_tools "$INIT_FM")

  for expected_tool in Read Write Bash; do
    if echo "$INIT_TOOLS" | grep -qx "$expected_tool"; then
      pass "sw-init allowed-tools contains '$expected_tool'"
    else
      fail "sw-init allowed-tools missing '$expected_tool'"
    fi
  done
fi

echo "--- Spot-check: sw-build has TaskCreate ---"

if [ -f "$CC_DIST/skills/sw-build/SKILL.md" ]; then
  BUILD_FM=$(extract_frontmatter "$CC_DIST/skills/sw-build/SKILL.md" || true)
  BUILD_TOOLS=$(extract_allowed_tools "$BUILD_FM")

  if echo "$BUILD_TOOLS" | grep -qx "TaskCreate"; then
    pass "sw-build allowed-tools contains 'TaskCreate'"
  else
    fail "sw-build allowed-tools missing 'TaskCreate'"
  fi

  # Also check the other Task tools are present
  for task_tool in TaskUpdate TaskList TaskGet; do
    if echo "$BUILD_TOOLS" | grep -qx "$task_tool"; then
      pass "sw-build allowed-tools contains '$task_tool'"
    else
      fail "sw-build allowed-tools missing '$task_tool'"
    fi
  done
fi

echo "--- Verify tools match core exactly for non-overridden skills ---"

# For identity mapping, tools should be identical to core
for skill in sw-init sw-verify sw-design sw-plan; do
  dist_skill="$CC_DIST/skills/$skill/SKILL.md"
  core_skill="$ROOT_DIR/core/skills/$skill/SKILL.md"
  if [ -f "$dist_skill" ] && [ -f "$core_skill" ]; then
    DIST_FM=$(extract_frontmatter "$dist_skill" || true)
    CORE_FM=$(extract_frontmatter "$core_skill" || true)
    DIST_TOOLS=$(extract_allowed_tools "$DIST_FM" | sort)
    CORE_TOOLS=$(extract_allowed_tools "$CORE_FM" | sort)

    if [ "$DIST_TOOLS" = "$CORE_TOOLS" ]; then
      pass "$skill allowed-tools identical to core (identity mapping)"
    else
      fail "$skill allowed-tools differ from core (identity mapping should preserve them)"
    fi
  fi
done

# ═══════════════════════════════════════════════════════════════════════
# AC-4: Agent identity — no mode:subagent, shorthand models, array tools
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-4: Agent identity ==="

echo "--- (a) NO mode:subagent in any agent ---"

if [ -d "$CC_DIST/agents" ]; then
  for agent_file in "$CC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    FM=$(extract_frontmatter "$agent_file" || true)

    # Must NOT have mode: subagent
    if echo "$FM" | grep -qE '^mode:\s*subagent'; then
      fail "$agent_name has mode: subagent (should NOT be present for Claude Code)"
    else
      pass "$agent_name does NOT have mode: subagent"
    fi

    # Must NOT have mode: field at all (Claude Code agents don't use it)
    if echo "$FM" | grep -qE '^mode:'; then
      fail "$agent_name has mode: field (Claude Code agents should not have mode)"
    else
      pass "$agent_name has no mode: field"
    fi
  done
fi

echo "--- (b) Shorthand model names (opus/sonnet not full IDs) ---"

if [ -d "$CC_DIST/agents" ]; then
  for agent_file in "$CC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    FM=$(extract_frontmatter "$agent_file" || true)

    MODEL_VALUE=$(echo "$FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)

    if [ -z "$MODEL_VALUE" ]; then
      fail "$agent_name has no model field in frontmatter"
      continue
    fi

    # Must be shorthand, NOT full ID
    case "$MODEL_VALUE" in
      opus|sonnet)
        pass "$agent_name has shorthand model: $MODEL_VALUE"
        ;;
      claude-opus-4-6|claude-sonnet-4-6|claude-*)
        fail "$agent_name has full model ID '$MODEL_VALUE' (should be shorthand 'opus' or 'sonnet')"
        ;;
      *)
        fail "$agent_name has unexpected model value: '$MODEL_VALUE'"
        ;;
    esac
  done
fi

echo "--- Specific model spot-checks ---"

# specwright-tester uses opus
if [ -f "$CC_DIST/agents/specwright-tester.md" ]; then
  TESTER_FM=$(extract_frontmatter "$CC_DIST/agents/specwright-tester.md" || true)
  TESTER_MODEL=$(echo "$TESTER_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$TESTER_MODEL" "opus" "specwright-tester model is 'opus'"
fi

# specwright-executor uses sonnet
if [ -f "$CC_DIST/agents/specwright-executor.md" ]; then
  EXECUTOR_FM=$(extract_frontmatter "$CC_DIST/agents/specwright-executor.md" || true)
  EXECUTOR_MODEL=$(echo "$EXECUTOR_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$EXECUTOR_MODEL" "sonnet" "specwright-executor model is 'sonnet'"
fi

echo "--- (c) Array-style tool entries (- Read not read: true) ---"

if [ -d "$CC_DIST/agents" ]; then
  for agent_file in "$CC_DIST"/agents/*.md; do
    agent_name=$(basename "$agent_file" .md)
    FM=$(extract_frontmatter "$agent_file" || true)

    # Must have array-style "  - ToolName" tool entries (Claude Code format)
    ARRAY_TOOLS=$(echo "$FM" | grep -E '^  - [A-Za-z]' || true)
    if [ -n "$ARRAY_TOOLS" ]; then
      pass "$agent_name has array-style tool entries"
    else
      fail "$agent_name missing array-style tool entries (should be '- Read' format)"
    fi

    # Must NOT have object-style "  toolname: true" lines (that's opencode format)
    OBJECT_TOOLS=$(echo "$FM" | grep -E '^  [a-z]+: true$' || true)
    if [ -z "$OBJECT_TOOLS" ]; then
      pass "$agent_name has no object-style tool entries"
    else
      fail "$agent_name has object-style tool entries: $(echo "$OBJECT_TOOLS" | head -1 | xargs)"
    fi
  done
fi

echo "--- Agent body content preserved ---"

if [ -d "$CC_DIST/agents" ]; then
  for agent_file in "$CC_DIST"/agents/*.md; do
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

echo "--- Agent frontmatter has name and description ---"

if [ -d "$CC_DIST/agents" ]; then
  for agent_file in "$CC_DIST"/agents/*.md; do
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
# AC-5: Protocol refs — ALL skills use bare protocols/ paths
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-5: Protocol references ==="

echo "--- ALL skills: no .specwright/protocols/ references ---"

SPECWRIGHT_PROTO_FOUND=0
for skill_dir in "$CC_DIST"/skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"
  [ ! -f "$skill_file" ] && continue

  if grep -qF '.specwright/protocols/' "$skill_file"; then
    fail "$skill_name has .specwright/protocols/ references (should be bare protocols/)"
    SPECWRIGHT_PROTO_FOUND=$((SPECWRIGHT_PROTO_FOUND + 1))
  fi
done

if [ "$SPECWRIGHT_PROTO_FOUND" -eq 0 ]; then
  pass "no skill has .specwright/protocols/ references"
fi

echo "--- Skills use bare protocols/ paths ---"

# Spot-check that protocol references exist and are bare
if [ -f "$CC_DIST/skills/sw-init/SKILL.md" ]; then
  if grep -qF 'protocols/state.md' "$CC_DIST/skills/sw-init/SKILL.md"; then
    pass "sw-init has bare protocols/state.md reference"
  else
    fail "sw-init missing protocols/state.md reference"
  fi

  if grep -qF 'protocols/context.md' "$CC_DIST/skills/sw-init/SKILL.md"; then
    pass "sw-init has bare protocols/context.md reference"
  else
    fail "sw-init missing protocols/context.md reference"
  fi
fi

if [ -f "$CC_DIST/skills/sw-verify/SKILL.md" ]; then
  if grep -qF 'protocols/evidence.md' "$CC_DIST/skills/sw-verify/SKILL.md"; then
    pass "sw-verify has bare protocols/evidence.md reference"
  else
    fail "sw-verify missing protocols/evidence.md reference"
  fi
fi

echo "--- Protocol files match core verbatim ---"

if [ -d "$CC_DIST/protocols" ]; then
  MODIFIED_PROTOS=0
  for proto_file in "$CC_DIST"/protocols/*.md; do
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
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-6: Hook files exist and pass node --check
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-6: Hook files ==="

EXPECTED_HOOKS="post-write-diagnostics.mjs session-start.mjs session-stop.mjs subagent-context.mjs task-completed.mjs"

echo "--- Hook files exist ---"

for hook in $EXPECTED_HOOKS; do
  if [ -f "$CC_DIST/hooks/$hook" ]; then
    pass "hooks/$hook exists"
  else
    fail "hooks/$hook missing"
  fi
done

for hook in session-start.mjs session-stop.mjs subagent-context.mjs; do
  if grep -Fq "../../shared/specwright-state-paths.mjs" "$CC_DIST/hooks/$hook" 2>/dev/null; then
    pass "hooks/$hook imports shared resolver"
  else
    fail "hooks/$hook does not import shared resolver"
  fi
done

if grep -Fq "../../shared/specwright-state-paths.mjs" "$CC_DIST/hooks/pre-ship-guard.mjs" 2>/dev/null; then
  pass "hooks/pre-ship-guard.mjs imports shared resolver"
else
  fail "hooks/pre-ship-guard.mjs does not import shared resolver"
fi

echo "--- Hook files pass node --check (valid JavaScript) ---"

for hook in $EXPECTED_HOOKS; do
  hook_file="$CC_DIST/hooks/$hook"
  if [ -f "$hook_file" ]; then
    if node --check "$hook_file" 2>/dev/null; then
      pass "hooks/$hook passes node --check"
    else
      fail "hooks/$hook fails node --check (syntax error)"
    fi
  fi
done

echo "--- Hook files match adapter source ---"

for hook in $EXPECTED_HOOKS; do
  hook_file="$CC_DIST/hooks/$hook"
  adapter_hook="$ROOT_DIR/adapters/claude-code/hooks/$hook"
  if [ -f "$hook_file" ] && [ -f "$adapter_hook" ]; then
    if diff -q "$hook_file" "$adapter_hook" &>/dev/null; then
      pass "hooks/$hook matches adapter source"
    else
      fail "hooks/$hook does NOT match adapters/claude-code/hooks/$hook"
    fi
  fi
done

echo "--- No unexpected hook files ---"

if [ -d "$CC_DIST/hooks" ]; then
  HOOK_MJS_COUNT=$(find "$CC_DIST/hooks" -maxdepth 1 -name '*.mjs' -type f | wc -l | tr -d ' ')
  assert_eq "$HOOK_MJS_COUNT" "6" "hooks/ has exactly 6 .mjs files"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-7: Plugin manifest
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-7: Plugin manifest ==="

PLUGIN_JSON="$CC_DIST/.claude-plugin/plugin.json"

echo "--- plugin.json exists and is valid JSON ---"

if [ -f "$PLUGIN_JSON" ]; then
  pass "plugin.json exists"

  if jq empty "$PLUGIN_JSON" 2>/dev/null; then
    pass "plugin.json is valid JSON"
  else
    fail "plugin.json is not valid JSON"
  fi
else
  fail "plugin.json missing from .claude-plugin/"
fi

echo "--- plugin.json has required fields ---"

if [ -f "$PLUGIN_JSON" ]; then
  PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON" 2>/dev/null)
  if [ -n "$PLUGIN_NAME" ]; then
    pass "plugin.json has 'name' field: '$PLUGIN_NAME'"
  else
    fail "plugin.json missing 'name' field"
  fi

  PLUGIN_VERSION=$(jq -r '.version // empty' "$PLUGIN_JSON" 2>/dev/null)
  if [ -n "$PLUGIN_VERSION" ]; then
    pass "plugin.json has 'version' field: '$PLUGIN_VERSION'"
  else
    fail "plugin.json missing 'version' field"
  fi

  # Version should be a semver-like string (not empty or garbage)
  if echo "$PLUGIN_VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+'; then
    pass "plugin.json version is semver-like: '$PLUGIN_VERSION'"
  else
    fail "plugin.json version is not semver-like: '$PLUGIN_VERSION'"
  fi
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-8: No platform markers in ANY file
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-8: No platform markers ==="

echo "--- No <!-- platform: markers in any file recursively ---"

PLATFORM_MARKER_FILES=$(grep -rl '<!-- platform:' "$CC_DIST" 2>/dev/null || true)
if [ -z "$PLATFORM_MARKER_FILES" ]; then
  pass "no files contain '<!-- platform:' markers"
else
  FILE_COUNT=$(echo "$PLATFORM_MARKER_FILES" | wc -l | tr -d ' ')
  fail "$FILE_COUNT file(s) still contain platform markers:"
  echo "$PLATFORM_MARKER_FILES" | head -5 | sed 's/^/      /'
fi

# Also check for the closing marker pattern
PLATFORM_END_FILES=$(grep -rl '<!-- /platform:' "$CC_DIST" 2>/dev/null || true)
if [ -z "$PLATFORM_END_FILES" ]; then
  pass "no files contain '<!-- /platform:' closing markers"
else
  FILE_COUNT=$(echo "$PLATFORM_END_FILES" | wc -l | tr -d ' ')
  fail "$FILE_COUNT file(s) still contain platform closing markers"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-9: sw-build content verification
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-9: sw-build content ==="

CC_BUILD_SKILL="$CC_DIST/skills/sw-build/SKILL.md"

echo "--- (a) Frontmatter has Task CRUD tools ---"

if [ -f "$CC_BUILD_SKILL" ]; then
  BUILD_FM=$(extract_frontmatter "$CC_BUILD_SKILL" || true)
  BUILD_TOOLS=$(extract_allowed_tools "$BUILD_FM")

  for task_tool in TaskCreate TaskUpdate TaskList TaskGet; do
    if echo "$BUILD_TOOLS" | grep -qx "$task_tool"; then
      pass "sw-build frontmatter has '$task_tool' in allowed-tools"
    else
      fail "sw-build frontmatter missing '$task_tool' in allowed-tools"
    fi
  done
else
  fail "sw-build/SKILL.md not found"
fi

echo "--- (b) Body has 'Task tracking' ---"

if [ -f "$CC_BUILD_SKILL" ]; then
  BUILD_BODY=$(extract_body "$CC_BUILD_SKILL" || true)

  if echo "$BUILD_BODY" | grep -q "Task tracking"; then
    pass "sw-build body contains 'Task tracking'"
  else
    fail "sw-build body missing 'Task tracking'"
  fi
fi

echo "--- (c) Body has 'Mid-build checks' ---"

if [ -f "$CC_BUILD_SKILL" ]; then
  BUILD_BODY=$(extract_body "$CC_BUILD_SKILL" || true)

  if echo "$BUILD_BODY" | grep -q "Mid-build checks"; then
    pass "sw-build body contains 'Mid-build checks'"
  else
    fail "sw-build body missing 'Mid-build checks'"
  fi
fi

echo "--- sw-build preserves TDD content ---"

if [ -f "$CC_BUILD_SKILL" ]; then
  BUILD_BODY=$(extract_body "$CC_BUILD_SKILL" || true)

  for tdd_term in "RED" "GREEN" "REFACTOR" "specwright-tester" "specwright-executor"; do
    if echo "$BUILD_BODY" | grep -q "$tdd_term"; then
      pass "sw-build body contains '$tdd_term'"
    else
      fail "sw-build body missing '$tdd_term'"
    fi
  done
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-12: Retro refinements content verification
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-12: Retro refinements ==="

echo "--- (a) gate-security Phase 3 ---"

CC_GATE_SEC="$CC_DIST/skills/gate-security/SKILL.md"
if [ -f "$CC_GATE_SEC" ]; then
  SEC_BODY=$(extract_body "$CC_GATE_SEC" || true)
  for sec_term in "Phase 3" "CWE-636" "CWE-209" "CWE-306"; do
    if echo "$SEC_BODY" | grep -q "$sec_term"; then
      pass "gate-security body contains '$sec_term'"
    else
      fail "gate-security body missing '$sec_term'"
    fi
  done
else
  fail "gate-security/SKILL.md not found"
fi

echo "--- (b) Executor grounding ---"

CC_EXECUTOR="$CC_DIST/agents/specwright-executor.md"
if [ -f "$CC_EXECUTOR" ]; then
  EXEC_BODY=$(cat "$CC_EXECUTOR")
  for exec_term in "verify that types" "Discrepancies"; do
    if echo "$EXEC_BODY" | grep -q "$exec_term"; then
      pass "executor contains '$exec_term'"
    else
      fail "executor missing '$exec_term'"
    fi
  done
else
  fail "specwright-executor.md not found"
fi

echo "--- (c) sw-learn mandatory calibration ---"

CC_LEARN="$CC_DIST/skills/sw-learn/SKILL.md"
if [ -f "$CC_LEARN" ]; then
  LEARN_BODY=$(extract_body "$CC_LEARN" || true)
  if echo "$LEARN_BODY" | grep -q "MUST record gateCalibration"; then
    pass "sw-learn contains 'MUST record gateCalibration'"
  else
    fail "sw-learn missing 'MUST record gateCalibration'"
  fi
else
  fail "sw-learn/SKILL.md not found"
fi

echo "--- (d) evidence protocol carries verdict calibration rules ---"

CC_EVIDENCE="$CC_DIST/protocols/evidence.md"
if [ -f "$CC_EVIDENCE" ]; then
  if grep -q "## Verdict Rendering" "$CC_EVIDENCE"; then
    pass "evidence contains '## Verdict Rendering'"
  else
    fail "evidence missing '## Verdict Rendering'"
  fi
  if grep -q "mandatory" "$CC_EVIDENCE"; then
    pass "evidence contains 'mandatory'"
  else
    fail "evidence missing 'mandatory'"
  fi
else
  fail "evidence.md not found"
fi

echo "--- (e) sw-build discrepancy handling ---"

if [ -f "$CC_BUILD_SKILL" ]; then
  if grep -q "plan mismatch" "$CC_BUILD_SKILL"; then
    pass "sw-build contains 'plan mismatch' discrepancy handling"
  else
    fail "sw-build missing 'plan mismatch' discrepancy handling"
  fi
else
  fail "sw-build/SKILL.md not found (AC-12e)"
fi

echo "--- (f) gate-semantic exists and has required sections ---"

CC_GATE_SEM="$CC_DIST/skills/gate-semantic/SKILL.md"
if [ -f "$CC_GATE_SEM" ]; then
  SEM_FM=$(extract_frontmatter "$CC_GATE_SEM" || true)
  SEM_NAME=$(echo "$SEM_FM" | grep -E '^name:' | sed 's/^name:\s*//' | xargs)
  assert_eq "$SEM_NAME" "gate-semantic" "gate-semantic frontmatter has name: gate-semantic"

  SEM_BODY=$(extract_body "$CC_GATE_SEM" || true)
  for sem_section in "Goal" "Inputs" "Outputs" "Constraints" "Failure Modes"; do
    if echo "$SEM_BODY" | grep -q "## $sem_section"; then
      pass "gate-semantic body contains '## $sem_section'"
    else
      fail "gate-semantic body missing '## $sem_section'"
    fi
  done

  for sem_term in "error-path-cleanup" "unchecked-errors" "WARN" "evidence.md"; do
    if echo "$SEM_BODY" | grep -qi "$sem_term"; then
      pass "gate-semantic body contains '$sem_term'"
    else
      fail "gate-semantic body missing '$sem_term'"
    fi
  done
else
  fail "gate-semantic/SKILL.md not found"
fi

echo "--- (g) sw-verify references gate-semantic ---"

CC_VERIFY="$CC_DIST/skills/sw-verify/SKILL.md"
if [ -f "$CC_VERIFY" ]; then
  if grep -q "gate-semantic" "$CC_VERIFY"; then
    pass "sw-verify references gate-semantic"
  else
    fail "sw-verify does not reference gate-semantic"
  fi
else
  fail "sw-verify/SKILL.md not found (AC-12g)"
fi

echo "--- (h) no semi-formal protocol references remain ---"

if grep -r "semi-formal-reasoning" "$CC_DIST"/skills "$CC_DIST"/agents "$CC_DIST/CLAUDE.md" >/dev/null 2>&1; then
  fail "dist output still references semi-formal-reasoning"
else
  pass "dist output has no semi-formal-reasoning references"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-10: No opencode artifacts
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-10: No opencode artifacts ==="

echo "--- No commands/ directory ---"

if [ -d "$CC_DIST/commands" ]; then
  fail "dist/claude-code/commands/ exists but should NOT (opencode-specific)"
else
  pass "no commands/ directory in dist/claude-code/"
fi

echo "--- No package.json ---"

if [ -f "$CC_DIST/package.json" ]; then
  fail "dist/claude-code/package.json exists but should NOT (opencode-specific)"
else
  pass "no package.json in dist/claude-code/"
fi

echo "--- No plugin.ts ---"

if [ -f "$CC_DIST/plugin.ts" ]; then
  fail "dist/claude-code/plugin.ts exists but should NOT (opencode-specific)"
else
  pass "no plugin.ts in dist/claude-code/"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-14: Normal test path executes the runtime harness
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-14: Multi-worktree runtime harness ==="

if [ -x "$MULTI_WORKTREE_RUNTIME_TEST" ]; then
  pass "tests/test-multi-worktree-state.sh is executable"
else
  fail "tests/test-multi-worktree-state.sh is missing or not executable"
fi

HARNESS_EXIT=0
HARNESS_OUTPUT="$(bash "$MULTI_WORKTREE_RUNTIME_TEST" 2>&1)" || HARNESS_EXIT=$?

if [ "$HARNESS_EXIT" -ne 0 ]; then
  fail "tests/test-multi-worktree-state.sh fails under the configured test path"
  echo "  Harness output:"
  printf '    %s\n' "${HARNESS_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-multi-worktree-state.sh passes under the configured test path"
fi
if echo "$HARNESS_OUTPUT" | grep -Fq "AC-2: same-work attachment surfaces adopt/takeover guidance"; then
  pass "runtime harness output includes same-work takeover coverage"
else
  fail "runtime harness output missing same-work takeover coverage"
fi
if echo "$HARNESS_OUTPUT" | grep -Fq "IC-B2: status view reports attached work and repo-active owners"; then
  pass "runtime harness output includes sw-status repo-active ownership coverage"
else
  fail "runtime harness output missing sw-status repo-active ownership coverage"
fi

echo ""
echo "=== Supplemental regression: Branch freshness target-model docs ==="

if [ -x "$TARGET_MODEL_DOCS_TEST" ]; then
  pass "tests/test-branch-freshness-target-model-docs.sh is executable"
else
  fail "tests/test-branch-freshness-target-model-docs.sh is missing or not executable"
fi

TARGET_MODEL_EXIT=0
TARGET_MODEL_OUTPUT="$(bash "$TARGET_MODEL_DOCS_TEST" 2>&1)" || TARGET_MODEL_EXIT=$?

if [ "$TARGET_MODEL_EXIT" -ne 0 ]; then
  fail "tests/test-branch-freshness-target-model-docs.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${TARGET_MODEL_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-branch-freshness-target-model-docs.sh passes under the configured test path"
fi
if echo "$TARGET_MODEL_OUTPUT" | grep -Fq "workflow schema adds targetRef object"; then
  pass "target-model regression output includes targetRef schema coverage"
else
  fail "target-model regression output missing targetRef schema coverage"
fi

echo ""
echo "=== Supplemental regression: Git freshness engine ==="

if [ -x "$GIT_FRESHNESS_ENGINE_TEST" ]; then
  pass "tests/test-git-freshness-engine.sh is executable"
else
  fail "tests/test-git-freshness-engine.sh is missing or not executable"
fi

GIT_FRESHNESS_EXIT=0
GIT_FRESHNESS_OUTPUT="$(bash "$GIT_FRESHNESS_ENGINE_TEST" 2>&1)" || GIT_FRESHNESS_EXIT=$?

if [ "$GIT_FRESHNESS_EXIT" -ne 0 ]; then
  fail "tests/test-git-freshness-engine.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${GIT_FRESHNESS_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-git-freshness-engine.sh passes under the configured test path"
fi
if echo "$GIT_FRESHNESS_OUTPUT" | grep -Fq "protocol names clone-local runtime state explicitly"; then
  pass "git-freshness regression output includes storage-boundary coverage"
else
  fail "git-freshness regression output missing storage-boundary coverage"
fi

echo ""
echo "=== Supplemental regression: Lifecycle freshness checkpoints ==="

if [ -x "$LIFECYCLE_FRESHNESS_TEST" ]; then
  pass "tests/test-lifecycle-freshness-checkpoints.sh is executable"
else
  fail "tests/test-lifecycle-freshness-checkpoints.sh is missing or not executable"
fi

LIFECYCLE_FRESHNESS_EXIT=0
LIFECYCLE_FRESHNESS_OUTPUT="$(bash "$LIFECYCLE_FRESHNESS_TEST" 2>&1)" || LIFECYCLE_FRESHNESS_EXIT=$?

if [ "$LIFECYCLE_FRESHNESS_EXIT" -ne 0 ]; then
  fail "tests/test-lifecycle-freshness-checkpoints.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${LIFECYCLE_FRESHNESS_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-lifecycle-freshness-checkpoints.sh passes under the configured test path"
fi
if echo "$LIFECYCLE_FRESHNESS_OUTPUT" | grep -Fq "PASS: sw-build forbids hidden branch rewrites"; then
  pass "lifecycle regression output includes rewrite-guard coverage"
else
  fail "lifecycle regression output missing rewrite-guard coverage"
fi

echo ""
echo "=== Supplemental regression: Config validation and visibility docs ==="

if [ -x "$CONFIG_VISIBILITY_DOCS_TEST" ]; then
  pass "tests/test-config-validation-visibility-docs.sh is executable"
else
  fail "tests/test-config-validation-visibility-docs.sh is missing or not executable"
fi

CONFIG_VISIBILITY_EXIT=0
CONFIG_VISIBILITY_OUTPUT="$(bash "$CONFIG_VISIBILITY_DOCS_TEST" 2>&1)" || CONFIG_VISIBILITY_EXIT=$?

if [ "$CONFIG_VISIBILITY_EXIT" -ne 0 ]; then
  fail "tests/test-config-validation-visibility-docs.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${CONFIG_VISIBILITY_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-config-validation-visibility-docs.sh passes under the configured test path"
fi
if echo "$CONFIG_VISIBILITY_OUTPUT" | grep -Fq "PASS: sw-sync stays advisory on reconcile and ship decisions"; then
  pass "config-visibility regression output includes sync-boundary coverage"
else
  fail "config-visibility regression output missing sync-boundary coverage"
fi

echo ""
echo "=== Supplemental regression: Workflow proof ==="

if [ -x "$WORKFLOW_PROOF_TEST" ]; then
  pass "tests/test-workflow-proof.sh is executable"
else
  fail "tests/test-workflow-proof.sh is missing or not executable"
fi

WORKFLOW_PROOF_EXIT=0
# Smoke mode keeps the default structural path fast while still proving that
# workflow-proof coverage executes and carries queue-managed shipping markers.
WORKFLOW_PROOF_OUTPUT="$(SPECWRIGHT_WORKFLOW_PROOF_MODE=smoke bash "$WORKFLOW_PROOF_TEST" 2>&1)" || WORKFLOW_PROOF_EXIT=$?

if [ "$WORKFLOW_PROOF_EXIT" -ne 0 ]; then
  fail "tests/test-workflow-proof.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${WORKFLOW_PROOF_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-workflow-proof.sh passes under the configured test path"
fi
if [ "$WORKFLOW_PROOF_EXIT" -eq 0 ] && echo "$WORKFLOW_PROOF_OUTPUT" | grep -Fq "COVERAGE: workflow-proof.queue-managed-ship"; then
  pass "workflow-proof regression output includes queue-managed ship coverage"
else
  fail "workflow-proof regression output missing queue-managed ship coverage"
fi

echo ""
echo "=== Supplemental regression: Audit-chain root model ==="

if [ -x "$AUDIT_CHAIN_ROOT_MODEL_TEST" ]; then
  pass "tests/test-audit-chain-root-model.sh is executable"
else
  fail "tests/test-audit-chain-root-model.sh is missing or not executable"
fi

AUDIT_CHAIN_ROOT_MODEL_EXIT=0
AUDIT_CHAIN_ROOT_MODEL_OUTPUT="$(bash "$AUDIT_CHAIN_ROOT_MODEL_TEST" 2>&1)" || AUDIT_CHAIN_ROOT_MODEL_EXIT=$?

if [ "$AUDIT_CHAIN_ROOT_MODEL_EXIT" -ne 0 ]; then
  fail "tests/test-audit-chain-root-model.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${AUDIT_CHAIN_ROOT_MODEL_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-audit-chain-root-model.sh passes under the configured test path"
fi
if echo "$AUDIT_CHAIN_ROOT_MODEL_OUTPUT" | grep -Fq "PASS: tracked mode routes spec paths through configured workArtifactsRoot"; then
  pass "audit-chain root-model regression output includes tracked-root coverage"
else
  fail "audit-chain root-model regression output missing tracked-root coverage"
fi

echo ""
echo "=== Supplemental regression: Audit-chain workflow proof ==="

if [ -x "$AUDIT_CHAIN_WORKFLOW_PROOF_TEST" ]; then
  pass "tests/test-audit-chain-workflow-proof.sh is executable"
else
  fail "tests/test-audit-chain-workflow-proof.sh is missing or not executable"
fi

AUDIT_CHAIN_WORKFLOW_EXIT=0
AUDIT_CHAIN_WORKFLOW_OUTPUT="$(bash "$AUDIT_CHAIN_WORKFLOW_PROOF_TEST" 2>&1)" || AUDIT_CHAIN_WORKFLOW_EXIT=$?

if [ "$AUDIT_CHAIN_WORKFLOW_EXIT" -ne 0 ]; then
  fail "tests/test-audit-chain-workflow-proof.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${AUDIT_CHAIN_WORKFLOW_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-audit-chain-workflow-proof.sh passes under the configured test path"
fi
if [ "$AUDIT_CHAIN_WORKFLOW_EXIT" -eq 0 ] && echo "$AUDIT_CHAIN_WORKFLOW_OUTPUT" | grep -Fq "COVERAGE: audit-chain.workflow-proof"; then
  pass "audit-chain workflow proof output includes lifecycle coverage"
else
  fail "audit-chain workflow proof output missing lifecycle coverage"
fi

echo ""
echo "=== Supplemental regression: Audit-chain migration surfaces ==="

if [ -x "$AUDIT_CHAIN_MIGRATION_SURFACES_TEST" ]; then
  pass "tests/test-audit-chain-migration-surfaces.sh is executable"
else
  fail "tests/test-audit-chain-migration-surfaces.sh is missing or not executable"
fi

AUDIT_CHAIN_MIGRATION_EXIT=0
AUDIT_CHAIN_MIGRATION_OUTPUT="$(bash "$AUDIT_CHAIN_MIGRATION_SURFACES_TEST" 2>&1)" || AUDIT_CHAIN_MIGRATION_EXIT=$?

if [ "$AUDIT_CHAIN_MIGRATION_EXIT" -ne 0 ]; then
  fail "tests/test-audit-chain-migration-surfaces.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${AUDIT_CHAIN_MIGRATION_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-audit-chain-migration-surfaces.sh passes under the configured test path"
fi
if [ "$AUDIT_CHAIN_MIGRATION_EXIT" -eq 0 ] && echo "$AUDIT_CHAIN_MIGRATION_OUTPUT" | grep -Fq "COVERAGE: audit-chain.migration-surfaces"; then
  pass "audit-chain migration surfaces output includes publication-mode coverage"
else
  fail "audit-chain migration surfaces output missing publication-mode coverage"
fi

echo ""
echo "=== Supplemental regression: Approval lifecycle ==="

if [ -x "$APPROVAL_LIFECYCLE_TEST" ]; then
  pass "tests/test-approval-lifecycle-docs.sh is executable"
else
  fail "tests/test-approval-lifecycle-docs.sh is missing or not executable"
fi

APPROVAL_LIFECYCLE_EXIT=0
APPROVAL_LIFECYCLE_OUTPUT="$(SPECWRIGHT_APPROVAL_LIFECYCLE_MODE=smoke bash "$APPROVAL_LIFECYCLE_TEST" 2>&1)" || APPROVAL_LIFECYCLE_EXIT=$?

if [ "$APPROVAL_LIFECYCLE_EXIT" -ne 0 ]; then
  fail "tests/test-approval-lifecycle-docs.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${APPROVAL_LIFECYCLE_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-approval-lifecycle-docs.sh passes under the configured test path"
fi
if [ "$APPROVAL_LIFECYCLE_EXIT" -eq 0 ] && echo "$APPROVAL_LIFECYCLE_OUTPUT" | grep -Fq "COVERAGE: approval-lifecycle.fail-closed"; then
  pass "approval-lifecycle regression output includes fail-closed approval coverage"
else
  fail "approval-lifecycle regression output missing fail-closed approval coverage"
fi

echo ""
echo "=== Supplemental regression: Review packet docs ==="

if [ -x "$REVIEW_PACKET_DOCS_TEST" ]; then
  pass "tests/test-review-packet-docs.sh is executable"
else
  fail "tests/test-review-packet-docs.sh is missing or not executable"
fi

REVIEW_PACKET_EXIT=0
REVIEW_PACKET_OUTPUT="$(bash "$REVIEW_PACKET_DOCS_TEST" 2>&1)" || REVIEW_PACKET_EXIT=$?

if [ "$REVIEW_PACKET_EXIT" -ne 0 ]; then
  fail "tests/test-review-packet-docs.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${REVIEW_PACKET_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-review-packet-docs.sh passes under the configured test path"
fi
if echo "$REVIEW_PACKET_OUTPUT" | grep -Fq "COVERAGE: review-packet.clone-local-guard"; then
  pass "review-packet regression output includes clone-local reviewer guard coverage"
else
  fail "review-packet regression output missing clone-local reviewer guard coverage"
fi

echo ""
echo "=== Supplemental regression: Support surface cutover docs ==="

if [ -x "$SUPPORT_SURFACE_CUTOVER_TEST" ]; then
  pass "tests/test-support-surface-cutover-docs.sh is executable"
else
  fail "tests/test-support-surface-cutover-docs.sh is missing or not executable"
fi

SUPPORT_SURFACE_EXIT=0
SUPPORT_SURFACE_OUTPUT="$(bash "$SUPPORT_SURFACE_CUTOVER_TEST" 2>&1)" || SUPPORT_SURFACE_EXIT=$?

if [ "$SUPPORT_SURFACE_EXIT" -ne 0 ]; then
  fail "tests/test-support-surface-cutover-docs.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${SUPPORT_SURFACE_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-support-surface-cutover-docs.sh passes under the configured test path"
fi
if [ "$SUPPORT_SURFACE_EXIT" -eq 0 ] && echo "$SUPPORT_SURFACE_OUTPUT" | grep -Fq "COVERAGE: support-surface.publication-mode-cutover"; then
  pass "support-surface regression output includes publication-mode cutover coverage"
else
  fail "support-surface regression output missing publication-mode cutover coverage"
fi

echo ""
echo "=== Supplemental regression: Operator-surface workflow proof ==="

OPERATOR_SURFACE_WORKFLOW_PROOF_EXIT=0
OPERATOR_SURFACE_WORKFLOW_PROOF_OUTPUT="$(run_operator_surface_workflow_proof_regression 2>&1)" || OPERATOR_SURFACE_WORKFLOW_PROOF_EXIT=$?

if [ "$OPERATOR_SURFACE_WORKFLOW_PROOF_EXIT" -ne 0 ]; then
  fail "operator-surface workflow proof regression fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${OPERATOR_SURFACE_WORKFLOW_PROOF_OUTPUT//$'\n'/$'\n    '}"
else
  pass "operator-surface workflow proof regression passes under the configured test path"
fi
if [ "$OPERATOR_SURFACE_WORKFLOW_PROOF_EXIT" -eq 0 ] && echo "$OPERATOR_SURFACE_WORKFLOW_PROOF_OUTPUT" | grep -Fq "COVERAGE: workflow-proof.operator-surface"; then
  pass "operator-surface workflow proof output includes runtime and verify-strictness coverage"
else
  fail "operator-surface workflow proof output missing runtime and verify-strictness coverage"
fi

echo ""
echo "=== Supplemental regression: Verify mutation proof surfaces ==="

if [ -x "$VERIFY_MUTATION_PROOF_TEST" ]; then
  pass "tests/test-verify-mutation-proof.sh is executable"
else
  fail "tests/test-verify-mutation-proof.sh is missing or not executable"
fi

VERIFY_MUTATION_PROOF_EXIT=0
VERIFY_MUTATION_PROOF_OUTPUT="$(bash "$VERIFY_MUTATION_PROOF_TEST" 2>&1)" || VERIFY_MUTATION_PROOF_EXIT=$?

if [ "$VERIFY_MUTATION_PROOF_EXIT" -ne 0 ]; then
  fail "tests/test-verify-mutation-proof.sh fails under the configured test path"
  echo "  Regression output:"
  printf '    %s\n' "${VERIFY_MUTATION_PROOF_OUTPUT//$'\n'/$'\n    '}"
else
  pass "tests/test-verify-mutation-proof.sh passes under the configured test path"
fi
if [ "$VERIFY_MUTATION_PROOF_EXIT" -eq 0 ] && echo "$VERIFY_MUTATION_PROOF_OUTPUT" | grep -Fq "COVERAGE: verify-mutation.proof-surfaces"; then
  pass "verify mutation proof output includes surface coverage"
else
  fail "verify mutation proof output missing surface coverage"
fi

# ═══════════════════════════════════════════════════════════════════════
# AC-11: Source files not modified by build
# ═══════════════════════════════════════════════════════════════════════

echo ""
echo "=== AC-11: Source files not modified ==="

echo "--- Core skill files unchanged ---"

# core/skills/sw-init/SKILL.md still has Read uppercase
if [ -f "$ROOT_DIR/core/skills/sw-init/SKILL.md" ]; then
  CORE_INIT_FM=$(extract_frontmatter "$ROOT_DIR/core/skills/sw-init/SKILL.md" || true)
  CORE_INIT_TOOLS=$(extract_allowed_tools "$CORE_INIT_FM")

  if echo "$CORE_INIT_TOOLS" | grep -qx "Read"; then
    pass "core/skills/sw-init/SKILL.md still has 'Read' uppercase (not modified)"
  else
    fail "core/skills/sw-init/SKILL.md 'Read' is gone (build modified source!)"
  fi

  if echo "$CORE_INIT_TOOLS" | grep -qx "Write"; then
    pass "core/skills/sw-init/SKILL.md still has 'Write' uppercase (not modified)"
  else
    fail "core/skills/sw-init/SKILL.md 'Write' is gone (build modified source!)"
  fi

  if echo "$CORE_INIT_TOOLS" | grep -qx "Bash"; then
    pass "core/skills/sw-init/SKILL.md still has 'Bash' uppercase (not modified)"
  else
    fail "core/skills/sw-init/SKILL.md 'Bash' is gone (build modified source!)"
  fi
fi

echo "--- Core agent files unchanged ---"

# core/agents/specwright-tester.md still has opus shorthand
if [ -f "$ROOT_DIR/core/agents/specwright-tester.md" ]; then
  CORE_TESTER_FM=$(extract_frontmatter "$ROOT_DIR/core/agents/specwright-tester.md" || true)
  CORE_TESTER_MODEL=$(echo "$CORE_TESTER_FM" | grep -E '^model:' | sed 's/^model:\s*//' | xargs)
  assert_eq "$CORE_TESTER_MODEL" "opus" "core/agents/specwright-tester.md still has 'opus' shorthand (not modified)"
fi

# Core agents should NOT have mode: subagent added
if [ -f "$ROOT_DIR/core/agents/specwright-tester.md" ]; then
  CORE_TESTER_FM=$(extract_frontmatter "$ROOT_DIR/core/agents/specwright-tester.md" || true)
  if echo "$CORE_TESTER_FM" | grep -qE '^mode:\s*subagent'; then
    fail "core/agents/specwright-tester.md has mode:subagent (build modified source!)"
  else
    pass "core/agents/specwright-tester.md does NOT have mode:subagent (not modified)"
  fi
fi

echo "--- Core and adapter source integrity (git diff) ---"

POST_BUILD_SOURCE_STATUS=$(git_source_status)
if [ "$POST_BUILD_SOURCE_STATUS" = "$PRE_BUILD_SOURCE_STATUS" ]; then
  pass "build left core/ and adapters/ source state unchanged"
else
  fail "build changed core/ or adapters/ source state relative to pre-build snapshot"
fi

if [ "$HARNESS_EXIT" -ne 0 ]; then
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed (runtime harness failed)"
  rm -rf "$DIST_DIR"
  exit 1
fi

# ─── Cleanup ─────────────────────────────────────────────────────────

echo ""
echo "--- Cleanup ---"
rm -rf "$DIST_DIR"
echo "  INFO: dist/ cleaned up"

# ─── Summary ─────────────────────────────────────────────────────────

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
