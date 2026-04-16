#!/usr/bin/env bash
#
# Regression checks for Unit 05 Task 2 — migration and publication-mode docs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SYNC_SKILL="$ROOT_DIR/core/skills/sw-sync/SKILL.md"
AUDIT_SKILL="$ROOT_DIR/core/skills/sw-audit/SKILL.md"
GUARD_SKILL="$ROOT_DIR/core/skills/sw-guard/SKILL.md"
RESEARCH_SKILL="$ROOT_DIR/core/skills/sw-research/SKILL.md"
DEBUG_SKILL="$ROOT_DIR/core/skills/sw-debug/SKILL.md"
PLAN_SKILL="$ROOT_DIR/core/skills/sw-plan/SKILL.md"
BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
GATE_BUILD_SKILL="$ROOT_DIR/core/skills/gate-build/SKILL.md"
GATE_SECURITY_SKILL="$ROOT_DIR/core/skills/gate-security/SKILL.md"
GATE_TESTS_SKILL="$ROOT_DIR/core/skills/gate-tests/SKILL.md"
GATE_WIRING_SKILL="$ROOT_DIR/core/skills/gate-wiring/SKILL.md"
RECOVERY_PROTOCOL="$ROOT_DIR/core/protocols/recovery.md"
TESTING_STRATEGY_PROTOCOL="$ROOT_DIR/core/protocols/testing-strategy.md"
DECISION_PROTOCOL="$ROOT_DIR/core/protocols/decision.md"
BACKLOG_PROTOCOL="$ROOT_DIR/core/protocols/backlog.md"
RESEARCH_PROTOCOL="$ROOT_DIR/core/protocols/research.md"
AUDIT_PROTOCOL="$ROOT_DIR/core/protocols/audit.md"
LANDSCAPE_PROTOCOL="$ROOT_DIR/core/protocols/landscape.md"
LEARNING_LIFECYCLE_PROTOCOL="$ROOT_DIR/core/protocols/learning-lifecycle.md"
GUARDRAILS_DETECTION_PROTOCOL="$ROOT_DIR/core/protocols/guardrails-detection.md"
BUILD_CONTEXT_PROTOCOL="$ROOT_DIR/core/protocols/build-context.md"
HEADLESS_PROTOCOL="$ROOT_DIR/core/protocols/headless.md"
EVIDENCE_PROTOCOL="$ROOT_DIR/core/protocols/evidence.md"
TESTER_AGENT="$ROOT_DIR/core/agents/specwright-tester.md"
INTEGRATION_TESTER_AGENT="$ROOT_DIR/core/agents/specwright-integration-tester.md"

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

assert_not_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$label (unexpectedly found: '$needle')"
  else
    pass "$label"
  fi
}

echo "=== audit-chain migration surfaces ==="
echo ""

for file in \
  "$SYNC_SKILL" \
  "$AUDIT_SKILL" \
  "$GUARD_SKILL" \
  "$RESEARCH_SKILL" \
  "$DEBUG_SKILL" \
  "$PLAN_SKILL" \
  "$BUILD_SKILL" \
  "$VERIFY_SKILL" \
  "$GATE_BUILD_SKILL" \
  "$GATE_SECURITY_SKILL" \
  "$GATE_TESTS_SKILL" \
  "$GATE_WIRING_SKILL" \
  "$RECOVERY_PROTOCOL" \
  "$TESTING_STRATEGY_PROTOCOL" \
  "$DECISION_PROTOCOL" \
  "$BACKLOG_PROTOCOL" \
  "$RESEARCH_PROTOCOL" \
  "$AUDIT_PROTOCOL" \
  "$LANDSCAPE_PROTOCOL" \
  "$LEARNING_LIFECYCLE_PROTOCOL" \
  "$GUARDRAILS_DETECTION_PROTOCOL" \
  "$BUILD_CONTEXT_PROTOCOL" \
  "$HEADLESS_PROTOCOL" \
  "$EVIDENCE_PROTOCOL" \
  "$TESTER_AGENT" \
  "$INTEGRATION_TESTER_AGENT"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Skills use logical roots ---"
