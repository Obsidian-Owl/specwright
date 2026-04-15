#!/usr/bin/env bash
#
# Regression checks for Unit 04 — support-surface cutover.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REVIEW_PACKET_PROTOCOL="$ROOT_DIR/core/protocols/review-packet.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
REVIEW_SKILL="$ROOT_DIR/core/skills/sw-review/SKILL.md"
STATUS_SKILL="$ROOT_DIR/core/skills/sw-status/SKILL.md"
DOCTOR_SKILL="$ROOT_DIR/core/skills/sw-doctor/SKILL.md"
INIT_SKILL="$ROOT_DIR/core/skills/sw-init/SKILL.md"
GUARD_SKILL="$ROOT_DIR/core/skills/sw-guard/SKILL.md"
PIVOT_SKILL="$ROOT_DIR/core/skills/sw-pivot/SKILL.md"
LEARN_SKILL="$ROOT_DIR/core/skills/sw-learn/SKILL.md"

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

echo "=== support surface cutover docs ==="
echo ""

for file in \
  "$REVIEW_PACKET_PROTOCOL" \
  "$SHIP_SKILL" \
  "$REVIEW_SKILL" \
  "$STATUS_SKILL" \
  "$DOCTOR_SKILL" \
  "$INIT_SKILL" \
  "$GUARD_SKILL" \
  "$PIVOT_SKILL" \
  "$LEARN_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Task 1: ship and review consume the audit packet ---"
assert_contains "$REVIEW_PACKET_PROTOCOL" "reviewer-facing PR body" "review-packet protocol assigns ship as a live consumer"
assert_contains "$REVIEW_PACKET_PROTOCOL" "packet, approvals, and evidence" "review-packet protocol assigns review as a live consumer"
assert_contains "$SHIP_SKILL" "{workDir}/review-packet.md" "sw-ship reads the review packet"
assert_contains "$SHIP_SKILL" "inline reviewer-usable approval lineage" "sw-ship inlines reviewer summary in clone-local mode"
assert_contains "$SHIP_SKILL" "tracked work-artifact mode" "sw-ship distinguishes tracked reviewer surfaces"
assert_contains "$REVIEW_SKILL" "Resolve the associated work from PR context" "sw-review resolves work from PR metadata"
assert_contains "$REVIEW_SKILL" "review-packet.md" "sw-review reads the review packet when work is available"
assert_contains "$REVIEW_SKILL" "approvals.md" "sw-review reads approval lineage when work is available"
assert_contains "$REVIEW_SKILL" "diff-only fallback" "sw-review documents fallback when no work match is available"

echo ""
echo "--- Task 2: audit visibility surfaces ---"

echo ""
echo "--- Task 3: pivot and learn preserve lineage ---"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "support-surface.publication-mode-cutover"
