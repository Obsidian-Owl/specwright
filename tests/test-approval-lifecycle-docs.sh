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
# The default Claude harness uses smoke mode to keep structural smoke within
# budget while still exercising fail-closed approval semantics.
APPROVAL_LIFECYCLE_MODE="${SPECWRIGHT_APPROVAL_LIFECYCLE_MODE:-full}"

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
assert_contains "$APPROVALS_PROTOCOL" 'never approval truth' "protocol forbids workflow.json as approval truth"

echo ""
echo "--- Shared helper behavior ---"
if [ "$APPROVAL_LIFECYCLE_MODE" = "full" ]; then
  HELPER_OUTPUT="$(
  APPROVALS_HELPER="$APPROVALS_HELPER" TEST_TMPDIR="$TEST_TMPDIR" APPROVAL_LIFECYCLE_MODE="$APPROVAL_LIFECYCLE_MODE" node --input-type=module <<'EOF'
import { mkdirSync, writeFileSync } from 'fs';
import { join } from 'path';
import { pathToFileURL } from 'url';

const helperPath = pathToFileURL(process.env.APPROVALS_HELPER).href;
const tmpDir = process.env.TEST_TMPDIR;
const helper = await import(helperPath);
const {
  createApprovalEntry,
  hashApprovalArtifacts,
  recordApproval,
  assessApprovalEntry,
  loadApprovalsFile,
  writeApprovalsFile
} = helper;
const mode = process.env.APPROVAL_LIFECYCLE_MODE ?? 'full';
const isFull = mode === 'full';

const artifactsRoot = join(tmpDir, 'artifacts');
mkdirSync(artifactsRoot, { recursive: true });
writeFileSync(join(artifactsRoot, 'design.md'), 'design v1\n', 'utf8');
writeFileSync(join(artifactsRoot, 'context.md'), 'context v1\n', 'utf8');

const hashA = hashApprovalArtifacts(artifactsRoot, ['design.md', 'context.md']);
const hashB = hashApprovalArtifacts(artifactsRoot, ['context.md', 'design.md']);

let initialDoc = null;
let stale = { status: 'SKIPPED' };
let restored = { status: 'SKIPPED' };
let doc = null;
let loaded = { entries: [] };
let acceptedDoc = null;
let acceptedLoaded = { entries: [] };
let acceptedReasonPreserved = false;
let acceptedConfigPathPreserved = false;
let acceptedExpiryPreserved = false;
let acceptedIndependentStatuses = [];
let acceptedMissingExpiryStatus = 'SKIPPED';
let acceptedInvalidExpiryStatus = 'SKIPPED';
let acceptedExpiredStatus = 'SKIPPED';
let acceptedMissingUnitStatus = 'SKIPPED';
let acceptedMissingMutantIdStatus = 'SKIPPED';
let acceptedMissingReasonStatus = 'SKIPPED';
let acceptedMissingConfigPathStatus = 'SKIPPED';
let acceptedMissingApprovedAtStatus = 'SKIPPED';
let acceptedInvalidApprovedAtStatus = 'SKIPPED';

