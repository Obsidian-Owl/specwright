#!/usr/bin/env bash
#
# Tests for Unit 01 — Strip the Gate Handoff Template
# (Subtractive recovery — see .specwright/work/legibility-recovery/)
#
# Verifies:
#   AC-1, AC-2 — decision.md Gate Handoff section is the new three-line format
#   AC-3..AC-6 — sw-design, sw-plan, sw-verify, sw-ship reference the new format
#   AC-9       — sw-init and sw-build do NOT reference the gate handoff template
#   AC-10      — old four-section handoff headings do not leak elsewhere
#
# AC-7 is covered by tests/test-claude-code-build.sh (run separately).
# AC-8 is a behavioral test against pipeline skills, run after this unit ships.
#
# Usage: ./tests/test-handoff-template.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_file_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    pass "$message"
  else
    fail "$message — pattern not found: $pattern"
  fi
}

assert_file_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"
  if grep -qE "$pattern" "$path" 2>/dev/null; then
    fail "$message — pattern still present: $pattern"
  else
    pass "$message"
  fi
}

cd "$ROOT_DIR" || exit 1

echo "=== Unit 01: Strip the Gate Handoff Template ==="
echo ""

# AC-1: decision.md has the new Gate Handoff section with the three-line format
echo "AC-1: decision.md three-line format present"
assert_file_contains "core/protocols/decision.md" "^## Gate Handoff" \
  "decision.md has '## Gate Handoff' heading"
assert_file_contains "core/protocols/decision.md" "Done\. \{one-line outcome\}" \
  "decision.md template includes 'Done. {one-line outcome}.'"
assert_file_contains "core/protocols/decision.md" "Artifacts: \{stageReportPath\}" \
  "decision.md template includes 'Artifacts: {stageReportPath}'"
assert_file_contains "core/protocols/decision.md" "Next: /sw-\{next-skill\}" \
  "decision.md template includes 'Next: /sw-{next-skill}'"

# AC-2: decision.md does NOT contain the old four-section labels
echo ""
echo "AC-2: decision.md four-section labels removed"
assert_file_not_contains "core/protocols/decision.md" "^### Decision Digest" \
  "decision.md does not have '### Decision Digest'"
assert_file_not_contains "core/protocols/decision.md" "^### Quality Checks" \
  "decision.md does not have '### Quality Checks'"
assert_file_not_contains "core/protocols/decision.md" "^### Deficiencies" \
  "decision.md does not have '### Deficiencies'"
assert_file_not_contains "core/protocols/decision.md" "^### Recommendation" \
  "decision.md does not have '### Recommendation'"

# AC-3..AC-6: each pipeline skill references the new format
echo ""
echo "AC-3..AC-6: pipeline skills reference the new format"
for skill in sw-design sw-plan sw-verify sw-ship; do
  assert_file_contains "core/skills/$skill/SKILL.md" "three-line handoff|Gate Handoff section" \
    "$skill references the new handoff format"
  assert_file_not_contains "core/skills/$skill/SKILL.md" "decision digest, quality checks, deficiencies" \
    "$skill no longer references the four-section template"
done

# AC-9: sw-init and sw-build do NOT have a Gate handoff constraint block
echo ""
echo "AC-9: sw-init and sw-build do not emit gate handoff"
assert_file_not_contains "core/skills/sw-init/SKILL.md" "Gate handoff \(LOW freedom\)" \
  "sw-init has no Gate handoff constraint block"
assert_file_not_contains "core/skills/sw-build/SKILL.md" "Gate handoff \(LOW freedom\)" \
  "sw-build has no Gate handoff constraint block"

# AC-10: old four-section handoff headings do not leak elsewhere
echo ""
echo "AC-10: no old four-section handoff headings leak"
LEAK_FILES=$(grep -rEl '^### (Decision Digest|Quality Checks|Deficiencies|Recommendation)' core/ 2>/dev/null || true)
if [ -z "$LEAK_FILES" ]; then
  pass "no old four-section handoff headings leak in core/"
else
  fail "old four-section handoff headings leak in: $LEAK_FILES"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
