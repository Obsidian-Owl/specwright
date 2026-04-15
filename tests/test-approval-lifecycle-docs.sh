#!/usr/bin/env bash
#
# Regression checks for Unit 02 — approval lifecycle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APPROVALS_PROTOCOL="$ROOT_DIR/core/protocols/approvals.md"
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

echo "=== approval lifecycle ==="
echo ""

for file in "$APPROVALS_PROTOCOL" "$APPROVALS_HELPER"; do
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
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
