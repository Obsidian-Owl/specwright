#!/usr/bin/env bash
#
# Regression checks for Unit 02 — approval lifecycle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APPROVALS_PROTOCOL="$ROOT_DIR/core/protocols/approvals.md"
APPROVALS_HELPER="$ROOT_DIR/adapters/shared/specwright-approvals.mjs"
DESIGN_SKILL="$ROOT_DIR/core/skills/sw-design/SKILL.md"
PLAN_SKILL="$ROOT_DIR/core/skills/sw-plan/SKILL.md"
BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
ROOT_CLAUDE="$ROOT_DIR/CLAUDE.md"
ADAPTER_CLAUDE="$ROOT_DIR/adapters/claude-code/CLAUDE.md"
ROOT_AGENTS="$ROOT_DIR/AGENTS.md"
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

echo "=== approval lifecycle ==="
echo ""

for file in "$APPROVALS_PROTOCOL" "$APPROVALS_HELPER" "$DESIGN_SKILL" "$PLAN_SKILL" "$BUILD_SKILL" "$VERIFY_SKILL" "$ROOT_CLAUDE" "$ADAPTER_CLAUDE" "$ROOT_AGENTS"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Approval protocol contract ---"
assert_contains "$APPROVALS_PROTOCOL" "\`APPROVED\`" "protocol defines APPROVED status"
assert_contains "$APPROVALS_PROTOCOL" "\`STALE\`" "protocol defines STALE status"
assert_contains "$APPROVALS_PROTOCOL" "\`SUPERSEDED\`" "protocol defines SUPERSEDED status"
assert_contains "$APPROVALS_PROTOCOL" "\`command\`" "protocol defines command approval source"
assert_contains "$APPROVALS_PROTOCOL" "\`review-comment\`" "protocol defines review-comment approval source"
assert_contains "$APPROVALS_PROTOCOL" "\`external-record\`" "protocol defines external-record approval source"
assert_contains "$APPROVALS_PROTOCOL" "\`headless-check\`" "protocol defines headless-check approval source"
assert_contains "$APPROVALS_PROTOCOL" 'workflow.json is never approval truth' "protocol forbids workflow.json as approval truth"

echo ""
echo "--- Shared helper behavior ---"
HELPER_OUTPUT="$(
  APPROVALS_HELPER="$APPROVALS_HELPER" TEST_TMPDIR="$TEST_TMPDIR" node --input-type=module <<'EOF'
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import { pathToFileURL } from 'url';

const helperPath = pathToFileURL(process.env.APPROVALS_HELPER).href;
const tmpDir = process.env.TEST_TMPDIR;
const helper = await import(helperPath);
const {
  hashApprovalArtifacts,
  recordApproval,
  assessApprovalEntry,
  loadApprovalsFile,
  writeApprovalsFile
} = helper;

const artifactsRoot = join(tmpDir, 'artifacts');
mkdirSync(artifactsRoot, { recursive: true });
writeFileSync(join(artifactsRoot, 'design.md'), 'design v1\n', 'utf8');
writeFileSync(join(artifactsRoot, 'context.md'), 'context v1\n', 'utf8');

const hashA = hashApprovalArtifacts(artifactsRoot, ['design.md', 'context.md']);
const hashB = hashApprovalArtifacts(artifactsRoot, ['context.md', 'design.md']);

let doc = recordApproval(null, {
  baseDir: artifactsRoot,
  scope: 'design',
  artifacts: ['design.md', 'context.md'],
  sourceClassification: 'command',
  sourceRef: '/sw-plan',
  approvedAt: '2026-04-15T00:00:00Z'
});

writeFileSync(join(artifactsRoot, 'design.md'), 'design v2\n', 'utf8');
const stale = assessApprovalEntry(doc.entries[0], { baseDir: artifactsRoot });

