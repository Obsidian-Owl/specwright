#!/usr/bin/env node

/**
 * Specwright SessionStart hook for Codex.
 * Emits concise active-work context and a fresh continuation snapshot if present.
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
      // Best-effort continuation restore only.
    }
  }

  const operatorSummary = loadOperatorSurfaceSummary(stateInfo, work);
  const summary = renderWorkInProgressSummary({
    work,
    summary: operatorSummary,
    ownerConflict,
    continuationContent
  });

  process.stdout.write(summary + '\n');
} catch {
  process.exit(0);
}

process.exit(0);
