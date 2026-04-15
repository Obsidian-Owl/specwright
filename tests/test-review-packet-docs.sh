#!/usr/bin/env bash
#
# Regression checks for Unit 03 — rationale and review-packet docs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REVIEW_PACKET_PROTOCOL="$ROOT_DIR/core/protocols/review-packet.md"
EVIDENCE_PROTOCOL="$ROOT_DIR/core/protocols/evidence.md"
BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
GATE_SPEC_SKILL="$ROOT_DIR/core/skills/gate-spec/SKILL.md"
ROOT_AGENTS="$ROOT_DIR/AGENTS.md"
ROOT_CLAUDE="$ROOT_DIR/CLAUDE.md"
ADAPTER_CLAUDE="$ROOT_DIR/adapters/claude-code/CLAUDE.md"

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
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

emit_coverage_marker() {
  printf 'COVERAGE: %s\n' "$1"
}

echo "=== review packet docs ==="
echo ""

for file in \
  "$REVIEW_PACKET_PROTOCOL" \
  "$EVIDENCE_PROTOCOL" \
  "$BUILD_SKILL" \
  "$VERIFY_SKILL" \
  "$GATE_SPEC_SKILL" \
  "$ROOT_AGENTS" \
  "$ROOT_CLAUDE" \
  "$ADAPTER_CLAUDE"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Review packet contract ---"
assert_contains "$REVIEW_PACKET_PROTOCOL" "## Approval Lineage" "review-packet protocol defines approval lineage section"
assert_contains "$REVIEW_PACKET_PROTOCOL" "## What Changed" "review-packet protocol defines change summary section"
assert_contains "$REVIEW_PACKET_PROTOCOL" "## Why The Agent Implemented It This Way" "review-packet protocol defines rationale digest section"
assert_contains "$REVIEW_PACKET_PROTOCOL" "## Spec Conformance" "review-packet protocol defines conformance section"
assert_contains "$REVIEW_PACKET_PROTOCOL" "## Gate Summary" "review-packet protocol defines gate summary section"
assert_contains "$REVIEW_PACKET_PROTOCOL" "## Remaining Attention" "review-packet protocol defines remaining attention section"
assert_contains "$REVIEW_PACKET_PROTOCOL" "must not depend on local-only file links" "review-packet protocol guards clone-local reviewer visibility"
assert_contains "$REVIEW_PACKET_PROTOCOL" "a transcript archive" "review-packet protocol rejects transcript storage"
assert_contains "$REVIEW_PACKET_PROTOCOL" "a second gate engine" "review-packet protocol rejects duplicated gate logic"
assert_contains "$REVIEW_PACKET_PROTOCOL" "reviewer-facing PR body" "review-packet protocol makes sw-ship a live consumer"
assert_contains "$REVIEW_PACKET_PROTOCOL" "packet, approvals, and evidence" "review-packet protocol makes sw-review a live consumer"

echo ""
echo "--- Evidence synthesis contract ---"
assert_contains "$EVIDENCE_PROTOCOL" "## Reviewer Synthesis" "evidence protocol defines reviewer synthesis section"
assert_contains "$EVIDENCE_PROTOCOL" "\`review-packet.md\` is a sibling audit artifact" "evidence protocol distinguishes packet from gate reports"
assert_contains "$EVIDENCE_PROTOCOL" "implementation-rationale.md" "evidence protocol names implementation rationale as packet input"
assert_contains "$EVIDENCE_PROTOCOL" "gate-spec compliance matrix" "evidence protocol names gate-spec matrix as packet input"
assert_contains "$EVIDENCE_PROTOCOL" "does not rerun" "evidence protocol forbids packet gate reruns"
assert_contains "$EVIDENCE_PROTOCOL" "canonical AC / IC proof surface" "evidence protocol keeps spec proof canonical"

echo ""
echo "--- Build and verify lifecycle surfaces ---"
assert_contains "$BUILD_SKILL" "{workDir}/implementation-rationale.md" "sw-build outputs the implementation rationale artifact"
assert_contains "$BUILD_SKILL" "append-only curated" "sw-build keeps rationale append-only and curated"
assert_contains "$BUILD_SKILL" "tracked tree stays clean" "sw-build guards tracked work-artifact cleanliness for rationale updates"
assert_contains "$BUILD_SKILL" "relevant AC references" "sw-build requires AC references in rationale"
assert_contains "$BUILD_SKILL" "tests added or" "sw-build requires test-summary rationale coverage"
assert_contains "$BUILD_SKILL" "execution path (\`executor\` or \`build-fixer\`)" "sw-build records executor vs build-fixer path"
assert_contains "$BUILD_SKILL" "captures rationale, not transcript" "sw-build forbids transcript-style rationale capture"
assert_contains "$BUILD_SKILL" "protocols/review-packet.md" "sw-build protocol references include review-packet"
assert_contains "$VERIFY_SKILL" "{workDir}/review-packet.md" "sw-verify outputs the review packet artifact"
assert_contains "$VERIFY_SKILL" "implementation-rationale.md" "sw-verify consumes implementation rationale"
assert_contains "$VERIFY_SKILL" "integration-criteria.md" "sw-verify inputs include conditional packet integration criteria"
assert_contains "$VERIFY_SKILL" "canonical gate-spec compliance matrix" "sw-verify keeps gate-spec as the proof source"
assert_contains "$VERIFY_SKILL" "not a second gate engine" "sw-verify forbids duplicate gate logic in the packet"
assert_contains "$VERIFY_SKILL" "local-only file links" "sw-verify carries the clone-local reviewer guardrail"

echo ""
echo "--- Canonical proof surface and protocol indexes ---"
assert_contains "$GATE_SPEC_SKILL" "canonical AC / IC proof surface" "gate-spec names its matrix as the canonical proof surface"
assert_contains "$GATE_SPEC_SKILL" "Preserve the five-column compliance matrix shape" "gate-spec preserves the stable matrix shape"
assert_contains "$ROOT_AGENTS" "review-packet.md" "AGENTS.md indexes the review-packet protocol"
assert_contains "$ROOT_CLAUDE" "review-packet.md" "root CLAUDE.md indexes the review-packet protocol"
assert_contains "$ADAPTER_CLAUDE" "review-packet.md" "adapter CLAUDE.md indexes the review-packet protocol"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "review-packet.clone-local-guard"
