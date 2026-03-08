/**
 * Specwright plugin for Opencode.
 *
 * Handles three lifecycle events:
 *   session.created   — reads workflow.json; outputs recovery summary if work is in progress;
 *                       includes continuation.md snapshot if fresh, then deletes it.
 *   session.compacted — writes continuation.md with a current-state snapshot so the next
 *                       session can resume without losing context.
 *   session.idle      — warns if work is in progress so the user can decide what to do.
 *
 * Uses only standard Node.js / Bun APIs (fs, path). Returns results instead of exiting.
 */

import { readFileSync, writeFileSync, existsSync, unlinkSync } from 'fs';
import { join } from 'path';

export default async function (ctx: { directory: string; on: (event: string, handler: () => Promise<string | void>) => void }) {
  const { directory } = ctx;
  const stateDir = join(directory, '.specwright/state');
  const workflowPath = join(stateDir, 'workflow.json');
  const continuationPath = join(stateDir, 'continuation.md');

  // ── Helpers ───────────────────────────────────────────────────────────────

  function readWorkflow(): Record<string, unknown> | null {
    try {
      if (!existsSync(workflowPath)) return null;
      return JSON.parse(readFileSync(workflowPath, 'utf-8')) as Record<string, unknown>;
    } catch {
      return null;
    }
  }

  function isActiveWork(state: Record<string, unknown>): boolean {
    const currentWork = state.currentWork as Record<string, unknown> | undefined;
    if (!currentWork) return false;
    const status = currentWork.status as string | undefined;
    return !!status && !['shipped', 'abandoned'].includes(status);
  }

  // ── session.created ────────────────────────────────────────────────────────
  //
  // Read current workflow state. If work is in progress, return a recovery
  // summary. Include a fresh continuation snapshot if one exists.

  ctx.on('session.created', async () => {
    try {
      const state = readWorkflow();
      if (!state || !isActiveWork(state)) return;

      const currentWork = state.currentWork as Record<string, unknown>;
      const status = currentWork.status as string;
      const tasksCompleted = (currentWork.tasksCompleted as unknown[])?.length ?? 0;
      const tasksTotal = currentWork.tasksTotal ?? '?';
      const workId = currentWork.id as string | undefined;
      const workDir = (currentWork.workDir as string | undefined) || `.specwright/work/${workId}`;
      const unitLine = currentWork.unitId ? `  Active Unit: ${currentWork.unitId}` : '';

      const gates = state.gates as Record<string, { status: string }> | undefined;
      const gatesSummary = gates
        ? Object.entries(gates).map(([name, g]) => `${name}: ${g.status}`).join(', ') || 'none run'
        : 'none run';

      // Check for a fresh continuation snapshot written by the compacted handler
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
              continuationContent = `\n--- Current State Snapshot ---\n${raw}`;
            }
          }
          // One-time snapshot — always delete after reading
          unlinkSync(continuationPath);
        } catch {
          // Ignore continuation read errors — not critical
        }
      }

      const summary = [
        'Specwright: Work in progress',
        `  Unit: ${workId} (${status})`,
        unitLine || null,
        `  Progress: ${tasksCompleted}/${tasksTotal} tasks`,
        `  Gates: ${gatesSummary}`,
        `  Spec: ${workDir}/spec.md`,
        `  Plan: ${workDir}/plan.md`,
        continuationContent || null,
      ].filter(Boolean).join('\n');

      return summary;
    } catch (err) {
      // Degrade gracefully — never block session on hook failure
      const message = err instanceof Error ? err.message : String(err);
      console.error(`Specwright: Failed to read state on session.created: ${message}`);
    }
  });

  // ── session.compacted ──────────────────────────────────────────────────────
  //
  // Triggered when Opencode compacts the conversation. Write a continuation.md
  // snapshot so session.created can restore context in the next session.

  ctx.on('session.compacted', async () => {
    try {
      const state = readWorkflow();
      if (!state || !isActiveWork(state)) return;

      const currentWork = state.currentWork as Record<string, unknown>;
      const status = currentWork.status as string;
      const tasksCompleted = (currentWork.tasksCompleted as unknown[])?.length ?? 0;
      const tasksTotal = currentWork.tasksTotal ?? '?';
      const workId = currentWork.id as string | undefined;
      const workDir = (currentWork.workDir as string | undefined) || `.specwright/work/${workId}`;

      const timestamp = new Date().toISOString();

      const nextSteps = [
        `1. Read ${workDir}/spec.md to understand what this unit is building.`,
        `2. Read ${workDir}/plan.md to see remaining tasks.`,
        `3. Continue implementation — run /sw-status to see full progress.`,
      ].join('\n');

      const continuationSnapshot = [
        `Snapshot: ${timestamp}`,
        '',
        '# Specwright Continuation',
        '',
        `**Status:** ${status}`,
        `**Unit:** ${workId}`,
        `**Progress:** ${tasksCompleted}/${tasksTotal} tasks completed`,
        '',
        '## Next Steps',
        '',
        nextSteps,
      ].join('\n');

      writeFileSync(continuationPath, continuationSnapshot, 'utf-8');
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`Specwright: Failed to write continuation on session.compacted: ${message}`);
    }
  });

  // ── session.idle ───────────────────────────────────────────────────────────
  //
  // Triggered when the session becomes idle. Warn if there is active work so
  // the user knows Specwright has work in progress.

  ctx.on('session.idle', async () => {
    try {
      const state = readWorkflow();
      if (!state || !isActiveWork(state)) return;

      const currentWork = state.currentWork as Record<string, unknown>;
      const status = currentWork.status as string;
      const tasksCompleted = (currentWork.tasksCompleted as unknown[])?.length ?? 0;
      const tasksTotal = currentWork.tasksTotal ?? '?';
      const workId = currentWork.id as string | undefined;

      return (
        `Specwright: Active work in progress — ${workId} (${status}, ${tasksCompleted}/${tasksTotal} tasks). ` +
        `Run /sw-status to check progress or /sw-status --reset to abandon.`
      );
    } catch {
      // Degrade gracefully
    }
  });
}
