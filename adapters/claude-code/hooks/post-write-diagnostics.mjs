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
import { execFileSync } from 'child_process';

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

  // Step 2+3: LSP diagnostics
  // In the Claude Code plugin context (this hook's only runtime), CLAUDE_PLUGIN_ROOT
  // is always set — so standalone cli-lsp-client is never needed here. The Claude Code
  // platform provides LSP diagnostics via its own plugin system. This hook focuses on
  // ast-grep structural feedback that platform LSP doesn't provide.
  //
  // cli-lsp-client is used only in standalone/headless contexts (e.g., CI without
  // Claude Code). That path is handled by gate-semantic at verify time, not by this
  // PostToolUse hook.

  // Step 4: ast-grep structural feedback (runs independently of LSP)
  try {
    // Validate sg is actually ast-grep (not shadow-utils newgrp)
    const versionCheck = execFileSync('sg', ['--version'], { encoding: 'utf8', timeout: 3000, stdio: ['pipe', 'pipe', 'pipe'] });
    if (/ast-grep/i.test(versionCheck)) {
      // Language detection — map extensions to ast-grep language identifiers
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

      // Per-language patterns — catch/except is not universal. Languages without
      // try/catch (Go, Rust, C, C++, Bash) are skipped to avoid false negatives.
      // Future: per-language rule files for broader coverage.
      const patternMap = {
        'javascript': 'catch ($$$ARGS) { }',
        'typescript': 'catch ($$$ARGS) { }',
        'java': 'catch ($$$ARGS) { }',
        'kotlin': 'catch ($$$ARGS) { }',
        'swift': 'catch { }',
        'csharp': 'catch ($$$ARGS) { }',
        'python': 'except: pass',
        'ruby': 'rescue => $E'
      };
      const pattern = lang ? patternMap[lang] : null;

      if (lang && pattern) {
        // Future: use per-language rule files from ${CLAUDE_PLUGIN_ROOT}/rules/${lang}/post-write.yml
        try {
          // Use sg run with file path (not --stdin, to preserve line numbers)
          const sgOutput = execFileSync(
            'sg', ['run', '--pattern', pattern, '--lang', lang, filePath, '--json'],
            { encoding: 'utf8', timeout: 3000, stdio: ['pipe', 'pipe', 'pipe'] }
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
