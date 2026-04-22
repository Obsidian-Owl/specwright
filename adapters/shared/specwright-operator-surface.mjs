import { formatApprovalStatusLine } from './specwright-approvals.mjs';
import { buildStatusCard } from './specwright-status-card.mjs';
import { formatCloseoutLines } from './specwright-closeout.mjs';

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

export function loadOperatorSurfaceSummary(stateInfo, work) {
  if (!stateInfo || !work) {
    return null;
  }
  const card = buildStatusCard(stateInfo, work);

  return {
    card,
    closeout: card?.closeout ?? null,
    approval: card?.approvals ?? null,
    warnings: Array.isArray(card?.warnings) ? card.warnings : [],
    nextCommand: card?.nextCommand ?? null
  };
}

function formatBranchStatusLine(branch, options = {}) {
  if (!branch) {
    return null;
  }

  const indent = options.indent ?? '  ';
  const expected = normalizeString(branch.expected);
  const observed = normalizeString(branch.observed);
  const status = normalizeString(branch.status) ?? 'unknown';

  if (expected && observed) {
    if (expected === observed) {
      return `${indent}Branch: ${observed} (${status})`;
    }

    return `${indent}Branch: expected ${expected}, observed ${observed} (${status})`;
  }

  if (observed) {
    return `${indent}Branch: observed ${observed} (${status})`;
  }

  if (expected) {
    return `${indent}Branch: expected ${expected} (${status})`;
  }

  return `${indent}Branch: unavailable (${status})`;
}

function formatWarningLines(warnings, options = {}) {
  const indent = options.indent ?? '  ';
  if (!Array.isArray(warnings) || warnings.length === 0) {
    return [];
  }

  return warnings
    .filter((warning) => {
      const code = normalizeString(warning?.code) ?? '';
      if (code.startsWith('approval-')) {
        return false;
      }

      return !['missing-closeout', 'branch-mismatch'].includes(code);
    })
    .map((warning) => normalizeString(warning?.summary))
    .filter(Boolean)
    .slice(0, 2)
    .map((summary) => `${indent}WARNING: ${summary}`);
}

function formatNextCommandLine(nextCommand, options = {}) {
  const normalizedNextCommand = normalizeString(nextCommand);
  if (!normalizedNextCommand) {
    return null;
  }

  const indent = options.indent ?? '  ';
  return `${indent}Next: ${normalizedNextCommand}`;
}

export function renderOperatorSurfaceLines(summary, options = {}) {
  if (!summary) {
    return [];
  }

  const indent = options.indent ?? '  ';
  const detailIndent = options.detailIndent ?? `${indent}  `;
  const bulletIndent = options.bulletIndent ?? `${detailIndent}- `;
  const lines = [];
  const branchLine = formatBranchStatusLine(summary.card?.branch, { indent });
  if (branchLine) {
    lines.push(branchLine);
  }

  lines.push(...formatCloseoutLines(summary.closeout, {
    indent,
    detailIndent,
    bulletIndent
  }));

  const approvalLine = formatApprovalStatusLine(summary.approval, { indent });
  if (approvalLine) {
    lines.push(approvalLine);
  }

  lines.push(...formatWarningLines(summary.warnings, { indent }));

  const nextCommandLine = formatNextCommandLine(summary.nextCommand, { indent });
  if (nextCommandLine) {
    lines.push(nextCommandLine);
  }

  return lines;
}

export function renderOperationalWarningLines(options = {}) {
  const indent = options.indent ?? '  ';
  const lines = [];
  const work = options.work;
  const ownerConflict = options.ownerConflict;

  if (work?.lock?.skill && work?.lock?.since) {
    lines.push(`${indent}WARNING: Lock held by "${work.lock.skill}" since ${work.lock.since}`);
  }

  if (ownerConflict) {
    lines.push(
      `${indent}WARNING: This work is already active in another top-level worktree (${ownerConflict.ownerWorktreeId}${ownerConflict.ownerBranch ? ` on ${ownerConflict.ownerBranch}` : ''}: ${ownerConflict.ownerWorktreePath}). Adopt/takeover required before mutating or shipping it here.`
    );
  }

  if (work?.status === 'shipping') {
    lines.push(
      `${indent}WARNING: Status is "shipping" — PR creation was in progress. Run /sw-ship to check if the PR was created or to retry.`
    );
  }

  return lines;
}

export function renderWorkInProgressSummary(options = {}) {
  const work = options.work;
  if (!work) {
    return '';
  }

  const indent = options.indent ?? '  ';
  const summary = options.summary ?? null;
  const lines = [
    'Specwright: Work in progress',
    `${indent}Unit: ${work.workId} (${work.status})`,
    work.unitId ? `${indent}Active Unit: ${work.unitId}` : null,
    `${indent}Progress: ${work.completedCount}/${work.totalCount} tasks`,
    `${indent}Gates: ${work.gatesSummary ?? summary?.card?.gates?.summary ?? 'No gates recorded yet.'}`,
    `${indent}Spec: ${work.specPath}`,
    `${indent}Plan: ${work.planPath}`,
    ...renderOperatorSurfaceLines(summary, { indent }),
    ...renderOperationalWarningLines({
      indent,
      work,
      ownerConflict: options.ownerConflict
    }),
    options.continuationContent || null
  ].filter(Boolean);

  return lines.join('\n');
}
