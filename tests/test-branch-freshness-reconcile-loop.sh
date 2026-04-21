#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Integrated proof for lifecycle-owned or CI-owned freshness recovery across
# build, verify, ship, shared protocols, public operator docs, command blurbs,
# and eval prompt templates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
FRESHNESS_PROTOCOL="$ROOT_DIR/core/protocols/git-freshness.md"
RECONCILE_PROTOCOL="$ROOT_DIR/core/protocols/git-reconcile.md"
CLAUDE_DOC="$ROOT_DIR/CLAUDE.md"
ADAPTER_CLAUDE_DOC="$ROOT_DIR/adapters/claude-code/CLAUDE.md"
README_DOC="$ROOT_DIR/README.md"
DESIGN_DOC="$ROOT_DIR/DESIGN.md"
CODEX_BUILD_CMD="$ROOT_DIR/adapters/codex/commands/sw-build.md"
CODEX_VERIFY_CMD="$ROOT_DIR/adapters/codex/commands/sw-verify.md"
CODEX_SHIP_CMD="$ROOT_DIR/adapters/codex/commands/sw-ship.md"
OPENCODE_BUILD_CMD="$ROOT_DIR/adapters/opencode/commands/sw-build.md"
OPENCODE_VERIFY_CMD="$ROOT_DIR/adapters/opencode/commands/sw-verify.md"
OPENCODE_SHIP_CMD="$ROOT_DIR/adapters/opencode/commands/sw-ship.md"
PROMPTS_FILE="$ROOT_DIR/evals/framework/prompts.py"

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

emit_coverage_marker() {
  printf 'COVERAGE: %s\n' "$1"
}

assert_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_regex() {
  local file="$1" pattern="$2" label="$3"
  if python - "$file" "$pattern" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
raise SystemExit(0 if re.search(pattern, text, re.IGNORECASE | re.DOTALL) else 1)
PY
  then
    pass "$label"
  else
    fail "$label (pattern not found: $pattern)"
  fi
}

assert_not_regex() {
  local file="$1" pattern="$2" label="$3"
  if python - "$file" "$pattern" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
raise SystemExit(0 if re.search(pattern, text, re.IGNORECASE | re.DOTALL) else 1)
PY
  then
    fail "$label (unexpected pattern found: $pattern)"
  else
    pass "$label"
  fi
}

echo "=== branch freshness recovery proof ==="
echo ""

for file in \
  "$BUILD_SKILL" \
  "$VERIFY_SKILL" \
  "$SHIP_SKILL" \
  "$FRESHNESS_PROTOCOL" \
  "$RECONCILE_PROTOCOL" \
  "$CLAUDE_DOC" \
  "$ADAPTER_CLAUDE_DOC" \
  "$README_DOC" \
  "$DESIGN_DOC" \
  "$CODEX_BUILD_CMD" \
  "$CODEX_VERIFY_CMD" \
  "$CODEX_SHIP_CMD" \
  "$OPENCODE_BUILD_CMD" \
  "$OPENCODE_VERIFY_CMD" \
  "$OPENCODE_SHIP_CMD" \
  "$PROMPTS_FILE"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Stage-specific recovery ---"
assert_contains "$BUILD_SKILL" "continue in the same stage after a successful reconcile" "sw-build keeps successful reconcile inside build"
assert_regex "$VERIFY_SKILL" 'Do not redirect to[\s\S]{0,20}`/sw-build` solely[\s\S]{0,40}clear freshness' "sw-verify explicitly forbids bouncing back to build for freshness-only stops"
assert_contains "$VERIFY_SKILL" "continue gate execution in that same verify run" "sw-verify keeps successful reconcile inside verify"
assert_contains "$SHIP_SKILL" "continue shipping in that same run" "sw-ship keeps successful reconcile inside ship"
assert_contains "$SHIP_SKILL" "| Shipping freshness checkpoint is blocked under branch-head \`require\` + \`manual\` | STOP with manual reconcile guidance, rerun \`/sw-verify\`, then rerun \`/sw-ship\`. |" "sw-ship keeps the manual verify-then-ship exception explicit"
assert_regex "$SHIP_SKILL" 'Do not silently rewrite[\s\S]{0,120}`targetRef` or freshness metadata to bypass the[\s\S]{0,20}block' "sw-ship preserves fail-closed freshness state"

