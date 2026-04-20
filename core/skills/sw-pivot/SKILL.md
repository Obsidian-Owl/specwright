---
name: sw-pivot
description: >-
  Research-backed rebaselining. Revises design, plan, or in-progress work
  while preserving completed scope and approval lineage.
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

Research-backed rebaselining for the selected work. Capture preserved scope,
understand what changed, classify the pivot, revise the affected open work via
architect, and hand back to `sw-build`. Applies `protocols/decision.md` for
all decisions. Revisions auto-applied and recorded in `decisions.md`; the
revised artifact set is the contract.

## Inputs

- `{worktreeStateRoot}/session.json` — selected work for this worktree
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` — selected work state,
  active unit, `tasksCompleted`, `tasksTotal`, and work/unit paths
- work-level artifacts: `design.md`, `context.md`, `assumptions.md`,
  `decisions.md`, `integration-criteria.md` when present
- active or affected unit artifacts: `spec.md`, `plan.md`, `context.md`
- `{workArtifactsRoot}/{selectedWork.id}/approvals.md` — durable approval ledger for design and unit lineage
- Pivot reason (argument or conversation)
- Optional recent retro or research inputs when available and relevant

## Outputs

- revised work-level artifacts when design or scope changes require them
- regenerated affected remaining-unit artifacts when unit boundaries or
  observable behavior change
- updated `integration-criteria.md` when structural pivots stale the current
  criteria
- selected work's `workflow.json` — pivot classification, active state, and
  affected remaining work updated
- `decisions.md` — pivot decisions recorded

## Constraints

**Pre-condition (LOW freedom):**
Resolve the selected work from the current worktree session. Valid entry states
are `planning`, `building`, and `verifying`. Reject `designing`,
`shipping`, and `shipped` with explicit guidance: use `/sw-design` change
request flow for `designing`, and start a fresh work or normal ship/fix flow
for `shipping` or `shipped`. If another live top-level worktree owns the
selected work, STOP with explicit adopt/takeover guidance.

**Snapshot (LOW freedom):**
Read the selected work's completed and open scope. Present preserved baseline
scope versus delta scope before proposing any mutation.

**Classification (MEDIUM freedom):**
Classify the request before mutation:
- `task-pivot` — execution detail changed but design and unit boundaries remain valid
- `unit-pivot` — current or future unit scope changed, but work-level design intent still holds
- `work-pivot` — design path changed, scope expanded, or the architecture must be rebaselined

**Pivot input (MEDIUM freedom):**
If argument provided, use it as the pivot reason. If no argument, infer from
conversation context per `protocols/decision.md` DISAMBIGUATION.

**Research-first analysis (MEDIUM freedom):**
For `unit-pivot` and `work-pivot`, run a bounded research pass before revision.
Prefer existing tracked artifacts first, recent retro evidence second, and
fresh external research only when the pivot changes an external contract.
Capture the synthesized findings in work context rather than requiring the user
to restate them.

**Revise (HIGH freedom for architect, LOW freedom for mutation):**
Delegate to `specwright-architect` per `protocols/delegation.md`. Completed
tasks and shipped units are immutable baseline scope. Architect may revise
remaining tasks, affected remaining-unit artifacts, or work-level design
artifacts depending on pivot class. If architect proposes rewriting completed
criteria or shipped scope: reject and re-delegate (max 2 attempts). If the
pivot would invalidate shipped scope anyway, STOP and escalate to a fresh
`/sw-design` work instead of rewriting history.

**Apply (MEDIUM freedom):**
Auto-apply the classified revision. `task-pivot` may revise the active unit
task list; `unit-pivot` may regenerate affected remaining-unit artifacts and
`integration-criteria.md`; `work-pivot` may revise work-level design artifacts
plus affected remaining units. Update the selected work's `workflow.json`,
record preserved baseline scope versus delta scope in `decisions.md`, and
mutate only the selected work's workflow state. Never rewrite unrelated active
works. Use revision-chain updates for work-level artifacts instead of creating
parallel design trees.

**State handling (LOW freedom):**
Do not create a new persisted `pivoting` workflow status. `sw-pivot` runs
inside `planning`, `building`, or `verifying`; if active or affected unit
artifacts change, the touched work returns to `building`. If only future units
change and the active unit remains valid, preserve the active unit's current
state.

**Approval lineage (LOW freedom):**
If the pivot changes work-level or unit-level artifacts, the corresponding
design or `unit-spec` approval lineage becomes stale against the revised
artifact set. Use `protocols/approvals.md` and the shared approval helper
implemented in `adapters/shared/specwright-approvals.mjs` to assess and
preserve that stale lineage rather than erasing it. Surface compact stale
reasons such as `missing-entry`, `artifact-set-changed`, `missing-lineage`,
`expired`, and `superseded`. Never fabricate a replacement `APPROVED` entry
during `/sw-pivot`; the next human-triggered `/sw-build` records the
replacement approval that supersedes the stale lineage.

**Closeout summary (LOW freedom):**
Before the stage handoff, summarize the preserved completed scope, delta scope
introduced by the pivot, affected units or tasks, whether the active unit was
reset to `building`, and any stale approval reasons (`missing-entry`,
`artifact-set-changed`, `missing-lineage`, `expired`, `superseded`). The
closeout must make scope preservation explicit instead of implying a
remaining-tasks-only rewrite.

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
| Status not `planning`, `building`, or `verifying` | STOP with the stage-appropriate guidance for `/sw-design` or a fresh follow-up work |
| Selected work owned by another live top-level worktree | STOP with explicit adopt/takeover guidance |
| No open scope remains | STOP: "Run /sw-verify" |
| Architect modifies completed criteria or shipped scope | Reject, re-delegate (max 2) |
| Requested pivot would rewrite shipped scope | STOP and escalate to a fresh `/sw-design` work |
| Compaction during pivot | Read the selected work's workflow.json, check if revision was applied |
