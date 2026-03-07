/**
 * Specwright session-stop hook.
 * Checks if there's active work and warns the user before ending the session.
 * Deterministic — no LLM involved.
 */

import { readFileSync, existsSync } from 'fs';
import { join } from 'path';

const cwd = process.cwd();
const statePath = join(cwd, '.specwright', 'state', 'workflow.json');

if (!existsSync(statePath)) {
  // No Specwright state — nothing to warn about
  console.log(JSON.stringify({ ok: true }));
  process.exit(0);
}

try {
  const state = JSON.parse(readFileSync(statePath, 'utf-8'));
  const work = state.currentWork;

  if (work && !['shipped', 'abandoned', null].includes(work.status)) {
    const completed = work.tasksCompleted?.length ?? 0;
    const total = work.tasksTotal ?? '?';
    console.log(JSON.stringify({
      ok: false,
      reason: `Specwright has active work: ${work.id} (status: ${work.status}, ${completed}/${total} tasks done). Consider running /sw-status before ending this session, or /sw-status --reset to abandon.`
    }));
  } else {
    console.log(JSON.stringify({ ok: true }));
  }
} catch {
  // Don't block session end on read errors
  console.log(JSON.stringify({ ok: true }));
}

process.exit(0);
