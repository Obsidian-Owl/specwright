#!/usr/bin/env bash
#
# Regression checks for the sw-sync skill under the shared/session state model.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/sw-sync/SKILL.md"

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

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    fail "$label"
  else
    pass "$label"
  fi
}

extract_frontmatter() {
  local file="$1"
  awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR == 1 { next }
    $0 == "---" { exit 0 }
    { print }
  ' "$file"
}

extract_body() {
  local file="$1"
  awk '
    NR == 1 && $0 != "---" { exit 1 }
    NR == 1 { in_body = 0; next }
    $0 == "---" && in_body == 0 { in_body = 1; next }
    in_body == 1 { print }
  ' "$file"
}

echo "=== sw-sync shared/session regression ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "sw-sync skill file exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

FRONTMATTER="$(extract_frontmatter "$SKILL_FILE")" || {
  fail "skill frontmatter parses"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
}

BODY="$(extract_body "$SKILL_FILE")" || {
  fail "skill body parses"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
}

echo "--- Anatomy ---"
if echo "$FRONTMATTER" | grep -Fq "name: sw-sync"; then
  pass "frontmatter names sw-sync"
else
  fail "frontmatter names sw-sync"
fi

for required_tool in Read Bash Glob AskUserQuestion; do
  if echo "$FRONTMATTER" | grep -Fq "  - $required_tool"; then
    pass "allowed-tools includes $required_tool"
  else
    fail "allowed-tools includes $required_tool"
  fi
done

if echo "$FRONTMATTER" | grep -Fq "  - Write"; then
  fail "allowed-tools excludes Write"
else
  pass "allowed-tools excludes Write"
fi

for section in "## Goal" "## Inputs" "## Outputs" "## Constraints" "## Protocol References" "## Failure Modes"; do
  if echo "$BODY" | grep -Fq "$section"; then
    pass "has section $section"
  else
    fail "has section $section"
  fi
done

echo ""
echo "--- Shared/session inputs ---"
assert_contains "$SKILL_FILE" '{projectArtifactsRoot}/config.json' "uses tracked project config path"
assert_contains "$SKILL_FILE" '{worktreeStateRoot}/session.json' "uses per-worktree session path"
assert_contains "$SKILL_FILE" '{repoStateRoot}/work/*/workflow.json' "uses per-work workflow enumeration"

echo ""
echo "--- Branch protection rules ---"
assert_contains "$SKILL_FILE" 'git fetch --all --prune' "fetches all remotes with prune"
assert_contains "$SKILL_FILE" 'git worktree list --porcelain' "uses worktree porcelain output"
assert_contains "$SKILL_FILE" 'live sessions' "protects branches claimed by live sessions"
assert_contains "$SKILL_FILE" 'subordinate helper worktree' "protects subordinate helper branches"
assert_contains "$SKILL_FILE" 'workflow.json.branch' "protects branches recorded on works"
assert_contains "$SKILL_FILE" 'cleanupBranch' "honors cleanupBranch gate"
assert_contains "$SKILL_FILE" 'git check-ref-format --branch' "documents git ref-format validation"
assert_contains "$SKILL_FILE" 'shell metacharacters' "documents injection-oriented branch validation"
assert_contains "$SKILL_FILE" 'skip deletion and report candidates only' "documents headless report-only deletion behavior"

echo ""
echo "--- Singleton drift guards ---"
assert_not_contains "$SKILL_FILE" '.specwright/config.json' "does not reference legacy tracked config path directly"
assert_not_contains "$SKILL_FILE" '.specwright/state/workflow.json' "does not reference legacy singleton workflow path"
assert_not_contains "$SKILL_FILE" 'currentWork.branch' "does not rely on currentWork.branch"
assert_not_contains "$SKILL_FILE" 'active feature branch reference' "does not describe the old active-feature-branch shortcut"

echo ""
echo "--- Sanity ---"
WORD_COUNT="$(wc -w < "$SKILL_FILE" | tr -d ' ')"
if [ "$WORD_COUNT" -ge 200 ] && [ "$WORD_COUNT" -lt 1500 ]; then
  pass "word count stays within the expected skill range ($WORD_COUNT)"
else
  fail "word count stays within the expected skill range ($WORD_COUNT)"
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
