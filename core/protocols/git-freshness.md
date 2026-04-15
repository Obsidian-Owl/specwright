# Git Freshness Protocol

Shared contract for assessing branch freshness against a work's recorded target
branch.

## Purpose

`git-freshness` exists so `sw-build`, `sw-verify`, `sw-ship`, and support
surfaces can consume one deterministic checkpoint contract instead of
re-deriving Git ancestry rules independently.

This protocol defines:

- the storage boundary model the helper must respect
- the inputs and result shape for freshness assessment
- the supported validation backends and reconcile policies
- the explicit side-effect boundary for helper code

It does not define user-facing lifecycle policy on its own. Later skills apply
their checkpoint severity rules to the helper result.

## Storage Boundary Model

Freshness assessment must distinguish three storage classes.

### 1. Clone-local runtime state

This state is local to one clone or one worktree session. It includes:

- `session.json`
- `continuation.md`
- work attachment ownership
- per-work locks
- `lastSeenAt` style liveness timestamps
- absolute worktree paths and other machine-local diagnostics

This clone-local runtime state is never treated as a publishable audit trail.

### 2. Project-level artifacts

These project-level artifacts describe how the project is supposed to work and
may need to be reviewed or pushed with normal Git history. They include:

- `config.json`
- `CONSTITUTION.md`
- `CHARTER.md`
- `TESTING.md`
- the project's effective Git policy/config surface

### 3. Optional auditable work artifacts

Some work artifacts may need a remote audit trail, but that is a separate
publication decision from runtime orchestration. Examples include:

- `design.md`
- `context.md`
- `decisions.md`
- `assumptions.md`
- `approvals.md`
- `integration-criteria.md`
- `spec.md`
- `plan.md`
- `implementation-rationale.md`
- `review-packet.md`
- evidence artifacts

These optional auditable work artifacts may remain clone-local in one mode and
be published in another. They resolve under `workArtifactsRoot`, not under
runtime-only `repoStateRoot`. The helper contract must not assume one
universal storage backend for them.

## Resolution Rules

The helper operates from recorded work state and resolved roots.

- Inputs come from recorded work state and resolved roots, not from one
  hardcoded `.git/specwright` path.
- The selected work's `targetRef`, when present, is the first branch target.
- If `targetRef` is absent, the helper falls back to `config.git.targets`, then
  the `baseBranch` compatibility alias.
- The helper consumes the resolved `git.freshness` policy from config or the
  work-level `freshness` snapshot when later skills materialize it.
- The helper must not depend on symlinked mirrors between runtime roots and
  tracked artifact roots.

## Supported Validation Backends

- `branch-head`: compare the current branch with the resolved target branch
- `queue`: treat provider-managed merge freshness as the final authority

## Supported Reconcile Modes

- `manual`
- `rebase`
- `merge`

The helper reports which mode is configured. It does not execute the
reconciliation itself.

## Result Categories

The helper returns one of these statuses:

- `fresh`
- `stale`
- `diverged`
- `blocked`
- `queue-managed`

Recommended meanings:

- `fresh`: the current branch already contains the target head
- `stale`: the target advanced and the current branch does not include it
- `diverged`: both current and target have unique commits
- `blocked`: inputs or Git state are insufficient for a reliable assessment
- `queue-managed`: local branch-head freshness is not the deciding authority

## Result Shape

Minimum machine-readable shape:

```json
{
  "phase": "build | verify | ship",
  "targetRef": {
    "remote": "origin",
    "branch": "main",
    "role": "integration"
  },
  "validation": "branch-head | queue",
  "reconcile": "manual | rebase | merge",
  "checkpoint": "ignore | warn | require",
  "status": "fresh | stale | diverged | blocked | queue-managed",
  "ahead": 0,
  "behind": 0,
  "targetHead": "sha | null",
  "currentHead": "sha | null",
  "recommendedAction": "continue | stop | warn | delegate-to-queue",
  "guidance": "short human-readable summary"
}
```

Callers may add extra diagnostics, but they must preserve the stable fields
above.

## Explicit Side-Effect Boundary

Allowed:

- read Git refs and ancestry data
- fetch the resolved target remote when the caller requests an explicit fetch

Not allowed:

- checkout
- merge
- rebase
- commit
- push
- create or update PRs
- rewrite session or workflow ownership state as part of assessment

The helper is an assessor, not a mutator.

## Caller Responsibilities

- lifecycle skills decide whether a result blocks, warns, or proceeds
- publication mode for optional auditable work artifacts comes from
  `config.git.workArtifacts` in `protocols/git.md`, not from this helper
- redaction or safe publication of evidence is handled by the surfaces that
  expose or commit those artifacts

## Non-Goals

- defining merge-queue provider playbooks inline
- using symlinks as the contract between runtime-local and tracked artifacts
- turning runtime ownership state into committed repo truth
