---
name: sw-adopt
description: >-
  Explicitly adopt an existing work into the current worktree after validating
  live ownership, stale sessions, and branch consistency.
argument-hint: "<work-id>"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
---

# Specwright Adopt

## Goal

Attach an existing work to the current worktree without creating split-brain
ownership. This skill attaches only the current worktree session.

## Inputs

- target work ID from the argument, or the current worktree session's
  `attachedWorkId` when re-adopting the already-selected work
- `{worktreeStateRoot}/session.json` for the current worktree
- `{repoStateRoot}/work/{workId}/workflow.json`
- repo-wide `session.json` files discovered via `git worktree list --porcelain`

## Outputs

- updated `{worktreeStateRoot}/session.json` for the current worktree only
- updated selected work `workflow.json.attachment` pointing at the current
  worktree when adoption succeeds
- concise outcome explaining whether the work was adopted, blocked by a live
  owner, or blocked by branch mismatch

## Constraints

**Scope (LOW freedom):**
- `/sw-adopt` is the explicit same-work adoption flow. It must not silently run
  during `/sw-design`, `/sw-plan`, `/sw-build`, `/sw-verify`, or `/sw-ship`.
- `/sw-adopt` never rewrites another worktree's `session.json`.
- Subordinate sessions must not run `/sw-adopt`.

**Target resolution (LOW freedom):**
- Resolve the target work from the argument first, then the current worktree's
  `session.json.attachedWorkId` as a fallback.
- Validate that the target work exists under `{repoStateRoot}/work/{workId}`.
- If no target work resolves, STOP and tell the operator to pass a work ID or
  run `/sw-design`.

**Ownership validation (LOW freedom):**
- Use live-versus-dead session state as the adoption authority.
- Inspect repo-wide `session.json` files to determine live-versus-dead session
  state for the target work.
- Treat live top-level sessions as authoritative owners.
- Treat dead top-level sessions as stale attachments that may be superseded.
- Treat subordinate sessions as non-owners even when they reference the same
  `workId`.
- If another live top-level worktree owns the target work, STOP and tell the
  operator to continue there or make that owner stale first. `/sw-adopt` does
  not perform remote session surgery.

**Branch consistency (LOW freedom):**
- When the target work is already in `building`, `verifying`, or `shipping`,
  validate branch consistency against `workflow.json.branch`.
- Matching the recorded branch is necessary for in-flight adoption, but it is
  never sufficient to seize ownership on its own.
- If the current worktree branch is inconsistent with the recorded branch,
  STOP and tell the operator to check out the recorded branch first.

**Mutation boundary (LOW freedom):**
- On success, mutate only the current worktree's `session.json` and the target
  work's `workflow.json`.
- Update the target work's `workflow.json.attachment` to the current worktree,
  refresh `workflow.json.branch` from the current worktree branch, and refresh
  liveness timestamps.
- Never clear or rewrite another worktree's session file as part of adoption.

## Protocol References

- `protocols/state.md` -- live ownership, attachment validation, subordinate rules
- `protocols/context.md` -- logical roots and session discovery
- `protocols/git.md` -- recorded branch context

## Failure Modes

| Condition | Action |
|-----------|--------|
| No target work resolves | STOP: "Pass a work ID or run /sw-design first." |
| Target work does not exist | STOP with a missing-work error |
| Current session is subordinate | STOP: "Subordinate helper sessions cannot adopt work." |
| Another live top-level worktree owns the target work | STOP with live-owner guidance |
| Recorded branch mismatch for in-flight work | STOP with branch-consistency guidance |
