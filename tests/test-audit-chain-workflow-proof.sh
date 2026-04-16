#!/usr/bin/env bash
#
# Integrated workflow proof for the audit-chain lifecycle and approval policy.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APPROVALS_PROTOCOL="$ROOT_DIR/core/protocols/approvals.md"
REVIEW_PACKET_PROTOCOL="$ROOT_DIR/core/protocols/review-packet.md"
DESIGN_SKILL="$ROOT_DIR/core/skills/sw-design/SKILL.md"
PLAN_SKILL="$ROOT_DIR/core/skills/sw-plan/SKILL.md"
BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
APPROVALS_HELPER="$ROOT_DIR/adapters/shared/specwright-approvals.mjs"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

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
  local path="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$path"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_output_contains() {
  local output="$1" needle="$2" label="$3"
  if printf '%s' "$output" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

emit_coverage_marker() {
  printf 'COVERAGE: %s\n' "$1"
}

echo "=== audit-chain workflow proof ==="
echo ""

for file in \
  "$APPROVALS_PROTOCOL" \
  "$REVIEW_PACKET_PROTOCOL" \
  "$DESIGN_SKILL" \
  "$PLAN_SKILL" \
  "$BUILD_SKILL" \
  "$VERIFY_SKILL" \
  "$SHIP_SKILL" \
  "$APPROVALS_HELPER"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Lifecycle chain contract ---"
assert_contains "$DESIGN_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-design loads constitution from projectArtifactsRoot"
assert_contains "$DESIGN_SKILL" "{projectArtifactsRoot}/CHARTER.md" "sw-design loads charter from projectArtifactsRoot"
assert_contains "$DESIGN_SKILL" "{projectArtifactsRoot}/config.json" "sw-design loads config from projectArtifactsRoot"
assert_contains "$PLAN_SKILL" "Interactive \`/sw-plan\` runs may write an \`APPROVED\` \`design\` entry" "sw-plan records design approval on entry"
assert_contains "$PLAN_SKILL" "headless runs must validate existing human approval" "sw-plan keeps headless approval fail-closed"
assert_contains "$PLAN_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-plan loads constitution from projectArtifactsRoot"
assert_contains "$PLAN_SKILL" "{projectArtifactsRoot}/config.json" "sw-plan loads config from projectArtifactsRoot"
assert_contains "$BUILD_SKILL" "Interactive \`/sw-build\` runs may record an \`APPROVED\` \`unit-spec\` entry" "sw-build records unit-spec approval on entry"
assert_contains "$BUILD_SKILL" "{workDir}/implementation-rationale.md" "sw-build produces implementation rationale"
assert_contains "$BUILD_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-build loads constitution from projectArtifactsRoot"
assert_contains "$BUILD_SKILL" "{projectArtifactsRoot}/config.json" "sw-build loads config from projectArtifactsRoot"
assert_contains "$VERIFY_SKILL" "Approval Lineage" "sw-verify reports approval lineage separately"
assert_contains "$VERIFY_SKILL" "Missing, \`STALE\`, or" "sw-verify surfaces incomplete or stale approval lineage"
assert_contains "$VERIFY_SKILL" "never create \`APPROVED\` entries" "sw-verify keeps headless verification fail-closed"
assert_contains "$VERIFY_SKILL" "{workDir}/review-packet.md" "sw-verify synthesizes review-packet.md"
assert_contains "$VERIFY_SKILL" "{projectArtifactsRoot}/config.json" "sw-verify loads config from projectArtifactsRoot"
assert_contains "$REVIEW_PACKET_PROTOCOL" "reviewer-facing PR body" "review-packet protocol makes ship a live consumer"
assert_contains "$SHIP_SKILL" "{workDir}/review-packet.md" "sw-ship consumes review-packet.md"

echo ""
echo "--- Approval and stale-chain proof ---"
HELPER_OUTPUT=""
HELPER_EXIT=0

if ! command -v node >/dev/null 2>&1; then
  fail "node is required for the approval-helper proof but was not found"
else
  HELPER_OUTPUT="$(
    APPROVALS_HELPER="$APPROVALS_HELPER" TEST_TMPDIR="$TEST_TMPDIR" node --input-type=module <<'EOF'
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import { pathToFileURL } from 'url';

const helperPath = pathToFileURL(process.env.APPROVALS_HELPER).href;
const tmpDir = process.env.TEST_TMPDIR;
const helper = await import(helperPath);
const {
  assessApprovalEntry,
  createApprovalEntry,
  hashApprovalArtifacts,
  loadApprovalsFile,
  recordApproval,
  writeApprovalsFile
} = helper;

const workRoot = join(tmpDir, 'audit-chain');
const unitRoot = join(workRoot, 'units', '05-workflow-proof-and-migration');
mkdirSync(unitRoot, { recursive: true });

writeFileSync(join(workRoot, 'design.md'), 'design v1\n', 'utf8');
writeFileSync(join(workRoot, 'context.md'), 'design context v1\n', 'utf8');
writeFileSync(join(workRoot, 'decisions.md'), 'decision v1\n', 'utf8');
writeFileSync(join(unitRoot, 'spec.md'), 'spec v1\n', 'utf8');
writeFileSync(join(unitRoot, 'plan.md'), 'plan v1\n', 'utf8');
writeFileSync(join(unitRoot, 'context.md'), 'unit context v1\n', 'utf8');
writeFileSync(join(unitRoot, 'implementation-rationale.md'), 'rationale v1\n', 'utf8');

let doc = recordApproval(null, {
  baseDir: workRoot,
  scope: 'design',
  artifacts: ['design.md', 'context.md', 'decisions.md'],
  sourceClassification: 'command',
  sourceRef: '/sw-plan',
  approvedAt: '2026-04-16T00:00:00Z'
});

doc = recordApproval(doc, {
  baseDir: unitRoot,
  scope: 'unit-spec',
  unitId: '05-workflow-proof-and-migration',
  artifacts: ['spec.md', 'plan.md', 'context.md'],
  sourceClassification: 'command',
  sourceRef: '/sw-build',
  approvedAt: '2026-04-16T00:10:00Z'
});

const approvalsPath = join(workRoot, 'approvals.md');
writeApprovalsFile(approvalsPath, doc);
const loaded = loadApprovalsFile(approvalsPath);

const designEntry = loaded.entries.find((entry) => entry.scope === 'design');
const unitEntry = loaded.entries.find((entry) => entry.scope === 'unit-spec');

const designStatus = assessApprovalEntry(designEntry, { baseDir: workRoot }).status;
const unitStatusBefore = assessApprovalEntry(unitEntry, { baseDir: unitRoot }).status;

writeFileSync(join(unitRoot, 'spec.md'), 'spec v2\n', 'utf8');
const unitStatusAfter = assessApprovalEntry(unitEntry, { baseDir: unitRoot }).status;
const missingDesignStatus = assessApprovalEntry(null, {
  baseDir: workRoot,
  artifacts: ['design.md', 'context.md', 'decisions.md']
}).status;

let headlessApprovedRejected = false;
try {
  createApprovalEntry({
    baseDir: unitRoot,
    scope: 'unit-spec',
    unitId: '05-workflow-proof-and-migration',
    artifacts: ['spec.md', 'plan.md', 'context.md'],
    sourceClassification: 'headless-check',
    sourceRef: 'ci',
    approvedAt: '2026-04-16T00:20:00Z'
  });
} catch {
  headlessApprovedRejected = true;
}

const rationaleHash = hashApprovalArtifacts(unitRoot, ['implementation-rationale.md']);

process.stdout.write(JSON.stringify({
  designStatus,
  unitStatusBefore,
  unitStatusAfter,
  missingDesignStatus,
  headlessApprovedRejected,
  roundTripEntries: loaded.entries.length,
  rationaleArtifactHashPresent: Boolean(rationaleHash.artifactSetHash)
}));
EOF
  )" || HELPER_EXIT=$?

  if [ "$HELPER_EXIT" -ne 0 ]; then
    fail "approvals helper node script exited with code $HELPER_EXIT"
  else
    assert_output_contains "$HELPER_OUTPUT" '"designStatus":"APPROVED"' "design approval stays approved when artifact set matches"
    assert_output_contains "$HELPER_OUTPUT" '"unitStatusBefore":"APPROVED"' "unit-spec approval stays approved when artifact set matches"
    assert_output_contains "$HELPER_OUTPUT" '"unitStatusAfter":"STALE"' "unit-spec approval becomes stale when spec changes"
    assert_output_contains "$HELPER_OUTPUT" '"missingDesignStatus":"MISSING"' "missing design lineage is distinguishable from stale lineage"
    assert_output_contains "$HELPER_OUTPUT" '"headlessApprovedRejected":true' "headless approval fabrication is rejected"
    assert_output_contains "$HELPER_OUTPUT" '"roundTripEntries":2' "approvals ledger round-trips both design and unit approvals"
    assert_output_contains "$HELPER_OUTPUT" '"rationaleArtifactHashPresent":true' "workflow proof fixture includes rationale as an auditable artifact"
  fi
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "audit-chain.workflow-proof"
