#!/usr/bin/env node

/**
 * Specwright Capture Learning Hook
 * PostToolUse hook for Bash failures. Captures failed commands to the
 * learning queue for later review via /specwright:learn-review.
 *
 * Receives JSON via stdin from Claude Code PostToolUse event.
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import { join, dirname } from 'path';

const cwd = process.env.CLAUDE_CWD || process.cwd();
const specDir = join(cwd, '.specwright');

// Guard: skip if Specwright not initialized
if (!existsSync(specDir)) {
  process.exit(0);
}

// Read stdin (Claude Code sends JSON with tool input and response)
let input = '';
try {
  input = readFileSync('/dev/stdin', 'utf-8');
} catch {
  process.exit(0);
}

let data;
try {
  data = JSON.parse(input);
} catch {
  process.exit(0);
}

// Extract exit code and command from the tool response
const exitCode = data?.tool_response?.exit_code ?? data?.tool_result?.exit_code;
const command = data?.tool_input?.command ?? '';

// Guard: skip if exit code is zero or missing (success)
if (!exitCode || exitCode === 0) {
  process.exit(0);
}

// Guard: skip empty commands
if (!command || command === 'null') {
  process.exit(0);
}

// Truncate command to 200 characters
const cmdTruncated = command.substring(0, 200);

// Escape for JSON safety
const cmdSafe = cmdTruncated.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, ' ');

const timestamp = new Date().toISOString();

const queueFile = join(specDir, 'state', 'learning-queue.jsonl');
mkdirSync(dirname(queueFile), { recursive: true });

const entry = JSON.stringify({
  timestamp,
  command: cmdSafe,
  exitCode,
  type: 'error'
});

try {
  // Append to queue file
  const existing = existsSync(queueFile) ? readFileSync(queueFile, 'utf-8') : '';
  writeFileSync(queueFile, existing + entry + '\n');
} catch {
  // Silent — don't fail the tool use for learning capture errors
}

process.exit(0);
