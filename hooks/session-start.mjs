/**
 * Specwright session-start hook.
 * Reads workflow.json on session start. If work is in progress,
 * outputs a recovery summary so Claude knows where to resume.
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const cwd = process.cwd();
const statePath = join(cwd, '.specwright', 'state', 'workflow.json');

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

    const summary = [
      `Specwright: Work in progress`,
      `  Unit: ${work.id} (${work.status})`,
      `  Progress: ${completed}/${total} tasks`,
      `  Gates: ${gatesSummary}`,
      `  Spec: .specwright/work/${work.id}/spec.md`,
      `  Plan: .specwright/work/${work.id}/plan.md`,
      lockWarning,
    ].filter(Boolean).join('\n');

    // Output goes to stderr so Claude sees it as a system message
    process.stderr.write(summary + '\n');
  }
} catch (err) {
  // Don't block session on hook failure — degrade gracefully
  process.stderr.write(`Specwright: Failed to read state: ${err.message}\n`);
}

process.exit(0);
