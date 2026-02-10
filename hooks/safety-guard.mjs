#!/usr/bin/env node

/**
 * Specwright Safety Guard Hook
 * PreToolUse hook that blocks dangerous commands and sensitive file edits.
 * Reads additional patterns from .specwright/config.json if available.
 *
 * Receives JSON via stdin from Claude Code PreToolUse event.
 * Exit 0 = allow, Exit 2 = block (with message to stderr).
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const cwd = process.env.CLAUDE_CWD || process.cwd();
const specDir = join(cwd, '.specwright');

// Read stdin
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

const toolName = data?.tool_name || '';

// Load custom sensitive patterns from config if available
let sensitiveFilePatterns = ['\\.env$', '\\.pem$', '\\.key$', 'credentials', '\\.secret$'];
let secretPatterns = [];

const configPath = join(specDir, 'config.json');
if (existsSync(configPath)) {
  try {
    const config = JSON.parse(readFileSync(configPath, 'utf-8'));
    if (config.gates?.security?.sensitiveFiles) {
      sensitiveFilePatterns = [
        ...sensitiveFilePatterns,
        ...config.gates.security.sensitiveFiles
      ];
    }
    if (config.gates?.security?.secretPatterns) {
      secretPatterns = config.gates.security.secretPatterns;
    }
  } catch {
    // Use defaults on config read error
  }
}

// Check Bash commands
if (toolName === 'Bash') {
  const cmd = data?.tool_input?.command || '';

  // Block dangerous recursive deletes targeting root/home
  if (/rm\s+(-rf?|--recursive)\s+(\/|~|\$HOME|\/Users)/i.test(cmd)) {
    console.error('BLOCKED: Dangerous recursive delete targeting root/home directory');
    process.exit(2);
  }

  // Block destructive git operations
  if (/git\s+(push\s+--force|reset\s+--hard|clean\s+-fd)/i.test(cmd)) {
    console.error('BLOCKED: Destructive git operation — requires explicit user approval');
    process.exit(2);
  }

  // Block broad git staging commands
  if (/git\s+add\s+(--all|-A|\.(\s|$))/.test(cmd)) {
    console.error('BLOCKED: Broad git staging (git add -A / git add . / git add --all). Stage specific files by name.');
    process.exit(2);
  }
}

// Check file edits for sensitive files
if (toolName === 'Edit' || toolName === 'Write') {
  const filePath = data?.tool_input?.file_path || '';

  const sensitiveRegex = new RegExp(sensitiveFilePatterns.join('|'), 'i');
  if (sensitiveRegex.test(filePath)) {
    console.error(`BLOCKED: Direct edit to sensitive file (${filePath}). Review security implications first.`);
    process.exit(2);
  }
}

// Allow the operation
process.exit(0);