assert_contains "$SYNC_SKILL" "{projectArtifactsRoot}/config.json" "sw-sync reads tracked config from projectArtifactsRoot"
assert_contains "$AUDIT_SKILL" "{projectArtifactsRoot}/AUDIT.md" "sw-audit persists audit findings under projectArtifactsRoot"
assert_contains "$AUDIT_SKILL" "{projectArtifactsRoot}/LANDSCAPE.md" "sw-audit reads landscape from projectArtifactsRoot"
assert_contains "$GUARD_SKILL" "{projectArtifactsRoot}/config.json" "sw-guard reads tracked config from projectArtifactsRoot"
assert_contains "$GUARD_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-guard reads constitution from projectArtifactsRoot"
assert_contains "$RESEARCH_SKILL" "{projectArtifactsRoot}/research/" "sw-research uses tracked research root"
assert_contains "$RESEARCH_SKILL" "{projectArtifactsRoot}/CHARTER.md" "sw-research reads charter from projectArtifactsRoot"
assert_contains "$DEBUG_SKILL" "{projectArtifactsRoot}/config.json" "sw-debug reads tracked config from projectArtifactsRoot"
assert_contains "$DEBUG_SKILL" "{workArtifactsRoot}/{id}/diagnosis.md" "sw-debug writes diagnosis to auditable work artifacts"
assert_contains "$DEBUG_SKILL" "{workArtifactsRoot}/{id}/spec.md" "sw-debug writes spec to auditable work artifacts"
assert_contains "$PLAN_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-plan reads constitution from projectArtifactsRoot"
assert_contains "$PLAN_SKILL" "{projectArtifactsRoot}/config.json" "sw-plan reads tracked config from projectArtifactsRoot"
assert_contains "$BUILD_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-build reads constitution from projectArtifactsRoot"
assert_contains "$BUILD_SKILL" "{projectArtifactsRoot}/config.json" "sw-build reads tracked config from projectArtifactsRoot"
assert_contains "$VERIFY_SKILL" "{projectArtifactsRoot}/config.json" "sw-verify reads tracked config from projectArtifactsRoot"
assert_contains "$GATE_BUILD_SKILL" "{projectArtifactsRoot}/config.json" "gate-build reads tracked config from projectArtifactsRoot"
assert_contains "$GATE_SECURITY_SKILL" "{projectArtifactsRoot}/config.json" "gate-security reads tracked config from projectArtifactsRoot"
assert_contains "$GATE_TESTS_SKILL" "{projectArtifactsRoot}/config.json" "gate-tests reads tracked config from projectArtifactsRoot"
assert_contains "$GATE_TESTS_SKILL" "{projectArtifactsRoot}/TESTING.md" "gate-tests reads TESTING from projectArtifactsRoot"
assert_contains "$GATE_WIRING_SKILL" "{projectArtifactsRoot}/config.json" "gate-wiring reads tracked config from projectArtifactsRoot"

echo ""
echo "--- Protocols keep tracked and runtime surfaces split ---"
assert_contains "$RECOVERY_PROTOCOL" "{projectArtifactsRoot}/CHARTER.md" "recovery reads charter from projectArtifactsRoot"
assert_contains "$RECOVERY_PROTOCOL" "{projectArtifactsRoot}/CONSTITUTION.md" "recovery reads constitution from projectArtifactsRoot"
assert_contains "$RECOVERY_PROTOCOL" "{projectArtifactsRoot}/TESTING.md" "recovery reads TESTING from projectArtifactsRoot"
assert_contains "$TESTING_STRATEGY_PROTOCOL" "{projectArtifactsRoot}/TESTING.md" "testing strategy defines the tracked TESTING path"
assert_contains "$DECISION_PROTOCOL" "{projectArtifactsRoot}/TESTING.md" "decision protocol promotes testing learnings to projectArtifactsRoot"
assert_contains "$DECISION_PROTOCOL" "{workArtifactsRoot}/{id}/" "decision protocol stores assumptions under workArtifactsRoot"
assert_contains "$BACKLOG_PROTOCOL" "{projectArtifactsRoot}/BACKLOG.md" "backlog protocol writes markdown backlog under projectArtifactsRoot"
assert_contains "$RESEARCH_PROTOCOL" "{projectArtifactsRoot}/research/" "research protocol uses tracked research root"
assert_contains "$AUDIT_PROTOCOL" "{projectArtifactsRoot}/AUDIT.md" "audit protocol uses tracked AUDIT root"
assert_contains "$LANDSCAPE_PROTOCOL" "{projectArtifactsRoot}/LANDSCAPE.md" "landscape protocol uses tracked LANDSCAPE root"
assert_contains "$LEARNING_LIFECYCLE_PROTOCOL" "{projectArtifactsRoot}/CONSTITUTION.md" "learning lifecycle uses tracked constitution path"
assert_contains "$LEARNING_LIFECYCLE_PROTOCOL" "{projectArtifactsRoot}/patterns.md" "learning lifecycle uses tracked patterns path"
assert_contains "$LEARNING_LIFECYCLE_PROTOCOL" "{projectArtifactsRoot}/learnings/{work-id}.json" "learning lifecycle uses tracked learnings path"
assert_contains "$GUARDRAILS_DETECTION_PROTOCOL" "{projectArtifactsRoot}/config.json" "guardrails detection reads tracked config path"
assert_contains "$BUILD_CONTEXT_PROTOCOL" "{worktreeStateRoot}/continuation.md" "build-context writes continuation to worktreeStateRoot"
assert_contains "$HEADLESS_PROTOCOL" "{worktreeStateRoot}/continuation.md" "headless protocol writes continuation to worktreeStateRoot"
assert_contains "$EVIDENCE_PROTOCOL" "{projectArtifactsRoot}/learnings/" "evidence protocol reads calibration from tracked learnings"

