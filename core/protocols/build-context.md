# Build Context Protocol

Continuation snapshots, status cards, and context nudge for sw-build.

## Continuation Snapshot

After each task commit, write `{worktreeStateRoot}/continuation.md`: current unit, task just completed, key files modified, remaining tasks. Overwrites each time.

## Status Card

After each task commit, emit a status card:

```
───────────────────────────────────────
✓ {task-id} committed — {task name}
  Progress: {n} of {total} tasks complete
  Next:     {next-task-id} — {next task name}
  Ahead:    {remaining task ids and names}
───────────────────────────────────────
```

## Context Nudge

After the 3rd completed task, if 4+ tasks remain, append to the status card:
"Context growing — consider /clear. I'll recover from workflow.json."

## Repo Map

Lightweight codebase context injected into agent delegation prompts.

**Generation timing:** Before the first task in sw-build (after branch setup, before
the TDD loop begins).

**Storage:** `{currentWork.workDir}/repo-map.md` — ephemeral, regenerated per build.

**Injection method (dual-channel):**
1. **Context envelope** (primary): sw-build includes repo-map.md content at the TOP of
   each delegation prompt (before task details, ACs, and instructions). Longform data
   first improves response quality by up to 30% per Anthropic guidance.
2. **SubagentStart hook** (backup): a hook handler reads repo-map.md and injects it
   as `additionalContext` when executor or tester agents start. This is additive
   insurance — if the orchestrator's prompt trimming drops the map, the hook restores it.

Both channels may deliver the same content. The SubagentStart hook is a redundant
backup, not a replacement for the context envelope. When both fire, the agent
receives the repo map twice — worst-case overhead is ~1024 additional tokens (the
map's budget cap). This is acceptable given subagent context windows are large
(200K+) and the map provides high-value grounding context.

**Format and generation details:** See `protocols/repo-map.md`.

## Feedback Log

Accumulated per-task semantic findings from the micro-check step.

**Location:** `{currentWork.workDir}/feedback-log.md` — ephemeral, per-build.

**Accumulation:** Each micro-check appends to the file (does not overwrite).

**Per-task format:**
```markdown
## Task: {task-id}
- **{category}** ({file}:{line}): {description}
- **{category}** ({file}:{line}): {description}
```

When no findings exist for a task, no section is appended. When no tasks produce
findings across the entire build, the file does not exist or is empty.

## Correction Summary

Compressed quality corrections that survive context compaction.

**Generation method:** Observation masking — deduplicate findings by category, keep
only unique violation patterns with occurrence counts. Do NOT use LLM summarization
(research shows summarization increases trajectory length 13-15% by smoothing
failure signals).

**Deterministic instruction** (for the PreCompact agent prompt): "List each unique
violation category exactly once with its occurrence count. Do not rephrase,
summarize, or editorialize."

**Maximum size:** 500 tokens (measured as `Math.ceil(wordCount * 1.3)`).

**Example:**
```markdown
## Correction Summary
Unique violations seen in this build (avoid these patterns):
- unchecked-error (3 occurrences): Always check return values from async calls
- bare-except (1 occurrence): Use specific exception types
```

**Injection point:** Written to `{worktreeStateRoot}/continuation.md` during PreCompact.
Read and injected by the SessionStart hook on the `compact` trigger.

**When feedback-log.md is absent or empty:** No Correction Summary section is written.
The existing continuation snapshot content is unaffected.

## Pause Handling

If user responds "stop" or "pause" to a status card: halt cleanly.
Advise: `/sw-pivot` if the plan changed, `/sw-build` to resume.