if (isFull) {
  initialDoc = recordApproval(null, {
    baseDir: artifactsRoot,
    scope: 'design',
    artifacts: ['design.md', 'context.md'],
    sourceClassification: 'command',
    sourceRef: '/sw-plan',
    approvedAt: '2026-04-15T00:00:00Z'
  });

  writeFileSync(join(artifactsRoot, 'design.md'), 'design v2\n', 'utf8');
  stale = assessApprovalEntry(initialDoc.entries[0], { baseDir: artifactsRoot });
  writeFileSync(join(artifactsRoot, 'design.md'), 'design v1\n', 'utf8');
  restored = assessApprovalEntry(initialDoc.entries[0], { baseDir: artifactsRoot });

  doc = recordApproval(initialDoc, {
    baseDir: artifactsRoot,
    scope: 'design',
    artifacts: ['design.md', 'context.md'],
    sourceClassification: 'review-comment',
    sourceRef: 'https://example.invalid/review/1',
    approvedAt: '2026-04-15T01:00:00Z'
  });

  writeApprovalsFile(join(artifactsRoot, 'approvals.md'), doc);
  loaded = loadApprovalsFile(join(artifactsRoot, 'approvals.md'));

  acceptedDoc = recordApproval(null, {
    baseDir: artifactsRoot,
    scope: 'accepted-mutant',
    unitId: '02-approval-lifecycle',
    mutantId: 'mut-1',
    reason: 'equivalent defensive branch',
    configPath: 'gates.tests.mutation.acceptedMutants',
    artifacts: ['design.md', 'context.md'],
    sourceClassification: 'command',
    sourceRef: '/sw-verify --accept-mutant mut-1 --reason "equivalent defensive branch"',
    approvedAt: '2026-04-15T03:00:00Z',
    expiresAt: '2026-07-14T03:00:00Z'
  });

  acceptedDoc = recordApproval(acceptedDoc, {
    baseDir: artifactsRoot,
    scope: 'accepted-mutant',
    unitId: '02-approval-lifecycle',
    mutantId: 'mut-2',
    reason: 'log-only branch',
    configPath: 'gates.tests.mutation.acceptedMutants',
    artifacts: ['design.md', 'context.md'],
    sourceClassification: 'command',
    sourceRef: '/sw-verify --accept-mutant mut-2 --reason "log-only branch"',
    approvedAt: '2026-04-15T04:00:00Z',
    expiresAt: '2026-07-14T04:00:00Z'
  });

  acceptedDoc = recordApproval(acceptedDoc, {
    baseDir: artifactsRoot,
    scope: 'accepted-mutant',
    unitId: '02-approval-lifecycle',
    mutantId: 'mut-1',
    reason: 'equivalent defensive branch, refreshed',
    configPath: 'gates.tests.mutation.acceptedMutants',
    artifacts: ['design.md', 'context.md'],
    sourceClassification: 'command',
    sourceRef: '/sw-verify --accept-mutant mut-1 --reason "equivalent defensive branch, refreshed"',
    approvedAt: '2026-04-15T05:00:00Z',
    expiresAt: '2026-07-15T05:00:00Z'
  });

  writeApprovalsFile(join(artifactsRoot, 'accepted-approvals.md'), acceptedDoc);
  acceptedLoaded = loadApprovalsFile(join(artifactsRoot, 'accepted-approvals.md'));
  const latestAccepted = acceptedLoaded.entries[acceptedLoaded.entries.length - 1];
  acceptedReasonPreserved = latestAccepted?.reason === 'equivalent defensive branch, refreshed';
  acceptedConfigPathPreserved =
    latestAccepted?.configPath === 'gates.tests.mutation.acceptedMutants';
  acceptedExpiryPreserved = latestAccepted?.expiresAt === '2026-07-15T05:00:00Z';
  acceptedIndependentStatuses = acceptedLoaded.entries.map((entry) => `${entry.mutantId}:${entry.status}`);
  acceptedMissingExpiryStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      expiresAt: undefined
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedInvalidExpiryStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      expiresAt: 'not-a-date'
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedExpiredStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      expiresAt: '2020-01-01T00:00:00Z'
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedMissingUnitStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      unitId: undefined
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedMissingMutantIdStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      mutantId: undefined
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedMissingReasonStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      reason: undefined
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedMissingConfigPathStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      configPath: undefined
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedMissingApprovedAtStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      approvedAt: undefined
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  acceptedInvalidApprovedAtStatus = assessApprovalEntry(
    {
      ...latestAccepted,
      approvedAt: 'not-a-date'
    },
    {
      baseDir: artifactsRoot
    }
  ).status;
  writeFileSync(
    join(artifactsRoot, 'broken-approvals.md'),
    '# Approvals\n\n<!-- approvals-ledger:start -->\n```json\n{\n```\n<!-- approvals-ledger:end -->\n',
    'utf8'
  );
}

