#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Integrated proof for branch-head/manual reconcile guidance across build,
# verify, ship, the shared freshness protocol, and public operator docs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
FRESHNESS_PROTOCOL="$ROOT_DIR/core/protocols/git-freshness.md"
CLAUDE_DOC="$ROOT_DIR/CLAUDE.md"
ADAPTER_CLAUDE_DOC="$ROOT_DIR/adapters/claude-code/CLAUDE.md"
README_DOC="$ROOT_DIR/README.md"
DESIGN_DOC="$ROOT_DIR/DESIGN.md"

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

echo "=== branch freshness reconcile loop proof ==="
echo ""

for file in \
  "$BUILD_SKILL" \
  "$VERIFY_SKILL" \
  "$SHIP_SKILL" \
  "$FRESHNESS_PROTOCOL" \
  "$CLAUDE_DOC" \
  "$ADAPTER_CLAUDE_DOC" \
  "$README_DOC" \
  "$DESIGN_DOC"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Stage-specific reruns ---"
assert_contains "$BUILD_SKILL" "Build freshness checkpoint is blocked under branch-head \`require\` + \`manual\` | STOP with manual reconcile guidance, keep the recorded target/freshness metadata, then rerun \`/sw-build\`." "sw-build reruns the blocked build stage after manual reconcile"
assert_regex "$VERIFY_SKILL" 'Do not redirect to `/sw-build` solely[\s\S]{0,40}clear freshness' "sw-verify explicitly forbids bouncing back to build for freshness-only stops"
assert_contains "$VERIFY_SKILL" "| Verify freshness checkpoint is blocked under branch-head \`require\` + \`manual\` | STOP with manual reconcile guidance and rerun \`/sw-verify\`, not \`/sw-build\`. |" "sw-verify reruns verify instead of soft-looping to build"
assert_contains "$SHIP_SKILL" "| Shipping freshness checkpoint is blocked under branch-head \`require\` + \`manual\` | STOP with manual reconcile guidance, rerun \`/sw-verify\`, then rerun \`/sw-ship\`. |" "sw-ship keeps the verify-then-ship exception explicit"
assert_regex "$SHIP_SKILL" 'Do not silently rewrite[\s\S]{0,40}`targetRef` or freshness metadata to bypass the block' "sw-ship preserves fail-closed freshness state"

echo ""
echo "--- Shared protocol contract ---"
assert_contains "$FRESHNESS_PROTOCOL" "after a manual reconcile stop, rerun the blocked lifecycle stage rather than" "git-freshness defines same-stage reruns as the default manual reconcile contract"
assert_contains "$FRESHNESS_PROTOCOL" "silently routing through a different stage; shipping is the exception because" "git-freshness encodes the shipping-only verify-then-ship exception"
assert_contains "$FRESHNESS_PROTOCOL" "require adopt/takeover before reconciling there" "git-freshness keeps linked-worktree ownership conflicts fail-closed"

echo ""
echo "--- Public operator docs ---"
for file in "$CLAUDE_DOC" "$ADAPTER_CLAUDE_DOC" "$README_DOC" "$DESIGN_DOC"; do
  label="${file#"$ROOT_DIR"/}"
  assert_regex "$file" 'manual reconcile[\s\S]{0,240}/sw-build[\s\S]{0,120}/sw-verify[\s\S]{0,160}/sw-ship' "$label documents the build/verify/ship rerun sequence"
  assert_regex "$file" 'recorded target[\s\S]{0,40}owning worktree' "$label keeps reconciliation anchored to the owning worktree"
done

echo ""
echo "--- Loop guards ---"
assert_contains "$VERIFY_SKILL" "The Next: line points to \`/sw-build\` for ordinary implementation BLOCKs, to" "sw-verify distinguishes implementation BLOCKs from freshness-only reruns"
assert_contains "$VERIFY_SKILL" "\`/sw-verify\` after a freshness-only pre-gate stop" "sw-verify keeps freshness-only handoff on verify"
assert_contains "$BUILD_SKILL" "queue-managed results do not trigger hidden rebases or other branch rewrites" "sw-build keeps manual reconcile distinct from hidden branch rewrites"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "freshness.reconcile-loop"
