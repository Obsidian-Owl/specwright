/**
 * Specwright session-start hook.
 * Reads workflow.json on session start. If work is in progress,
 * outputs a recovery summary so Claude knows where to resume.
 * Also reads continuation.md if present (written by PreCompact hook).
 */

import { readFileSync, existsSync, unlinkSync } from 'fs';
import {
  findSelectedWorkOwnerConflict,
  loadSpecwrightState,
  normalizeActiveWork
} from '../../shared/specwright-state-paths.mjs';
import {
  loadOperatorSurfaceSummary,
  renderWorkInProgressSummary
} from '../../shared/specwright-operator-surface.mjs';

try {
  const stateInfo = loadSpecwrightState();
  const continuationPath = stateInfo.continuationPath;
  const work = normalizeActiveWork(stateInfo);
  const ownerConflict = findSelectedWorkOwnerConflict(stateInfo);
  const operatorSummary = loadOperatorSurfaceSummary(stateInfo, work);

  if (!work || ['shipped', 'abandoned'].includes(work.status)) {
    process.exit(0);
  }

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

  const summary = renderWorkInProgressSummary({
    work,
    summary: operatorSummary,
    ownerConflict,
    continuationContent
  });

  process.stdout.write(summary + '\n');
} catch (err) {
  // Don't block session on hook failure — degrade gracefully
  process.stderr.write(`Specwright: Failed to read state: ${err.message}\n`);
}

process.exit(0);