echo ""
echo "--- Shared protocol contract ---"
assert_contains "$FRESHNESS_PROTOCOL" "skills may invoke \`git-reconcile\` inside the blocked stage" "git-freshness routes lifecycle-owned recovery through the reconcile protocol"
assert_contains "$FRESHNESS_PROTOCOL" "silently routing through a different stage; shipping is the exception because" "git-freshness encodes the shipping-only verify-then-ship exception"
assert_contains "$FRESHNESS_PROTOCOL" "require adopt/takeover before reconciling there" "git-freshness keeps linked-worktree ownership conflicts fail-closed"
assert_contains "$RECONCILE_PROTOCOL" "dirty worktree state is fail-closed" "git-reconcile keeps dirty worktrees fail-closed"
assert_contains "$RECONCILE_PROTOCOL" "Queue-managed validation is not a local reconcile mode" "git-reconcile preserves queue-managed no-local-rewrite semantics"

echo ""
echo "--- Public operator docs ---"
for file in "$CLAUDE_DOC" "$ADAPTER_CLAUDE_DOC" "$README_DOC" "$DESIGN_DOC"; do
  label="${file#"$ROOT_DIR"/}"
  assert_regex "$file" 'rebase[\s\S]{0,20}merge[\s\S]{0,180}same[\s\S]{0,20}(stage|run)' "$label documents lifecycle-owned rebase or merge recovery"
  assert_regex "$file" 'manual[\s\S]{0,80}fallback[\s\S]{0,160}owning worktree' "$label keeps manual recovery as an owning-worktree fallback"
  assert_not_regex "$file" 'manual reconcile[\s\S]{0,240}/sw-build[\s\S]{0,120}/sw-verify[\s\S]{0,160}/sw-ship' "$label no longer advertises the manual rerun sequence as the main story"
done

echo ""
echo "--- Command and prompt surfaces ---"
for file in \
  "$CODEX_BUILD_CMD" \
  "$CODEX_VERIFY_CMD" \
  "$CODEX_SHIP_CMD" \
  "$OPENCODE_BUILD_CMD" \
  "$OPENCODE_VERIFY_CMD" \
  "$OPENCODE_SHIP_CMD"; do
  label="${file#"$ROOT_DIR"/}"
  assert_regex "$file" 'rebase[\s\S]{0,20}merge[\s\S]{0,120}manual' "$label advertises rebase or merge first and manual fallback second"
done
assert_regex "$PROMPTS_FILE" 'rebase[\s\S]{0,20}merge[\s\S]{0,180}same (stage|run)' "prompt templates advertise same-stage lifecycle-owned reconcile"
assert_regex "$PROMPTS_FILE" 'manual[\s\S]{0,80}fallback' "prompt templates keep manual as fallback wording"
assert_not_regex "$PROMPTS_FILE" 'If branch-head freshness blocks entry under manual reconcile' "prompt templates no longer default to manual-only freshness guidance"

echo ""
echo "--- Loop guards ---"
assert_contains "$VERIFY_SKILL" "The Next: line points to \`/sw-build\` for ordinary implementation BLOCKs, to" "sw-verify distinguishes implementation BLOCKs from freshness-only reruns"
assert_contains "$VERIFY_SKILL" "\`/sw-verify\` after a freshness-only pre-gate stop" "sw-verify keeps freshness-only handoff on verify"
assert_contains "$BUILD_SKILL" "queue-managed results stay distinct and do not trigger implicit local rewrites" "sw-build keeps queue-managed recovery distinct from local rewrites"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "freshness.recovery-surfaces"
