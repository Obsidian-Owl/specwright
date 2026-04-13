/**
 * Specwright session-stop hook.
 * Checks if there's active work and warns the user before ending the session.
 * Deterministic — no LLM involved.
 */

import { loadSpecwrightState, normalizeActiveWork } from '../../shared/specwright-state-paths.mjs';

try {
  const stateInfo = loadSpecwrightState();
  if (!stateInfo.workflow) {
    console.log(JSON.stringify({ ok: true }));
    process.exit(0);
  }

  const work = normalizeActiveWork(stateInfo);
  if (work && !['shipped', 'abandoned', null].includes(work.status)) {
    console.log(JSON.stringify({
      ok: false,
      reason: `Specwright has active work: ${work.workId} (status: ${work.status}, ${work.completedCount}/${work.totalCount} tasks done). Consider running /sw-status before ending this session, or /sw-status --reset to abandon.`
    }));
  } else {
    console.log(JSON.stringify({ ok: true }));
  }
} catch {
  // Don't block session end on read errors
  console.log(JSON.stringify({ ok: true }));
}

process.exit(0);
