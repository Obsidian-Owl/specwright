/**
 * Specwright pre-ship guard hook.
 * Blocks PR creation commands (gh pr create, gh api /pulls, curl github pulls)
 * unless workflow.json status is "shipping".
 *
 * PreToolUse hook on Bash — fires before every Bash call.
 * Fast-exits on non-matching commands (no filesystem I/O).
 *
 * Accepts an optional argument for the project directory (used in tests).
 * Falls back to process.cwd() when not provided.
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const PR_PATTERN = /gh\s+pr\s+create|gh\s+api\s+[^\s]*\/pulls|curl\s+.*api\.github\.com.*\/pulls/;

// Read stdin for tool input
let input = '';
try {
  input = readFileSync('/dev/stdin', 'utf-8');
} catch {
  // No stdin — not a PreToolUse context, allow
  process.exit(0);
}

let command = '';
try {
  const parsed = JSON.parse(input);
  command = parsed?.tool_input?.command ?? '';
} catch {
  // Malformed input — allow (don't block on parse errors)
  process.exit(0);
}

// Fast exit: no PR creation pattern → allow immediately (no filesystem I/O)
if (!PR_PATTERN.test(command)) {
  process.exit(0);
}

// PR creation pattern matched — check workflow state
const projectDir = process.argv[2] || process.cwd();
const workflowPath = join(projectDir, '.specwright', 'state', 'workflow.json');

if (!existsSync(workflowPath)) {
  // No Specwright state — not a managed project, allow
  process.exit(0);
}

try {
  const state = JSON.parse(readFileSync(workflowPath, 'utf-8'));
  const status = state?.currentWork?.status;

  if (status === 'shipping') {
    // Correct state — allow PR creation
    process.exit(0);
  }

  // Wrong state — block
  const statusMsg = status ? `Current status: "${status}".` : 'No active work unit.';
  process.stderr.write(
    `Specwright: PR creation blocked. ${statusMsg} ` +
    `PR creation is only allowed during the shipping phase. ` +
    `Run /sw-verify then /sw-ship to create a PR.\n`
  );
  process.exit(1);
} catch {
  // State read/parse error — allow (don't block on errors)
  process.exit(0);
}
