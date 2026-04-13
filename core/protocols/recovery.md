# Recovery Protocol

## After Context Compaction

**IMMEDIATELY execute these steps:**

### 1. Resolve Logical Roots
```
Resolve {projectRoot}, {repoStateRoot}, and {worktreeStateRoot} per protocols/context.md
```
Use those roots for all recovery reads. Do not guess checkout-local paths.

### 1.5. Recover Session And Continuation State

Read `{worktreeStateRoot}/session.json` when it exists. This is the current
worktree's source of truth for attachment, mode, branch, and `lastSeenAt`.

If `{worktreeStateRoot}/continuation.md` exists, read it. This optional file
contains the working state captured before compaction: active task, files in
progress, pending decisions, and next steps. If absent, continue with session
and workflow state only.

If the shared/session layout is absent, follow the legacy fallback rules in
`protocols/context.md` before proceeding.

### 2. Recover The Selected Work

If `session.json.attachedWorkId` exists, read
`{repoStateRoot}/work/{workId}/workflow.json`.

This selected work `workflow.json` is the source of truth for lifecycle status,
active unit, gates, task progress, and lock state.

If no work can be resolved for a work-aware recovery path, stop with:

> "Run /sw-design first."

### 3. Load Anchor Context
```
Read {repoStateRoot}/CHARTER.md
Read {repoStateRoot}/CONSTITUTION.md
```

Read `{repoStateRoot}/TESTING.md` only when the resumed skill needs testing
boundaries and the file exists.

### 4. Resume Active Work

**If selected work exists:**
- Read the current work unit's `spec.md` and `plan.md` from the selected
  work's `workflow.workDir`
- Check progress markers in the selected work's `workflow.json`
- Resume from current state

**Never:**
- Rely on conversation history
- Assume what was happening
- Restart from scratch

### 5. Skill-Specific Recovery

Each skill's documentation has a "Failure Modes" section with specific recovery
notes.

Examples:
- If plan exists but tasks do not, resume at task decomposition
- If evidence is missing, re-run the last gate
- If a per-work lock is stale, clear it on the selected work only and resume

## Critical Rule

**Workflow state is the source of truth, not conversation history.**
