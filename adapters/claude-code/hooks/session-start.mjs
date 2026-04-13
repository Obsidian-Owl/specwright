/**
 * Specwright session-start hook.
 * Reads workflow.json on session start. If work is in progress,
 * outputs a recovery summary so Claude knows where to resume.
 * Also reads continuation.md if present (written by PreCompact hook).
 */

import { readFileSync, existsSync, unlinkSync } from 'fs';
import { loadSpecwrightState, normalizeActiveWork } from '../../shared/specwright-state-paths.mjs';

try {
  const stateInfo = loadSpecwrightState();
  const continuationPath = stateInfo.continuationPath;
  const work = normalizeActiveWork(stateInfo);

  if (!work || ['shipped', 'abandoned'].includes(work.status)) {
    process.exit(0);
  }

  const lockWarning = work.lock
    ? `\n⚠ Lock held by "${work.lock.skill}" since ${work.lock.since}`
    : '';

  let continuationContent = '';
  if (existsSync(continuationPath)) {
    try {
      const raw = readFileSync(continuationPath, 'utf-8');
      const firstLine = raw.split('\n')[0] || '';
      const match = firstLine.match(/^Snapshot:\s*(.+)$/);

      if (match) {
        const snapshotTime = new Date(match[1].trim());
        const ageMs = Date.now() - snapshotTime.getTime();
        const twoHoursMs = 2 * 60 * 60 * 1000;

        if (!isNaN(snapshotTime.getTime()) && ageMs < twoHoursMs) {
          continuationContent = `\n--- Continuation Snapshot ---\n${raw}`;

          const correctionMatch = raw.match(/## Correction Summary\n([\s\S]*?)(?=\n## |\n---|$)/);
          if (correctionMatch && correctionMatch[1].trim()) {
            continuationContent += `\n--- Quality Corrections ---\nIn this build session, the following quality issues were found and should be avoided:\n${correctionMatch[1].trim()}`;
          }
        }
      }

      unlinkSync(continuationPath);
    } catch {
      // Ignore continuation read errors — not critical
    }
  }

  const unitLine = work.unitId ? `  Active Unit: ${work.unitId}\n` : '';
  const shippingWarning = work.status === 'shipping'
    ? '\n  ⚠ Status is "shipping" — PR creation was in progress. Run /sw-ship to check if the PR was created or to retry.'
    : '';

  const summary = [
    'Specwright: Work in progress',
    `  Unit: ${work.workId} (${work.status})`,
    unitLine ? unitLine.trimEnd() : null,
    `  Progress: ${work.completedCount}/${work.totalCount} tasks`,
    `  Gates: ${work.gatesSummary}`,
    `  Spec: ${work.specPath}`,
    `  Plan: ${work.planPath}`,
    lockWarning,
    shippingWarning,
    continuationContent
  ].filter(Boolean).join('\n');

  process.stdout.write(summary + '\n');
} catch (err) {
  // Don't block session on hook failure — degrade gracefully
  process.stderr.write(`Specwright: Failed to read state: ${err.message}\n`);
}

process.exit(0);
