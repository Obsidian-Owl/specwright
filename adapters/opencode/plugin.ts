/**
 * Specwright plugin for Opencode.
 *
 * On load: auto-deploys skills, protocols, agents, and commands from the
 * installed npm package to the project's filesystem locations where Opencode
 * discovers them. Deployment is version-gated — only runs when the package
 * version differs from the deployed version.
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

import { readFileSync, writeFileSync, existsSync, unlinkSync, mkdirSync, cpSync, rmSync } from 'fs';
import { join } from 'path';

// ── Auto-deploy ─────────────────────────────────────────────────────────────
//
// Opencode does NOT discover skills, protocols, agents, or commands from npm
// packages. Assets must be copied to specific filesystem locations.
//
// Deployment targets (split across two roots):
//   commands/  → .opencode/commands/       (Opencode discovers commands here)
//   skills/    → .specwright/skills/       (commands reference this path)
//   protocols/ → .specwright/protocols/    (skills reference this path)
//   agents/    → .specwright/agents/       (delegation protocol references this)

interface DeployMapping {
  source: string;
  target: string;
}

function getDeployMappings(packageRoot: string, projectDir: string): DeployMapping[] {
  return [
    { source: join(packageRoot, 'commands'), target: join(projectDir, '.opencode', 'commands') },
    { source: join(packageRoot, 'skills'), target: join(projectDir, '.specwright', 'skills') },
    { source: join(packageRoot, 'protocols'), target: join(projectDir, '.specwright', 'protocols') },
    { source: join(packageRoot, 'agents'), target: join(projectDir, '.specwright', 'agents') },
  ];
}

function getPackageVersion(packageRoot: string): string | null {
  try {
    const pkgPath = join(packageRoot, 'package.json');
    if (!existsSync(pkgPath)) return null;
    const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
    return typeof pkg.version === 'string' ? pkg.version : null;
  } catch {
    return null;
  }
}

function getDeployedVersion(projectDir: string): string | null {
  try {
    const versionPath = join(projectDir, '.specwright', '.plugin-version');
    if (!existsSync(versionPath)) return null;
    return readFileSync(versionPath, 'utf-8').trim();
  } catch {
    return null;
  }
}

function writeDeployedVersion(projectDir: string, version: string): void {
  try {
    const versionPath = join(projectDir, '.specwright', '.plugin-version');
    mkdirSync(join(projectDir, '.specwright'), { recursive: true });
    writeFileSync(versionPath, version, 'utf-8');
  } catch {
    // Version marker write failure is non-fatal — next load will re-deploy
  }
}

function deployAssets(packageRoot: string, projectDir: string): void {
  try {
    const packageVersion = getPackageVersion(packageRoot);
    if (!packageVersion) {
      console.warn('Specwright: Could not read package version, skipping deploy');
      return;
    }

    const deployedVersion = getDeployedVersion(projectDir);
    if (deployedVersion === packageVersion) {
      return; // Already deployed — skip
    }

    console.log(`Specwright: Deploying v${packageVersion} (was: ${deployedVersion ?? 'none'})`);

    const mappings = getDeployMappings(packageRoot, projectDir);
    let deployedCount = 0;

    for (const { source, target } of mappings) {
      try {
        if (!existsSync(source)) {
          console.warn(`Specwright: Source directory not found, skipping: ${source}`);
          continue;
        }

        // Clean existing target to remove orphaned files from previous versions
        try {
          if (existsSync(target)) {
            rmSync(target, { recursive: true, force: true });
          }
        } catch {
          // If cleanup fails, proceed with overwrite copy
        }

        // Create parent directory and copy
        mkdirSync(target, { recursive: true });
        cpSync(source, target, { recursive: true, force: true });
        deployedCount++;
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(`Specwright: Failed to deploy ${source} → ${target}: ${message}`);
      }
    }

    if (deployedCount === mappings.length) {
      writeDeployedVersion(projectDir, packageVersion);
      console.log(`Specwright: Deployed ${deployedCount} asset directories`);
    } else if (deployedCount > 0) {
      console.warn(`Specwright: Partial deploy — ${deployedCount}/${mappings.length} succeeded. Will retry next load.`);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error(`Specwright: Deploy failed: ${message}`);
    // Non-fatal — lifecycle handlers still register below
  }
}

// ── Plugin entry point ──────────────────────────────────────────────────────

export default async function (ctx: { directory: string; on: (event: string, handler: () => Promise<string | void>) => void }) {
  const { directory } = ctx;

  // Deploy assets BEFORE registering event handlers
  deployAssets(import.meta.dir, directory);

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

      const shippingWarning = status === 'shipping'
        ? '\n  ⚠ Status is "shipping" — PR creation was in progress. Run /sw-ship to check if the PR was created or to retry.'
        : '';

      const summary = [
        'Specwright: Work in progress',
        `  Unit: ${workId} (${status})`,
        unitLine || null,
        `  Progress: ${tasksCompleted}/${tasksTotal} tasks`,
        `  Gates: ${gatesSummary}`,
        `  Spec: ${workDir}/spec.md`,
        `  Plan: ${workDir}/plan.md`,
        shippingWarning || null,
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