echo ""
echo "--- Agents consume tracked project artifacts ---"
assert_contains "$TESTER_AGENT" "{projectArtifactsRoot}/TESTING.md" "tester agent reads TESTING from projectArtifactsRoot"
assert_contains "$INTEGRATION_TESTER_AGENT" "{projectArtifactsRoot}/config.json" "integration tester reads config from projectArtifactsRoot"
assert_contains "$INTEGRATION_TESTER_AGENT" "{projectArtifactsRoot}/TESTING.md" "integration tester reads TESTING from projectArtifactsRoot"

echo ""
echo "--- Legacy path guards ---"
assert_not_contains "$AUDIT_SKILL" ".specwright/AUDIT.md" "sw-audit no longer hardcodes legacy AUDIT path"
assert_not_contains "$RESEARCH_SKILL" ".specwright/research/" "sw-research no longer hardcodes legacy research path"
assert_not_contains "$DEBUG_SKILL" ".specwright/work/" "sw-debug no longer hardcodes legacy work path"
assert_not_contains "$GATE_BUILD_SKILL" ".specwright/config.json" "gate-build no longer hardcodes legacy config path"
assert_not_contains "$GATE_SECURITY_SKILL" ".specwright/config.json" "gate-security no longer hardcodes legacy config path"
assert_not_contains "$GATE_TESTS_SKILL" ".specwright/TESTING.md" "gate-tests no longer hardcodes legacy TESTING path"
assert_not_contains "$GATE_WIRING_SKILL" ".specwright/config.json" "gate-wiring no longer hardcodes legacy config path"
assert_not_contains "$BACKLOG_PROTOCOL" ".specwright/BACKLOG.md" "backlog protocol no longer hardcodes legacy backlog path"
assert_not_contains "$RESEARCH_PROTOCOL" ".specwright/research/" "research protocol no longer hardcodes legacy research path"
assert_not_contains "$AUDIT_PROTOCOL" ".specwright/AUDIT.md" "audit protocol no longer hardcodes legacy AUDIT path"
assert_not_contains "$LANDSCAPE_PROTOCOL" ".specwright/LANDSCAPE.md" "landscape protocol no longer hardcodes legacy LANDSCAPE path"
assert_not_contains "$BUILD_CONTEXT_PROTOCOL" ".specwright/state/continuation.md" "build-context no longer hardcodes legacy continuation path"
assert_not_contains "$HEADLESS_PROTOCOL" ".specwright/state/continuation.md" "headless protocol no longer hardcodes legacy continuation path"
assert_not_contains "$EVIDENCE_PROTOCOL" ".specwright/learnings/" "evidence protocol no longer hardcodes legacy learnings path"
assert_not_contains "$TESTER_AGENT" ".specwright/TESTING.md" "tester agent no longer hardcodes legacy TESTING path"
assert_not_contains "$INTEGRATION_TESTER_AGENT" ".specwright/TESTING.md" "integration tester no longer hardcodes legacy TESTING path"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "audit-chain.migration-surfaces"