doc = recordApproval(doc, {
  baseDir: artifactsRoot,
  scope: 'design',
  artifacts: ['design.md', 'context.md'],
  sourceClassification: 'review-comment',
  sourceRef: 'https://example.invalid/review/1',
  approvedAt: '2026-04-15T01:00:00Z'
});

writeApprovalsFile(join(artifactsRoot, 'approvals.md'), doc);
const loaded = loadApprovalsFile(join(artifactsRoot, 'approvals.md'));

let headlessApprovedRejected = false;
try {
  recordApproval(loaded, {
    baseDir: artifactsRoot,
    scope: 'unit-spec',
    unitId: '02-approval-lifecycle',
    artifacts: ['design.md'],
    sourceClassification: 'headless-check',
    sourceRef: 'ci',
    approvedAt: '2026-04-15T02:00:00Z'
  });
} catch {
  headlessApprovedRejected = true;
}

process.stdout.write(JSON.stringify({
  sameHash: hashA.artifactSetHash === hashB.artifactSetHash,
  staleStatus: stale.status,
  supersededFirst: doc.entries[0].status,
  latestStatus: doc.entries[1].status,
  roundTripEntries: loaded.entries.length,
  headlessApprovedRejected
}));
EOF
)"
assert_output_contains "$HELPER_OUTPUT" '"sameHash":true' "helper hashes artifact sets deterministically"
assert_output_contains "$HELPER_OUTPUT" '"staleStatus":"STALE"' "helper marks changed artifact sets as STALE"
assert_output_contains "$HELPER_OUTPUT" '"supersededFirst":"SUPERSEDED"' "helper supersedes prior approval entries for the same scope"
assert_output_contains "$HELPER_OUTPUT" '"latestStatus":"APPROVED"' "helper records new approvals as APPROVED"
assert_output_contains "$HELPER_OUTPUT" '"roundTripEntries":2' "helper round-trips approvals.md through disk"
assert_output_contains "$HELPER_OUTPUT" '"headlessApprovedRejected":true' "headless approval source cannot produce APPROVED entries"

echo ""
echo "--- Lifecycle skill wiring ---"
assert_contains "$DESIGN_SKILL" "artifact set awaiting approval" "sw-design identifies the design approval target"
assert_contains "$DESIGN_SKILL" "does not write \`APPROVED\` entries itself" "sw-design stays pending until a later stage records approval"
assert_contains "$PLAN_SKILL" "Interactive \`/sw-plan\` runs may write an \`APPROVED\` \`design\` entry" "sw-plan records design approval on entry"
assert_contains "$PLAN_SKILL" "headless runs must validate existing human approval" "sw-plan forbids headless design approval fabrication"
assert_contains "$BUILD_SKILL" "Interactive \`/sw-build\` runs may record an \`APPROVED\` \`unit-spec\` entry" "sw-build records unit-spec approval on entry"
assert_contains "$BUILD_SKILL" "Never move approval truth into \`workflow.json\`" "sw-build keeps approval truth out of workflow.json"
assert_contains "$VERIFY_SKILL" "Missing, \`STALE\`, or" "sw-verify checks approval freshness states"
assert_contains "$VERIFY_SKILL" "\`SUPERSEDED\` lineage becomes a distinct approval finding" "sw-verify treats superseded approval lineage distinctly"
assert_contains "$VERIFY_SKILL" "Approval Lineage" "sw-verify reports approval lineage separately from gate findings"
assert_contains "$VERIFY_SKILL" "never create \`APPROVED\` entries" "sw-verify preserves headless non-approval behavior"

echo ""
echo "--- Protocol index visibility ---"
assert_contains "$ROOT_CLAUDE" "approvals.md" "root CLAUDE.md lists approvals.md in the protocol index"
assert_contains "$ADAPTER_CLAUDE" "approvals.md" "adapter CLAUDE.md lists approvals.md in the protocol index"
assert_contains "$ROOT_AGENTS" "approvals.md" "AGENTS.md lists approvals.md in the protocol index"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
