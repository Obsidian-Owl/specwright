#!/usr/bin/env node

/**
 * Specwright Token Counter Hook
 * PostToolUse hook that estimates token counts for .md files.
 * Advises Claude when files exceed or approach the 1,500 token budget (P3).
 *
 * Receives JSON via stdin from Claude Code PostToolUse event.
 * Outputs JSON with additionalContext to stdout.
 */

import { readFileSync, existsSync } from 'fs';

const cwd = process.env.CLAUDE_CWD || process.cwd();

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
const toolInput = data?.tool_input || {};
const filePath = toolInput.file_path || '';

// Only process .md files
if (!filePath.endsWith('.md')) {
  process.exit(0);
}

// Helper: estimate tokens from character count
function estimateTokens(charCount) {
  return Math.ceil(charCount / 4);
}

// Helper: convert absolute path to relative
function relativePath(absPath) {
  if (absPath.startsWith(cwd + '/')) {
    return absPath.slice(cwd.length + 1);
  }
  return absPath;
}

// Helper: format budget warning
function budgetWarning(tokens) {
  if (tokens > 1500) return ' [OVER 1,500 BUDGET]';
  if (tokens > 1350) return ' [NEAR BUDGET]';
  return '';
}

// Helper: format token count message
function formatMessage(relPath, tokens, chars, beforeTokens = null) {
  if (beforeTokens !== null) {
    const delta = tokens - beforeTokens;
    const sign = delta >= 0 ? '+' : '';
    return `[Token estimate] ${relPath}: ~${beforeTokens} → ~${tokens} tokens (${sign}${delta})${budgetWarning(tokens)}`;
  }
  return `[Token estimate] ${relPath}: ~${tokens} tokens (${chars} chars)${budgetWarning(tokens)}`;
}

try {
  const relPath = relativePath(filePath);

  if (toolName === 'Read') {
    // Read the file and count tokens
    if (!existsSync(filePath)) {
      process.exit(0);
    }
    const content = readFileSync(filePath, 'utf-8');
    const chars = content.length;
    const tokens = estimateTokens(chars);
    const message = formatMessage(relPath, tokens, chars);
    console.log(JSON.stringify({ additionalContext: message }));
  } else if (toolName === 'Edit') {
    // Calculate before/after token counts
    const oldString = toolInput.old_string || '';
    const newString = toolInput.new_string || '';

    if (!existsSync(filePath)) {
      process.exit(0);
    }

    const afterContent = readFileSync(filePath, 'utf-8');
    const afterChars = afterContent.length;
    const beforeChars = afterChars - newString.length + oldString.length;

    const beforeTokens = estimateTokens(beforeChars);
    const afterTokens = estimateTokens(afterChars);

    const message = formatMessage(relPath, afterTokens, afterChars, beforeTokens);
    console.log(JSON.stringify({ additionalContext: message }));
  } else if (toolName === 'Write') {
    // Count tokens in the content being written
    const content = toolInput.content || '';
    const chars = content.length;
    const tokens = estimateTokens(chars);
    const message = formatMessage(relPath, tokens, chars);
    console.log(JSON.stringify({ additionalContext: message }));
  }
} catch {
  // Silent failure
  process.exit(0);
}

process.exit(0);
