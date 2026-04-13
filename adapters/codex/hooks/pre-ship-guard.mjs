#!/usr/bin/env node

/**
 * Specwright PreToolUse guard for Codex.
 * Blocks PR creation commands unless workflow status is "shipping".
 */

import { readFileSync } from 'fs';
import { loadSpecwrightState, normalizeActiveWork } from '../../shared/specwright-state-paths.mjs';

const PR_PATTERN = /gh\s+pr\s+create|gh\s+api\s+[^\s]*\/pulls(\s|$)|curl\s+.*api\.github\.com[^\s]*\/pulls(\s|$)/;

let command = '';
try {
  const input = JSON.parse(readFileSync('/dev/stdin', 'utf-8'));
  command = input?.tool_input?.command ?? '';
} catch {
  process.exit(0);
}

if (!PR_PATTERN.test(command)) {
  process.exit(0);
}

try {
  const stateInfo = loadSpecwrightState();
  if (!stateInfo.workflow) {
    process.exit(0);
  }

  const work = normalizeActiveWork(stateInfo);
  const status = work?.status;

  if (status === 'shipping') {
    process.exit(0);
  }

  const statusMsg = status ? `Current status: "${status}".` : 'No active work unit.';
  const reason = `Specwright: PR creation blocked. ${statusMsg} PR creation is only allowed during /sw-ship.`;

  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: reason
    }
  }));
} catch {
  process.exit(0);
}
