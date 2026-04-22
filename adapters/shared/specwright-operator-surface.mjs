import { formatApprovalStatusLine } from './specwright-approvals.mjs';
import { buildStatusCard } from './specwright-status-card.mjs';
import { formatCloseoutLines } from './specwright-closeout.mjs';

const MAX_RENDERED_WARNING_LINES = 2;
const APPROVAL_WARNING_PREFIX = 'approval-';
// Warning codes emitted by buildStatusCard that already have dedicated surface
// rendering in this module. Keep in sync with specwright-status-card.mjs.
const SUPPRESSED_WARNING_CODES = new Set(['missing-closeout', 'branch-mismatch']);

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

  const significantWarnings = warnings
    .filter((warning) => {
      const code = normalizeString(warning?.code) ?? '';
      if (code.startsWith(APPROVAL_WARNING_PREFIX)) {
        return false;
      }

      return !SUPPRESSED_WARNING_CODES.has(code);
    })
    .map((warning) => normalizeString(warning?.summary))
    .filter(Boolean);
  const visibleWarnings = significantWarnings.slice(0, MAX_RENDERED_WARNING_LINES);
  const lines = visibleWarnings.map((summary) => `${indent}WARNING: ${summary}`);
  const hiddenWarningCount = significantWarnings.length - visibleWarnings.length;
  if (hiddenWarningCount > 0) {
    const noun = hiddenWarningCount === 1 ? 'warning' : 'warnings';
    lines.push(`${indent}... and ${hiddenWarningCount} more ${noun} - run /sw-status for full detail`);
  }

  return lines;
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

function renderOperationalWarningLines(options = {}) {
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
  const gatesSummary = normalizeString(work.gatesSummary)
    ?? normalizeString(summary?.card?.gates?.summary)
    ?? 'No gates recorded yet.';
  const lines = [
    'Specwright: Work in progress',
    `${indent}Unit: ${work.workId} (${work.status})`,
    work.unitId ? `${indent}Active Unit: ${work.unitId}` : null,
    `${indent}Progress: ${work.completedCount}/${work.totalCount} tasks`,
    `${indent}Gates: ${gatesSummary}`,
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
