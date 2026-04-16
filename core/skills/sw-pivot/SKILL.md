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

- `{worktreeStateRoot}/session.json` — selected work for this worktree
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` — `tasksCompleted`, `tasksTotal`, `workDir`
- `{workDir}/spec.md` — full spec (completed + remaining)
- `{workDir}/plan.md` — task breakdown
- `{workDir}/context.md` — unit context that downstream build and verify consume
- `{workArtifactsRoot}/{selectedWork.id}/approvals.md` — durable approval ledger for design and unit lineage
- Pivot reason (argument or conversation)

## Outputs

- `spec.md` — appended with `## Revision` section
- `plan.md` — appended with `## Pivot Note` section
- selected work's `workflow.json` — remaining tasks updated
- `decisions.md` — pivot decisions recorded

## Constraints

**Pre-condition (LOW freedom):**
Resolve the selected work from the current worktree session. Status must be
`building`. If all tasks are done: STOP — "Run /sw-verify." If another live
top-level worktree owns the selected work, STOP with explicit
adopt/takeover guidance.

**Snapshot (LOW freedom):**
Read the selected work's `tasksCompleted`, present done vs. remaining.

**Pivot input (MEDIUM freedom):**
If argument provided, use it as the pivot reason. If no argument, infer from
conversation context per `protocols/decision.md` DISAMBIGUATION.

**Revise (HIGH freedom for architect, LOW freedom for mutation):**
Delegate to `specwright-architect` per `protocols/delegation.md`. Completed tasks
are immutable. Architect revises remaining tasks only. If architect proposes modifying
completed criteria: reject and re-delegate (max 2 attempts).

**Apply (MEDIUM freedom):**
Auto-apply revision. Append revision to spec.md and pivot note to plan.md. Update
the selected work's `workflow.json`. Record scope (% tasks changed) and
rationale in decisions.md. The revised plan is the artifact — sw-build resumes
from it, verify validates the result. Mutate only the selected work's
workflow state; never rewrite unrelated active works. NEVER overwrite existing
content — append only.

**Approval lineage (LOW freedom):**
If the pivot changes `spec.md`, `plan.md`, or `context.md`, the current
`unit-spec` approval lineage becomes stale against the revised artifact set.
Use `protocols/approvals.md` and the shared approval helper implemented in
`adapters/shared/specwright-approvals.mjs` to assess and preserve that stale
lineage rather than erasing it. Never fabricate a replacement `APPROVED`
entry during `/sw-pivot`; the next human-triggered `/sw-build` records the
replacement approval that supersedes the stale lineage.

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. After apply: STOP → "Run `/sw-build`."

## Protocol References

- `protocols/stage-boundary.md` -- scope and handoff
- `protocols/decision.md` -- autonomous decision framework (scope assessment)
- `protocols/state.md` -- workflow state updates
- `protocols/approvals.md` -- approval lineage invalidation and stale-state handling
- `protocols/delegation.md` -- architect delegation
- `protocols/git.md` -- branch context

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status not `building` | STOP: "sw-pivot only valid during active sw-build" |
| Selected work owned by another live top-level worktree | STOP with explicit adopt/takeover guidance |
| All tasks completed | STOP: "Run /sw-verify" |
| Architect modifies completed criteria | Reject, re-delegate (max 2) |
| Compaction during pivot | Read the selected work's workflow.json, check if revision was applied |
