import { join, resolve } from 'path';
import {
  assessApprovalEntry,
  loadApprovalsFile
} from './specwright-approvals.mjs';
import { loadCloseoutDigest } from './specwright-closeout.mjs';

const UNIT_APPROVAL_ARTIFACTS = ['spec.md', 'plan.md', 'context.md'];
const DESIGN_APPROVAL_ARTIFACTS = ['design.md', 'context.md', 'decisions.md'];
const CLOSEOUT_ABSENCE_LINE = 'Closeout: none yet (no stage-report.md or review-packet.md)';

function resolveRuntimeWorkRoot(stateInfo, work) {
  if (stateInfo?.repoStateRoot) {
    return join(stateInfo.repoStateRoot, 'work', work.workId);
  }

  return resolve(stateInfo?.lookupRoot ?? process.cwd(), '.specwright', 'work', work.workId);
}

function resolveWorkPaths(stateInfo, work) {
  const runtimeWorkRoot = resolveRuntimeWorkRoot(stateInfo, work);

  return {
    stageReportPath: work?.unitId
      ? join(runtimeWorkRoot, 'units', work.unitId, 'stage-report.md')
      : join(runtimeWorkRoot, 'stage-report.md'),
    reviewPacketPath: work?.workDirPath
      ? join(work.workDirPath, 'review-packet.md')
      : null,
    approvalsPath: work?.artifactsRoot
      ? join(work.artifactsRoot, work.workId, 'approvals.md')
      : join(runtimeWorkRoot, 'approvals.md')
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

function findLatestApprovalEntry(entries, { scope, unitId }) {
  if (!Array.isArray(entries)) {
    return null;
  }

  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (entry?.scope !== scope) {
      continue;
    }

    if ((entry?.unitId ?? null) !== (unitId ?? null)) {
      continue;
    }

    return entry;
  }

  return null;
}

function summarizeApproval(stateInfo, work, approvalsPath) {
  const target = resolveApprovalTarget(work);

  try {
    const approvalDocument = loadApprovalsFile(approvalsPath);
    const entry = findLatestApprovalEntry(approvalDocument.entries, target);
    const assessment = assessApprovalEntry(entry, {
      baseDir: target.baseDir,
      artifacts: target.artifacts
    });

    return {
      scope: target.scope,
      status: assessment.status,
      reasonCode: assessment.reasonCode ?? 'approved'
    };
  } catch (error) {
    if (error?.code !== 'ENOENT') {
      const message = error instanceof Error ? error.message : String(error);
      process.stderr.write(`[specwright] summarizeApproval failed for ${target.scope}: ${message}\n`);
    }

    return {
      scope: target.scope,
      status: 'MISSING',
      reasonCode: 'missing-entry'
    };
  }
}

export function loadOperatorSurfaceSummary(stateInfo, work) {
  if (!stateInfo || !work) {
    return null;
  }

  const paths = resolveWorkPaths(stateInfo, work);
  const closeout = loadCloseoutDigest({
    stageReportPath: paths.stageReportPath,
    reviewPacketPath: paths.reviewPacketPath
  });

  return {
    closeout,
    approval: summarizeApproval(stateInfo, work, paths.approvalsPath),
    paths
  };
}

export function renderOperatorSurfaceLines(summary, options = {}) {
  if (!summary) {
    return [];
  }

  const indent = options.indent ?? '  ';
  const detailIndent = options.detailIndent ?? `${indent}  `;
  const bulletIndent = options.bulletIndent ?? `${detailIndent}- `;
  const lines = [];

  if (summary.closeout?.source) {
    lines.push(`${indent}Closeout: ${summary.closeout.source}`);
    if (summary.closeout.headline) {
      lines.push(`${detailIndent}${summary.closeout.headline}`);
    }
    for (const bullet of (summary.closeout.bullets ?? []).slice(0, 2)) {
      lines.push(`${bulletIndent}${bullet}`);
    }
  } else {
    lines.push(`${indent}${CLOSEOUT_ABSENCE_LINE}`);
  }

  if (summary.approval) {
    lines.push(
      `${indent}Approval: ${summary.approval.scope} ${summary.approval.status} (${summary.approval.reasonCode})`
    );
  }

  return lines;
}
