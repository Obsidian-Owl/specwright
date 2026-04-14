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

try {
  const stateInfo = loadSpecwrightState();
  const continuationPath = stateInfo.continuationPath;
  const work = normalizeActiveWork(stateInfo);
  const ownerConflict = findSelectedWorkOwnerConflict(stateInfo);

  if (!work || ['shipped', 'abandoned'].includes(work.status)) {
    process.exit(0);
  }

  const unitLine = work.unitId ? `  Active Unit: ${work.unitId}\n` : '';
  const lockWarning = work.lock
    ? `\n  WARNING: Lock held by "${work.lock.skill}" since ${work.lock.since}`
    : '';
  const ownershipWarning = ownerConflict
    ? `\n  WARNING: This work is already active in another top-level worktree (${ownerConflict.ownerWorktreeId}${ownerConflict.ownerBranch ? ` on ${ownerConflict.ownerBranch}` : ''}: ${ownerConflict.ownerWorktreePath}). Adopt/takeover required before mutating or shipping it here.`
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
        }
      }
      unlinkSync(continuationPath);
    } catch {
      // Best-effort continuation restore only.
    }
  }

  const shippingWarning = work.status === 'shipping'
    ? '\n  WARNING: Status is "shipping". Run /sw-ship to check PR state.'
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
    ownershipWarning,
    shippingWarning,
    continuationContent
  ].filter(Boolean).join('\n');

  process.stdout.write(summary + '\n');
} catch {
  process.exit(0);
}

process.exit(0);
