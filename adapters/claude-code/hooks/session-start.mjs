/**
 * Specwright session-start hook.
 * Reads workflow.json on session start. If work is in progress,
 * outputs a recovery summary so Claude knows where to resume.
 * Also reads continuation.md if present (written by PreCompact hook).
 */

import { readFileSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';

const cwd = process.cwd();
const statePath = join(cwd, '.specwright', 'state', 'workflow.json');
const continuationPath = join(cwd, '.specwright', 'state', 'continuation.md');

if (!existsSync(statePath)) {
  // Specwright not initialized — nothing to do
  process.exit(0);
}

try {
  const state = JSON.parse(readFileSync(statePath, 'utf-8'));

  if (state.currentWork && !['shipped', 'abandoned'].includes(state.currentWork.status)) {
    const work = state.currentWork;
    const completed = work.tasksCompleted?.length ?? 0;
    const total = work.tasksTotal ?? '?';

    const gatesSummary = Object.entries(state.gates || {})
      .map(([name, g]) => `${name}: ${g.status}`)
      .join(', ') || 'none run';

    const lockWarning = state.lock
      ? `\n⚠ Lock held by "${state.lock.skill}" since ${state.lock.since}`
      : '';

    // Check for continuation snapshot from PreCompact hook
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
            // Fresh snapshot — include in recovery output
            continuationContent = `\n--- Continuation Snapshot ---\n${raw}`;
          }
        }

        // Always delete after reading (one-time snapshot)
        unlinkSync(continuationPath);
      } catch {
        // Ignore continuation read errors — not critical
      }
    }

    const workDir = work.workDir || `.specwright/work/${work.id}`;
    const unitLine = work.unitId ? `  Active Unit: ${work.unitId}\n` : '';

    const summary = [
      `Specwright: Work in progress`,
      `  Unit: ${work.id} (${work.status})`,
      unitLine ? unitLine.trimEnd() : null,
      `  Progress: ${completed}/${total} tasks`,
      `  Gates: ${gatesSummary}`,
      `  Spec: ${workDir}/spec.md`,
      `  Plan: ${workDir}/plan.md`,
      lockWarning,
      continuationContent,
    ].filter(Boolean).join('\n');

    // SessionStart hook stdout is added as context Claude can see and act on
    process.stdout.write(summary + '\n');
  }
} catch (err) {
  // Don't block session on hook failure — degrade gracefully
  process.stderr.write(`Specwright: Failed to read state: ${err.message}\n`);
}

process.exit(0);
