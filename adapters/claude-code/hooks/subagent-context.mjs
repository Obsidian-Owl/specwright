#!/usr/bin/env node

/**
 * SubagentStart hook — injects codebase context into Specwright subagents.
 *
 * Routing by agent_type:
 *   executor/tester  → repo-map.md (codebase structure)
 *   architect/reviewer → context.md (research findings)
 *   other agents     → no injection (exit 0)
 *
 * Graceful degradation: if the target file doesn't exist, exit 0 silently.
 */

import { readFileSync } from 'fs';
import { join, resolve, isAbsolute } from 'path';
import { resolveLegacyStatePaths } from '../../shared/specwright-state-paths.mjs';

const REPO_MAP_AGENTS = ['specwright-executor', 'specwright-tester'];
const CONTEXT_AGENTS = ['specwright-architect', 'specwright-reviewer'];

function main() {
  let input;
  try {
    const stdin = readFileSync('/dev/stdin', 'utf8');
    input = JSON.parse(stdin);
  } catch {
    // No stdin or invalid JSON — exit silently
    process.exit(0);
  }

  const agentType = input?.agent_type;
  if (!agentType) {
    process.exit(0);
  }

  // Determine which file to inject based on agent type
  let targetFile;
  if (REPO_MAP_AGENTS.includes(agentType)) {
    targetFile = 'repo-map.md';
  } else if (CONTEXT_AGENTS.includes(agentType)) {
    targetFile = 'context.md';
  } else {
    // Unknown agent type — no injection
    process.exit(0);
  }

  // Read workflow state to find current work directory
  let workDir;
  let projectRoot;
  try {
    const statePaths = resolveLegacyStatePaths();
    const workflowPath = statePaths.workflowPath;
    const workflow = JSON.parse(readFileSync(workflowPath, 'utf8'));
    workDir = workflow?.currentWork?.workDir;
    projectRoot = statePaths.lookupRoot;
  } catch {
    // Can't read workflow — exit silently
    process.exit(0);
  }

  if (!workDir) {
    process.exit(0);
  }

  // Defense-in-depth: reject absolute workDir paths (workflow.json is user-writable)
  if (isAbsolute(workDir)) {
    process.exit(0);
  }

  // Read the target file (with path traversal validation)
  let content;
  try {
    const filePath = resolve(projectRoot, workDir, targetFile);

    // Validate resolved path is within project root to prevent path traversal.
    // Append separator to avoid prefix matching siblings (e.g., /repo-evil matching /repo).
    if (!filePath.startsWith(projectRoot + '/')) {
      process.exit(0);
    }

    content = readFileSync(filePath, 'utf8');
  } catch {
    // File doesn't exist — graceful degradation
    process.exit(0);
  }

  if (!content || content.trim().length === 0) {
    process.exit(0);
  }

  // Output additionalContext for the subagent
  const output = {
    hookSpecificOutput: {
      hookEventName: 'SubagentStart',
      additionalContext: content
    }
  };

  process.stdout.write(JSON.stringify(output));
}

main();
