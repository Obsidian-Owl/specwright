#!/usr/bin/env node

/**
 * Specwright SessionStart hook for Codex.
 * Emits concise active-work context and a fresh continuation snapshot if present.
 */

import { readFileSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';

const cwd = process.cwd();
const statePath = join(cwd, '.specwright', 'state', 'workflow.json');
const continuationPath = join(cwd, '.specwright', 'state', 'continuation.md');

if (!existsSync(statePath)) {
  process.exit(0);
}

try {
  const state = JSON.parse(readFileSync(statePath, 'utf-8'));
  const work = state?.currentWork;

  if (!work || ['shipped', 'abandoned'].includes(work.status)) {
    process.exit(0);
  }

  const completed = work.tasksCompleted?.length ?? 0;
  const total = work.tasksTotal ?? '?';
  const workDir = work.workDir || `.specwright/work/${work.id}`;
  const unitLine = work.unitId ? `  Active Unit: ${work.unitId}\n` : '';

  const gatesSummary = Object.entries(state.gates || {})
    .map(([name, g]) => `${name}: ${g.status}`)
    .join(', ') || 'none run';

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
    `  Unit: ${work.id} (${work.status})`,
    unitLine ? unitLine.trimEnd() : null,
    `  Progress: ${completed}/${total} tasks`,
    `  Gates: ${gatesSummary}`,
    `  Spec: ${workDir}/spec.md`,
    `  Plan: ${workDir}/plan.md`,
    shippingWarning,
    continuationContent
  ].filter(Boolean).join('\n');

  process.stdout.write(summary + '\n');
} catch {
  process.exit(0);
}

process.exit(0);
