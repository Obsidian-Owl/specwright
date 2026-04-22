import { mkdirSync, writeFileSync } from 'fs';
import { dirname, join, resolve } from 'path';

import {
  assessApprovalEntry,
  findLatestApprovalEntry,
  loadApprovalsFile,
  summarizeApprovalAssessment
} from './specwright-approvals.mjs';
import { loadCloseoutDigest } from './specwright-closeout.mjs';

const UNIT_APPROVAL_ARTIFACTS = ['spec.md', 'plan.md', 'context.md'];
const DESIGN_APPROVAL_ARTIFACTS = ['design.md', 'context.md', 'decisions.md'];

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function resolveRuntimeWorkRoot(stateInfo, work) {
  if (stateInfo?.repoStateRoot) {
    return join(stateInfo.repoStateRoot, 'work', work.workId);
  }

  return resolve(stateInfo?.lookupRoot ?? process.cwd(), '.specwright', 'work', work.workId);
}

function resolveWorkPaths(stateInfo, work) {
  const runtimeWorkRoot = resolveRuntimeWorkRoot(stateInfo, work);

  return {
    runtimeWorkRoot,
    stageReportPath: work?.unitId
      ? join(runtimeWorkRoot, 'units', work.unitId, 'stage-report.md')
      : join(runtimeWorkRoot, 'stage-report.md'),
    reviewPacketPath: work?.workDirPath
      ? join(work.workDirPath, 'review-packet.md')
      : null,
    approvalsPath: work?.artifactsRoot
      ? join(work.artifactsRoot, work.workId, 'approvals.md')
      : join(runtimeWorkRoot, 'approvals.md'),
    statusCardPath: work?.unitId
      ? join(runtimeWorkRoot, 'units', work.unitId, 'status-card.json')
      : join(runtimeWorkRoot, 'status-card.json')
  };
}

function resolveApprovalTarget(work) {
  if (work?.unitId) {
    return {
      scope: 'unit-spec',
      unitId: work.unitId,
      baseDir: work.workDirPath,
      artifacts: UNIT_APPROVAL_ARTIFACTS
    };
  }

  return {
    scope: 'design',
    unitId: null,
    baseDir: work?.artifactsRoot ? join(work.artifactsRoot, work.workId) : work?.workDirPath,
    artifacts: DESIGN_APPROVAL_ARTIFACTS
  };
}

function summarizeApproval(work, approvalsPath) {
  const target = resolveApprovalTarget(work);

  try {
    const approvalDocument = loadApprovalsFile(approvalsPath);
    const entry = findLatestApprovalEntry(approvalDocument.entries, target);
    const assessment = assessApprovalEntry(entry, {
      baseDir: target.baseDir,
      artifacts: target.artifacts
    });
    return summarizeApprovalAssessment(target.scope, assessment);
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      const message = error instanceof Error ? error.message : String(error);
      process.stderr.write(`[specwright] summarizeApproval failed for ${target.scope}: ${message}\n`);
    }
    return summarizeApprovalAssessment(target.scope, {
      status: 'MISSING',
      reasonCode: 'missing-entry'
    });
  }
}

function summarizeGates(gates) {
  const entries = Object.entries(gates ?? {});
  if (entries.length === 0) {
    return {
      status: 'not-run',
      summary: 'No gates recorded yet.',
      counts: {
        pass: 0,
        warn: 0,
        fail: 0,
        skip: 0,
        other: 0
      }
    };
  }

  const counts = {
    pass: 0,
    warn: 0,
    fail: 0,
    skip: 0,
    other: 0
  };

  for (const [, gate] of entries) {
    switch (gate?.verdict) {
      case 'PASS':
        counts.pass += 1;
        break;
      case 'WARN':
        counts.warn += 1;
        break;
      case 'FAIL':
      case 'ERROR':
        counts.fail += 1;
        break;
      case 'SKIP':
        counts.skip += 1;
        break;
      default:
        counts.other += 1;
        break;
    }
  }

  let status = 'pass';
  if (counts.fail > 0) {
    status = 'fail';
  } else if (counts.warn > 0 || counts.skip > 0 || counts.other > 0) {
    status = 'warn';
  } else if (counts.pass === 0) {
    status = 'not-run';
  }

  const summaryParts = [];
  if (counts.pass > 0) {
    summaryParts.push(`${counts.pass} PASS`);
  }
  if (counts.warn > 0) {
    summaryParts.push(`${counts.warn} WARN`);
  }
  if (counts.fail > 0) {
    summaryParts.push(`${counts.fail} FAIL`);
  }
  if (counts.skip > 0) {
    summaryParts.push(`${counts.skip} SKIP`);
  }
  if (counts.other > 0) {
    summaryParts.push(`${counts.other} OTHER`);
  }

  return {
    status,
    summary: summaryParts.join(', '),
    counts
  };
}

