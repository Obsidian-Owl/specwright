#!/usr/bin/env node

/**
 * PostToolUse hook — provides diagnostic feedback after file writes.
 *
 * Platform-first detection order:
 *   1. Opencode: exit 0 (LSP diagnostics already fed to agent)
 *   2. Claude Code platform LSP: skip standalone LSP, keep ast-grep feedback
 *   3. Standalone LSP: cli-lsp-client diagnostics (if no platform LSP)
 *   4. ast-grep: structural pattern feedback (if sg on PATH)
 *   5. Nothing available: exit 0 silently
 *
 * Async hook — does not block the agent.
 */

import { readFileSync } from 'fs';
import { extname } from 'path';
import { execSync } from 'child_process';

const CODE_EXTENSIONS = new Set([
  '.js', '.ts', '.jsx', '.tsx', '.py', '.go', '.rs', '.java',
  '.rb', '.c', '.cpp', '.h', '.cs', '.swift', '.kt', '.sh'
]);

function main() {
  let input;
  try {
    const stdin = readFileSync('/dev/stdin', 'utf8');
    input = JSON.parse(stdin);
  } catch {
    process.exit(0);
  }

  const filePath = input?.tool_input?.file_path;
  if (!filePath) {
    process.exit(0);
  }

  // Only process code files
  const ext = extname(filePath).toLowerCase();
  if (!CODE_EXTENSIONS.has(ext)) {
    process.exit(0);
  }

  const findings = [];

  // Step 1: Opencode detection — exit silently (LSP diagnostics already provided)
  if (process.env.OPENCODE || process.env.OPENCODE_VERSION) {
    process.exit(0);
  }

  // Step 2: Claude Code platform LSP detection
  // If platform LSP is active, skip standalone LSP (step 3) but still run ast-grep (step 4)
  let hasPlatformLSP = false;
  try {
    // Check if CLAUDE_PLUGIN_ROOT is set (indicates Claude Code plugin context)
    // Platform LSP availability is a runtime characteristic — we check for the
    // plugin root as a proxy. The actual LSP diagnostic injection happens via
    // the platform's own mechanism, not this hook.
    if (process.env.CLAUDE_PLUGIN_ROOT) {
      // In Claude Code context, assume platform may provide LSP diagnostics.
      // This hook adds ast-grep structural feedback that LSP doesn't provide.
      hasPlatformLSP = true;
    }
  } catch {
    // Ignore detection errors
  }

  // Step 3: Standalone LSP fallback (only if no platform LSP)
  if (!hasPlatformLSP) {
    try {
      const lspOutput = execSync(
        `cli-lsp-client diagnostics "${filePath}"`,
        { encoding: 'utf8', timeout: 5000, stdio: ['pipe', 'pipe', 'pipe'] }
      );
      if (lspOutput.trim()) {
        const lines = lspOutput.trim().split('\n');
        for (const line of lines) {
          if (line.trim()) {
            findings.push(`[LSP] ${line.trim()}`);
          }
        }
      }
    } catch {
      // cli-lsp-client not available or errored — continue to ast-grep
    }
  }

  // Step 4: ast-grep structural feedback (runs independently of LSP)
  try {
    // Validate sg is actually ast-grep (not shadow-utils newgrp)
    const versionCheck = execSync('sg --version 2>&1', { encoding: 'utf8', timeout: 3000 });
    if (/ast-grep/i.test(versionCheck)) {
      // Determine language from extension for rule path
      const langMap = {
        '.js': 'javascript', '.jsx': 'javascript',
        '.ts': 'typescript', '.tsx': 'typescript',
        '.py': 'python', '.go': 'go', '.rs': 'rust',
        '.java': 'java', '.rb': 'ruby',
        '.c': 'c', '.cpp': 'cpp', '.h': 'c',
        '.cs': 'csharp', '.swift': 'swift', '.kt': 'kotlin',
        '.sh': 'bash'
      };
      const lang = langMap[ext];

      if (lang) {
        // Future: use per-language rule files from ${CLAUDE_PLUGIN_ROOT}/rules/${lang}/post-write.yml
        try {
          // Use sg run with file path (not --stdin, to preserve line numbers)
          const sgOutput = execSync(
            `sg run --pattern 'catch ($$$ARGS) { }' --lang ${lang} "${filePath}" --json 2>/dev/null`,
            { encoding: 'utf8', timeout: 3000 }
          );
          if (sgOutput.trim()) {
            try {
              const matches = JSON.parse(sgOutput);
              if (Array.isArray(matches)) {
                for (const match of matches) {
                  const line = match?.range?.start?.line ?? '?';
                  findings.push(`[ast-grep] ${filePath}:${line}: warn: empty catch block detected`);
                }
              }
            } catch {
              // JSON parse failure — ignore
            }
          }
        } catch {
          // Rule file doesn't exist or sg errored — not an error
        }
      }
    }
  } catch {
    // sg not available — graceful degradation
  }

  // Output findings if any
  if (findings.length > 0) {
    const formatted = findings.join('\n');
    const output = {
      hookSpecificOutput: {
        hookEventName: 'PostToolUse',
        additionalContext: formatted
      }
    };
    process.stdout.write(JSON.stringify(output));
  }

  // Exit 0 regardless — PostToolUse hooks cannot block
}

main();
