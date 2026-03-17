# Build Context Protocol

Continuation snapshots, status cards, and context management for sw-build.

## Continuation Snapshot

After each task commit, write `.specwright/state/continuation.md`: current unit, task just completed, key files modified, remaining tasks. Overwrites each time.

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

## Pause Handling

If user responds "stop" or "pause" to a status card: halt cleanly.
Advise: `/sw-pivot` if the plan changed, `/sw-build` to resume.
