---
name: sw-pivot
description: >-
  Mid-build course correction. Captures committed progress, takes pivot input,
  has the architect revise remaining tasks, and resumes sw-build with a revised plan.
argument-hint: "[reason for pivot]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
---

# Specwright Pivot

## Goal

Graceful course correction during an active sw-build. Capture what's committed,
understand what changed, revise remaining tasks via architect, and hand back to
sw-build. Applies `protocols/decision.md` for all decisions. Revisions auto-applied
and recorded in decisions.md — the revised plan is the artifact.

## Inputs

- `.specwright/state/workflow.json` — `tasksCompleted`, `tasksTotal`, `workDir`
- `{currentWork.workDir}/spec.md` — full spec (completed + remaining)
- `{currentWork.workDir}/plan.md` — task breakdown
- Pivot reason (argument or conversation)

## Outputs

- `spec.md` — appended with `## Revision` section
- `plan.md` — appended with `## Pivot Note` section
- `workflow.json` — remaining tasks updated
- `decisions.md` — pivot decisions recorded

## Constraints

**Pre-condition (LOW freedom):**
Status must be `building`. If all tasks done: STOP — "Run /sw-verify."

**Snapshot (LOW freedom):**
Read tasksCompleted, present done vs. remaining.

**Pivot input (MEDIUM freedom):**
If argument provided, use it as the pivot reason. If no argument, infer from
conversation context per `protocols/decision.md` DISAMBIGUATION.

**Revise (HIGH freedom for architect, LOW freedom for mutation):**
Delegate to `specwright-architect` per `protocols/delegation.md`. Completed tasks
are immutable. Architect revises remaining tasks only. If architect proposes modifying
completed criteria: reject and re-delegate (max 2 attempts).

**Apply (MEDIUM freedom):**
Auto-apply revision. Append revision to spec.md and pivot note to plan.md. Update
workflow.json. Record scope (% tasks changed) and rationale in decisions.md. The
revised plan is the artifact — sw-build resumes from it, verify validates the result.
NEVER overwrite existing content — append only.

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. After apply: STOP → "Run `/sw-build`."

## Protocol References

- `protocols/stage-boundary.md` -- scope and handoff
- `protocols/decision.md` -- autonomous decision framework (scope assessment)
- `protocols/state.md` -- workflow state updates
- `protocols/delegation.md` -- architect delegation
- `protocols/git.md` -- branch context

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status not `building` | STOP: "sw-pivot only valid during active sw-build" |
| All tasks completed | STOP: "Run /sw-verify" |
| Architect modifies completed criteria | Reject, re-delegate (max 2) |
| Compaction during pivot | Read workflow.json, check if revision was applied |
