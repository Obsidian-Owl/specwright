/**
 * Specwright TaskCompleted hook.
 * In agent team context (team_name present): runs configured build/test
 * commands to enforce quality before allowing task completion.
 * In sequential mode (no team_name): exits 0 immediately (no action).
 *
 * Exit codes:
 * - 0: allow completion
 * - 2: block completion with stderr feedback
 */

import { readFileSync } from 'fs';
import { execSync } from 'child_process';
import { join } from 'path';

try {
  const input = JSON.parse(readFileSync('/dev/stdin', 'utf-8'));

  if (!input.team_name) {
    process.exit(0);
  }

  const cwd = process.cwd();
  const configPath = join(cwd, '.specwright', 'config.json');

  let config;
  try {
    config = JSON.parse(readFileSync(configPath, 'utf-8'));
  } catch {
    process.exit(0);
  }

  const commands = [];
  if (config.commands?.build) commands.push({ name: 'build', cmd: config.commands.build });
  if (config.commands?.test) commands.push({ name: 'test', cmd: config.commands.test });

  if (commands.length === 0) {
    process.exit(0);
  }

  for (const { name, cmd } of commands) {
    try {
      execSync(cmd, { cwd, stdio: 'pipe' });
    } catch (err) {
      const output = err.stderr?.toString() || err.stdout?.toString() || err.message;
      process.stderr.write(`${name} command failed: ${cmd}\n${output}\n`);
      process.exit(2);
    }
  }

  process.exit(0);
} catch {
  // Graceful degradation — never block on hook failures
  process.exit(0);
}
