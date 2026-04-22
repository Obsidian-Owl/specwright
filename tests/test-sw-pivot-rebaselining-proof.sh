#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Integrated proof for the broadened sw-pivot contract and its downstream
# workflow-facing surfaces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PIVOT_SKILL="$ROOT_DIR/core/skills/sw-pivot/SKILL.md"
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

assert_not_regex() {
  local file="$1" pattern="$2" label="$3"
  if python - "$file" "$pattern" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
raise SystemExit(1 if re.search(pattern, text, re.IGNORECASE | re.DOTALL) else 0)
PY
  then
    pass "$label"
  else
    fail "$label (unexpected pattern found: $pattern)"
  fi
}

echo "=== sw-pivot rebaselining proof ==="
echo ""

for file in \
  "$PIVOT_SKILL" \
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
echo "--- Pivot contract ---"
assert_contains "$PIVOT_SKILL" "Research-backed rebaselining for the selected work." "sw-pivot frames itself as research-backed rebaselining"
assert_contains "$PIVOT_SKILL" "Optional recent retro or research inputs when available and relevant" "sw-pivot keeps retro and research inputs optional"
assert_regex "$PIVOT_SKILL" 'Completed[\s\S]{0,20}tasks and shipped units are immutable baseline scope' "sw-pivot preserves completed and shipped scope as immutable baseline"
assert_contains "$PIVOT_SKILL" "record preserved baseline scope versus delta scope in \`decisions.md\`" "sw-pivot records preserved scope versus delta scope"
assert_regex "$PIVOT_SKILL" 'Never rewrite unrelated active[\s\S]{0,20}works' "sw-pivot keeps linked-worktree drift as context rather than rewriting other work"
assert_contains "$PIVOT_SKILL" "Never fabricate a replacement \`APPROVED\` entry" "sw-pivot preserves stale approval lineage instead of inventing approval"
assert_contains "$PIVOT_SKILL" "remaining-tasks-only rewrite." "sw-pivot explicitly rejects remaining-tasks-only rewrite framing"
assert_regex "$PIVOT_SKILL" 'Valid entry states[\s\S]{0,80}`planning`, `building`, and `verifying`[\s\S]{0,120}Reject `designing`,[\s\S]{0,80}`shipping`, and `shipped`' "sw-pivot exposes the broadened valid and invalid entry states together"
assert_regex "$PIVOT_SKILL" 'rewrite shipped scope[\s\S]{0,120}/sw-design' "sw-pivot escalates shipped-scope rewrites to fresh sw-design work"

echo ""
echo "--- Downstream alignment ---"
assert_contains "$BUILD_SKILL" "When \`sw-pivot\` or replanning regenerated the current unit artifacts, that regenerated artifact set becomes the current approval surface." "sw-build treats pivoted unit artifacts as the live approval surface"
assert_contains "$VERIFY_SKILL" "Missing, \`STALE\`, or" "sw-verify surfaces stale approval lineage explicitly"
assert_contains "$SHIP_SKILL" "review-packet-grounded, evidence-mapped body" "sw-ship keeps reviewer-facing proof grounded in verify output"
assert_contains "$FRESHNESS_PROTOCOL" "shipping is the exception because" "shared freshness protocol preserves the ship rerun exception"

echo ""
echo "--- Public surfaces ---"
for file in "$CLAUDE_DOC" "$ADAPTER_CLAUDE_DOC" "$README_DOC" "$DESIGN_DOC"; do
  label="${file#"$ROOT_DIR"/}"
  assert_regex "$file" 'sw-pivot[\s\S]{0,220}(research-backed|rebaselin)' "$label preserves research-backed pivot wording"
  assert_regex "$file" '(completed[^\n]*shipped|shipped[^\n]*completed)' "$label preserves completed and shipped scope wording"
  assert_regex "$file" 'rewrite shipped scope[\s\S]{0,160}/sw-design' "$label routes rewrite requests back to /sw-design"
done

echo ""
echo "--- Drift guards ---"
assert_not_regex "$PIVOT_SKILL" 'only valid during active sw-build|mid-build course correction' "sw-pivot no longer uses the pre-rebaselining build-only framing"
assert_not_regex "$CLAUDE_DOC" 'mid-build course correction' "CLAUDE no longer uses the old pivot tagline"
assert_not_regex "$README_DOC" 'remaining tasks only|remaining-task-only' "README no longer implies pivot rewrites only remaining tasks"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "pivot.rebaselining-proof"
