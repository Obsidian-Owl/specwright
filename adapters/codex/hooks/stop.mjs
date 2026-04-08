#!/usr/bin/env node

/**
 * Specwright Stop hook for Codex.
 * Writes a continuation snapshot for active work and returns valid JSON output.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

function writeSnapshot(currentWork, gates) {
  const stateDir = join(process.cwd(), '.specwright', 'state');
  const continuationPath = join(stateDir, 'continuation.md');
  const workDir = currentWork.workDir || `.specwright/work/${currentWork.id}`;
  const completed = currentWork.tasksCompleted?.length ?? 0;
  const total = currentWork.tasksTotal ?? '?';
  const timestamp = new Date().toISOString();

  const gatesSummary = gates
    ? Object.entries(gates).map(([name, g]) => `${name}: ${g.status}`).join(', ') || 'none run'
    : 'none run';

  const snapshot = [
    `Snapshot: ${timestamp}`,
    '',
    '## Current State',
    `Work unit: ${currentWork.id} (${currentWork.status})`,
    currentWork.unitId ? `Active unit: ${currentWork.unitId}` : null,
    `Progress: ${completed}/${total} tasks`,
    `Gates: ${gatesSummary}`,
    '',
    '## Work in Progress',
    `Spec: ${workDir}/spec.md`,
    `Plan: ${workDir}/plan.md`,
    '',
    '## Next Steps',
    `1. Read ${workDir}/spec.md.`,
    `2. Read ${workDir}/plan.md.`,
    '3. Continue with /sw-status then the next workflow skill.'
  ].filter(Boolean).join('\n');

  mkdirSync(stateDir, { recursive: true });
  writeFileSync(continuationPath, snapshot, 'utf-8');
}

function emit(output) {
  process.stdout.write(JSON.stringify(output));
}

try {
  // Parse stdin to satisfy Stop hook contract; input content is optional for our logic.
  try {
    readFileSync('/dev/stdin', 'utf-8');
  } catch {
    // Ignore missing stdin and proceed with safe JSON output.
  }

  const statePath = join(process.cwd(), '.specwright', 'state', 'workflow.json');
  if (!existsSync(statePath)) {
    emit({ continue: true });
    process.exit(0);
  }

  const state = JSON.parse(readFileSync(statePath, 'utf-8'));
  const work = state?.currentWork;

  if (!work || ['shipped', 'abandoned'].includes(work.status)) {
    emit({ continue: true });
    process.exit(0);
  }

  writeSnapshot(work, state.gates);
  emit({
    continue: true,
    systemMessage: `Specwright continuation snapshot saved for ${work.id}.`
  });
} catch {
  emit({ continue: true });
}

process.exit(0);
