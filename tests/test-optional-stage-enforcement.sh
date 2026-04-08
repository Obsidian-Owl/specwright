#!/usr/bin/env bash
# shellcheck disable=SC2016
# Grep patterns in this test intentionally contain literal backticks
# (markdown code-fence characters), not command substitution. Single
# quotes keep them literal.
#
# Tests for Unit 02 — Relax Optional-Stage Enforcement
# (Subtractive recovery — see .specwright/work/legibility-recovery/)
#
# Verifies:
#   AC-1        — state.md has shipped → designing transition row
#   AC-2        — state.md documents sw-learn as optional
#   AC-3        — sw-design State mutations handles prior shipped + clobber notice
#   AC-5, AC-5a — No core pipeline skill hard-requires an optional skill (negative assertions)
#                 sw-pivot exception captured
#   AC-6        — Optional skills may have recommendations in free-text (not enforced)
#   AC-9 proxy  — stage-boundary handoff table does not force sw-learn between ship and next build
#
# AC-4 (audit deliverable) is verified by the presence of audit.md.
# AC-7 (test-claude-code-build.sh) is run separately by the build gate.
# AC-8, AC-9, AC-10 are manual/fixture-based — verified during the verify phase.
#
# Usage: ./tests/test-optional-stage-enforcement.sh
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

cd "$ROOT_DIR" || exit 1

echo "=== Unit 02: Relax Optional-Stage Enforcement ==="
echo ""

# AC-1: state.md state-transition table has shipped → designing row
echo "AC-1: state.md has shipped → designing transition"
assert_file_contains "core/protocols/state.md" \
  '\| `?shipped`? \| `?designing`? \|' \
  "state.md has a shipped → designing row in the transition table"

assert_file_contains "core/protocols/state.md" \
  'sw-design.*clears prior.*work|shipped.*designing.*sw-design' \
  "state.md row for shipped → designing names sw-design as the trigger"

# AC-2: state.md documents sw-learn as optional
echo ""
echo "AC-2: sw-learn documented as optional"
assert_file_contains "core/protocols/state.md" \
  '(sw-learn is.*optional|optional capture step)' \
  "state.md documents sw-learn as optional, not a prerequisite"

# AC-3: sw-design State mutations handles prior shipped + clobber notice
echo ""
echo "AC-3: sw-design handles prior shipped work"
assert_file_contains "core/skills/sw-design/SKILL.md" \
  'prior `?currentWork`? has status `?shipped`?' \
  "sw-design State mutations mentions prior shipped work"

assert_file_contains "core/skills/sw-design/SKILL.md" \
  '`?workUnits`? .*reset to null|reset `?workUnits`? to null' \
  "sw-design clears workUnits to null when handling prior shipped work"

assert_file_contains "core/skills/sw-design/SKILL.md" \
  'Clearing prior shipped work.*sw-learn first if pattern capture is desired' \
  "sw-design prints clobber notice before clearing prior shipped work"

# AC-5: No core pipeline skill hard-requires an optional skill
echo ""
echo "AC-5: core pipeline skills do not hard-require optional skills"
for core_skill in sw-init sw-design sw-plan sw-build sw-verify sw-ship; do
  for optional in sw-learn sw-research sw-audit sw-doctor sw-guard sw-sync sw-review; do
    # Look for STOP lines or "Run /sw-{optional} first" style failure modes.
    # Excludes:
    #   - sw-pivot (handled separately in AC-5a)
    #   - sw-status (read-only)
    #   - informational print notices (phrased as suggestions, not STOPs)
    # A hard enforcement is specifically: a STOP: ... Run /sw-optional, or a
    # failure-mode table row whose action starts with STOP:.
    if grep -nE "STOP: .*/$optional" "core/skills/$core_skill/SKILL.md" 2>/dev/null \
       | grep -v '^\s*#' > /tmp/optional-enforce.out; then
      if [ -s /tmp/optional-enforce.out ]; then
        fail "core/skills/$core_skill/SKILL.md enforces optional skill $optional as hard precondition: $(cat /tmp/optional-enforce.out)"
        continue
      fi
    fi
    pass "$core_skill does not hard-require $optional"
  done
done

# AC-5a: sw-pivot exception — it IS state-gated, and that's deliberately OK
echo ""
echo "AC-5a: sw-pivot self-gating is captured as justified"
assert_file_contains \
  ".specwright/work/legibility-recovery/units/02-relax-optional-stage-enforcement/audit.md" \
  'sw-pivot.*optional to RUN.*state transition' \
  "audit.md captures sw-pivot justification (optional to invoke, state-gated when invoked)"

# AC-6: recommendations in free text are allowed
echo ""
echo "AC-6: sw-ship recommendation language is free-text, not enforcement"
assert_file_contains "core/skills/sw-ship/SKILL.md" \
  'suggest `?/sw-learn`?|(sw-learn.*optional)' \
  "sw-ship references sw-learn as a suggestion/optional, not a STOP"

# Stage-boundary handoff table restatement
echo ""
echo "AC restatement: stage-boundary table does not force sw-learn between ship and next build"
assert_file_contains "core/protocols/stage-boundary.md" \
  'sw-ship.*/sw-build.*next unit|sw-learn.*optional' \
  "stage-boundary.md clarifies sw-learn is optional in the ship → next-build path"

# AC-4 proxy: audit deliverable exists
echo ""
echo "AC-4: audit.md deliverable exists"
if [ -f ".specwright/work/legibility-recovery/units/02-relax-optional-stage-enforcement/audit.md" ]; then
  pass "audit.md exists at the unit work directory"
else
  fail "audit.md missing"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