function summarizeBranch(stateInfo, work) {
  const expected = normalizeString(stateInfo?.workflow?.branch) ?? normalizeString(work?.branch);
  const observed = normalizeString(stateInfo?.session?.branch)
    ?? (stateInfo?.layout === 'legacy' ? normalizeString(work?.branch) : null);
  let status = 'unknown';

  if (expected && observed) {
    status = expected === observed ? 'match' : 'mismatch';
  }

  return {
    expected,
    observed,
    status
  };
}

function hasFreshnessBlock(stateInfo) {
  const freshnessStatus = normalizeString(stateInfo?.workflow?.freshness?.status);
  return ['stale', 'diverged', 'blocked'].includes(freshnessStatus);
}

function hasRemainingWorkUnits(workflow, currentUnitId) {
  if (!Array.isArray(workflow?.workUnits) || workflow.workUnits.length === 0) {
    return false;
  }

  const normalizedCurrentUnitId = normalizeString(currentUnitId);
  const currentIndex = workflow.workUnits.findIndex(
    (unit) => normalizeString(unit?.id) === normalizedCurrentUnitId
  );
  const candidateUnits = currentIndex >= 0
    ? workflow.workUnits.slice(currentIndex + 1)
    : workflow.workUnits;

  return candidateUnits.some((unit) => {
    const status = normalizeString(unit?.status);
    return Boolean(status) && !['shipped', 'abandoned'].includes(status);
  });
}

function nextCommandFor(work, options = {}) {
  const stage = normalizeString(work?.status);
  if (!stage) {
    return '/sw-design';
  }

  const gateCounts = options.gates?.counts ?? {};

  switch (stage) {
    case 'designing':
      return '/sw-plan';
    case 'planning':
      return '/sw-build';
    case 'building':
      return work?.tasksTotal != null && work?.completedCount >= work.tasksTotal
        ? '/sw-verify'
        : '/sw-build';
    case 'verifying':
      if (hasFreshnessBlock(options.stateInfo)) {
        return '/sw-verify';
      }

      if ((gateCounts.fail ?? 0) > 0) {
        return '/sw-build';
      }

      if (
        (gateCounts.pass ?? 0) > 0 ||
        (gateCounts.warn ?? 0) > 0 ||
        (gateCounts.skip ?? 0) > 0
      ) {
        return '/sw-ship';
      }

      return '/sw-verify';
    case 'shipping':
      return '/sw-ship';
    case 'shipped':
      return hasRemainingWorkUnits(options.stateInfo?.workflow, work?.unitId)
        ? '/sw-build'
        : '/sw-learn';
    default:
      return '/sw-design';
  }
}

function buildWarnings(stateInfo, approval, closeout, branch) {
  const warnings = [];

  if (approval && approval.status !== 'APPROVED') {
    warnings.push({
      code: `approval-${approval.reasonCode ?? 'unknown'}`,
      summary: approval.summary
    });
  }

  if (!closeout?.source) {
    warnings.push({
      code: 'missing-closeout',
      summary: 'No stage-report.md or review-packet.md is available yet.'
    });
  }

  if (branch?.status === 'mismatch') {
    warnings.push({
      code: 'branch-mismatch',
      summary: `Expected ${branch.expected} but observed ${branch.observed}.`
    });
  }

  if (stateInfo?.usedFallback) {
    warnings.push({
      code: 'degraded-root-resolution',
      summary: 'Specwright is using degraded root-resolution fallback.'
    });
  }

  return warnings;
}

export function resolveStatusCardPath(stateInfo, work) {
  return resolveWorkPaths(stateInfo, work).statusCardPath;
}

export function buildStatusCard(stateInfo, work) {
  if (!stateInfo || !work) {
    return null;
  }

  const paths = resolveWorkPaths(stateInfo, work);
  const approval = summarizeApproval(work, paths.approvalsPath);
  const closeout = loadCloseoutDigest({
    stageReportPath: paths.stageReportPath,
    reviewPacketPath: paths.reviewPacketPath
  });
  const branch = summarizeBranch(stateInfo, work);
  const gates = summarizeGates(work.gates);
  const warnings = buildWarnings(stateInfo, approval, closeout, branch);

  return {
    format: 'status-card/v1',
    workId: work.workId,
    description: normalizeString(stateInfo?.workflow?.description),
    stage: normalizeString(work.status),
    currentUnitId: normalizeString(work.unitId),
    targetRef: stateInfo?.workflow?.targetRef ?? null,
    baselineCommit: normalizeString(stateInfo?.workflow?.baselineCommit),
    branch,
    approvals: approval,
    gates,
    closeout,
    warnings,
    nextCommand: nextCommandFor(work, { gates, stateInfo })
  };
}

export function writeStatusCard(path, card) {
  mkdirSync(dirname(path), { recursive: true });
  const contents = JSON.stringify(card, null, 2) + '\n';
  writeFileSync(path, contents, 'utf8');
  return contents;
}
