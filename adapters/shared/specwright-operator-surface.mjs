import { formatApprovalStatusLine } from './specwright-approvals.mjs';
import { buildStatusCard } from './specwright-status-card.mjs';
import { formatCloseoutLines } from './specwright-closeout.mjs';

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
    blockers: Array.isArray(card?.blockers) ? card.blockers : [],
    nextCommand: card?.nextCommand ?? null
  };
}

export function renderOperatorSurfaceLines(summary, options = {}) {
  if (!summary) {
    return [];
  }

  const indent = options.indent ?? '  ';
  const detailIndent = options.detailIndent ?? `${indent}  `;
  const bulletIndent = options.bulletIndent ?? `${detailIndent}- `;
  const lines = formatCloseoutLines(summary.closeout, {
    indent,
    detailIndent,
    bulletIndent
  });
  const approvalLine = formatApprovalStatusLine(summary.approval, { indent });

  if (approvalLine) {
    lines.push(approvalLine);
  }

  return lines;
}
