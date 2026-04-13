#!/usr/bin/env node

/**
 * Specwright Stop hook for Codex.
 * Writes a continuation snapshot for active work and returns valid JSON output.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { loadSpecwrightState, normalizeActiveWork } from '../../shared/specwright-state-paths.mjs';

function writeSnapshot(work, continuationPath) {
  const stateDir = continuationPath.replace(/\/continuation\.md$/, '');
  const timestamp = new Date().toISOString();

  const snapshot = [
    `Snapshot: ${timestamp}`,
    '',
    '## Current State',
    `Work unit: ${work.workId} (${work.status})`,
    work.unitId ? `Active unit: ${work.unitId}` : null,
    `Progress: ${work.completedCount}/${work.totalCount} tasks`,
    `Gates: ${work.gatesSummary}`,
    '',
    '## Work in Progress',
    `Spec: ${work.specPath}`,
    `Plan: ${work.planPath}`,
    '',
    '## Next Steps',
    `1. Read ${work.specPath}.`,
    `2. Read ${work.planPath}.`,
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

  const stateInfo = loadSpecwrightState();
  if (!stateInfo.workflow) {
    emit({ continue: true });
    process.exit(0);
  }

  const work = normalizeActiveWork(stateInfo);
  if (!work || ['shipped', 'abandoned'].includes(work.status)) {
    emit({ continue: true });
    process.exit(0);
  }

  writeSnapshot(work, stateInfo.continuationPath);
  emit({
    continue: true,
    systemMessage: `Specwright continuation snapshot saved for ${work.workId}.`
  });
} catch {
  emit({ continue: true });
}

process.exit(0);