let headlessApprovedRejected = false;
try {
  createApprovalEntry({
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

let acceptedMutantMissingUnitRejected = false;
try {
  createApprovalEntry({
    baseDir: artifactsRoot,
    scope: 'accepted-mutant',
    mutantId: 'mut-3',
    reason: 'equivalent guard clause',
    configPath: 'gates.tests.mutation.acceptedMutants',
    artifacts: ['design.md']
  });
} catch {
  acceptedMutantMissingUnitRejected = true;
}

let invalidStatusRejected = false;
try {
  createApprovalEntry({
    baseDir: artifactsRoot,
    scope: 'design',
    artifacts: ['design.md'],
    status: 'GARBAGE'
  });
} catch {
  invalidStatusRejected = true;
}

let invalidSourceRejected = false;
try {
  createApprovalEntry({
    baseDir: artifactsRoot,
    scope: 'design',
    artifacts: ['design.md'],
    sourceClassification: 'headless_check'
  });
} catch {
  invalidSourceRejected = true;
}

let traversalRejected = false;
try {
  hashApprovalArtifacts(artifactsRoot, ['../outside.txt']);
} catch {
  traversalRejected = true;
}

let malformedLedgerRejected = !isFull;
if (isFull) {
  try {
    loadApprovalsFile(join(artifactsRoot, 'broken-approvals.md'));
  } catch {
    malformedLedgerRejected = true;
  }
}

const missing = assessApprovalEntry(null, { baseDir: artifactsRoot, artifacts: ['design.md'] });

process.stdout.write(JSON.stringify({
  mode,
  sameHash: hashA.artifactSetHash === hashB.artifactSetHash,
  staleStatus: stale.status,
  restoredStatus: restored.status,
  supersededFirst: doc?.entries?.[0]?.status ?? null,
  latestStatus: doc?.entries?.[1]?.status ?? null,
  roundTripEntries: loaded.entries.length,
  acceptedReasonPreserved,
  acceptedConfigPathPreserved,
  acceptedExpiryPreserved,
  acceptedIndependentStatuses,
  acceptedMissingExpiryStatus,
  acceptedInvalidExpiryStatus,
  acceptedExpiredStatus,
  acceptedMissingUnitStatus,
  acceptedMissingMutantIdStatus,
  acceptedMissingReasonStatus,
  acceptedMissingConfigPathStatus,
  acceptedMissingApprovedAtStatus,
  acceptedInvalidApprovedAtStatus,
  headlessApprovedRejected,
  acceptedMutantMissingUnitRejected,
  invalidStatusRejected,
  invalidSourceRejected,
  traversalRejected,
  malformedLedgerRejected,
  missingStatus: missing.status
}));
EOF
)"
  assert_output_contains "$HELPER_OUTPUT" '"staleStatus":"STALE"' "helper marks changed artifact sets as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"sameHash":true' "helper hashes artifact sets deterministically"
  assert_output_contains "$HELPER_OUTPUT" '"headlessApprovedRejected":true' "headless approval source cannot produce APPROVED entries"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMutantMissingUnitRejected":true' "helper rejects accepted-mutant approvals without a unit id"
  assert_output_contains "$HELPER_OUTPUT" '"invalidStatusRejected":true' "helper rejects unknown approval statuses"
  assert_output_contains "$HELPER_OUTPUT" '"invalidSourceRejected":true' "helper rejects unknown source classifications"
  assert_output_contains "$HELPER_OUTPUT" '"traversalRejected":true' "helper rejects artifact paths that escape the work dir"
  assert_output_contains "$HELPER_OUTPUT" '"supersededFirst":"SUPERSEDED"' "helper supersedes prior approval entries for the same scope"
  assert_output_contains "$HELPER_OUTPUT" '"latestStatus":"APPROVED"' "helper records new approvals as APPROVED"
  assert_output_contains "$HELPER_OUTPUT" '"roundTripEntries":2' "helper round-trips approvals.md through disk"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedReasonPreserved":true' "helper preserves accepted-mutant reasons"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedConfigPathPreserved":true' "helper preserves accepted-mutant config linkage"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedExpiryPreserved":true' "helper preserves accepted-mutant expiry timestamps"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedIndependentStatuses":["mut-1:SUPERSEDED","mut-2:APPROVED","mut-1:APPROVED"]' "helper supersedes accepted-mutant entries by mutant id without collapsing other mutants"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMissingExpiryStatus":"STALE"' "helper marks accepted-mutant lineage without expiry as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedInvalidExpiryStatus":"STALE"' "helper marks accepted-mutant lineage with invalid expiry as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedExpiredStatus":"STALE"' "helper marks expired accepted-mutant lineage as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMissingUnitStatus":"STALE"' "helper marks accepted-mutant lineage without unit id as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMissingMutantIdStatus":"STALE"' "helper marks accepted-mutant lineage without mutant id as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMissingReasonStatus":"STALE"' "helper marks accepted-mutant lineage without reason as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMissingConfigPathStatus":"STALE"' "helper marks accepted-mutant lineage without config linkage as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedMissingApprovedAtStatus":"STALE"' "helper marks accepted-mutant lineage without approvedAt as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"acceptedInvalidApprovedAtStatus":"STALE"' "helper marks accepted-mutant lineage with invalid approvedAt as STALE"
  assert_output_contains "$HELPER_OUTPUT" '"restoredStatus":"APPROVED"' "helper treats restored artifact hashes as APPROVED again"
  assert_output_contains "$HELPER_OUTPUT" '"malformedLedgerRejected":true' "helper rejects malformed approvals ledgers"
  assert_output_contains "$HELPER_OUTPUT" '"missingStatus":"MISSING"' "helper distinguishes missing approval entries from stale ones"
else
  assert_contains "$APPROVALS_HELPER" "approval status" "helper smoke path still checks fail-closed unknown status behavior"
  assert_contains "$APPROVALS_HELPER" "source classification" "helper smoke path still checks fail-closed unknown source behavior"
  assert_contains "$APPROVALS_HELPER" "Artifact path escapes baseDir" "helper smoke path still checks artifact containment behavior"
  assert_contains "$APPROVALS_HELPER" "Approval entries must record a status." "helper smoke path still checks missing-entry status behavior"
  pass "approval lifecycle smoke mode skips the full helper fixture run"
fi
emit_coverage_marker "approval-lifecycle.fail-closed"

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

if [ "$APPROVAL_LIFECYCLE_MODE" = "full" ]; then
  echo ""
  echo "--- Protocol index visibility ---"
  assert_contains "$ROOT_CLAUDE" "approvals.md" "root CLAUDE.md lists approvals.md in the protocol index"
  assert_contains "$ADAPTER_CLAUDE" "approvals.md" "adapter CLAUDE.md lists approvals.md in the protocol index"
  assert_contains "$ROOT_AGENTS" "approvals.md" "AGENTS.md lists approvals.md in the protocol index"
else
  pass "approval lifecycle smoke mode skips protocol index visibility sweep"
fi

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
