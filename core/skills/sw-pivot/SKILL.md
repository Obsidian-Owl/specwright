---
name: sw-pivot
description: >-
  Mid-build course correction. Captures committed progress, takes pivot input,
  has the architect revise remaining tasks, and resumes sw-build with a revised plan.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Specwright Pivot

## Goal

Graceful course correction during an active sw-build. Capture what's been
committed, understand what changed, revise the remaining tasks via architect
review, and hand back to sw-build — without losing committed work or context.

## Inputs

- `.specwright/state/workflow.json` — `tasksCompleted`, `tasksTotal`, `workDir`
- `{currentWork.workDir}/spec.md` — full spec (completed + remaining criteria)
- `{currentWork.workDir}/plan.md` — task breakdown

## Outputs

- `spec.md` — appended with `## Revision — [date]: [reason]` section
- `plan.md` — appended with `## Pivot Note` section
- `workflow.json` — remaining task list updated

## Constraints

**Pre-condition (LOW freedom):**
- Read `currentWork.status` from workflow.json.
- If status is not `building`: STOP — "sw-pivot is only valid during an active
  sw-build. Current status: {status}."
- If `tasksCompleted` equals `tasksTotal` (all tasks done): STOP — "No remaining
  tasks to pivot. Run `/sw-verify`."

**Snapshot (LOW freedom):**
- Read `tasksCompleted` from workflow.json.
- Read spec.md and plan.md for task names and criteria.
- Present to user:
  ```
  Done (committed): task-1 — [name], task-2 — [name]
  Remaining: task-3 — [name], task-4 — [name], task-5 — [name]
  ```

**Pivot input (MEDIUM freedom):**
- Ask via AskUserQuestion: "What changed? Describe the new information,
  wrong assumption, or scope change that requires course correction."
- Accept free-text input. Confirm understanding before delegating.

**Revise (HIGH freedom for architect, LOW freedom for mutation):**
- Delegate to `specwright-architect` per `protocols/delegation.md` with:
  - Completed task list (names + criteria — READ ONLY context)
  - Remaining task list (names + criteria — subject to revision)
  - User's pivot description
  - Constraint: "You may remove, modify, add, or reorder REMAINING tasks only.
    Completed tasks and their criteria are immutable. Do not reference or alter
    any completed task's acceptance criteria."
- Architect returns revised task list for remaining work.
- If architect proposes modifying completed criteria: reject, re-delegate with
  explicit constraint reminder (max 2 attempts).

**Apply (LOW freedom):**
- Present diff of changes to user: tasks removed, tasks modified, tasks added.
- On user approval:
  1. APPEND to spec.md:
     ```
     ## Revision — [YYYY-MM-DD]: [one-line reason]
     [Revised task list with updated acceptance criteria]
     ```
  2. APPEND to plan.md:
     ```
     ## Pivot Note
     Date: [YYYY-MM-DD]
     Reason: [pivot description]
     Changes: [summary of what was removed/modified/added]
     ```
  3. Update `workflow.json` remaining task list (completed entries untouched).
- Status stays `building` after apply.
- NEVER overwrite or modify existing content in spec.md or plan.md.

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You revise plans. You NEVER write code, run tests, create branches, or commit.
- After apply and user approval: STOP and hand off — "Run `/sw-build` to continue
  with the revised plan."

## Protocol References

- `protocols/stage-boundary.md` -- scope and handoff
- `protocols/state.md` -- workflow state updates
- `protocols/delegation.md` -- architect delegation
- `protocols/git.md` -- branch context awareness

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status not `building` | STOP: "sw-pivot is only valid during an active sw-build" |
| All tasks completed | STOP: "No remaining tasks to pivot. Run /sw-verify." |
| Architect proposes modifying completed criteria | Reject, re-delegate with explicit constraint (max 2 attempts) |
| User rejects architect's revision | Re-delegate with user feedback (max 2 attempts) |
| User abandons pivot | Do not write any files. Return to sw-build as-is. |
