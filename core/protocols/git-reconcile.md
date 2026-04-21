# Git Reconcile Protocol

Shared contract for lifecycle-owned Git freshness recovery.

## Purpose

`git-reconcile` owns the mutating half of freshness recovery after
`git-freshness` has already assessed the selected work.

It exists so `sw-build`, `sw-verify`, and `sw-ship` can recover stale or
diverged branch-head state inside the blocked lifecycle stage without
collapsing read-only assessment and branch mutation into one opaque helper.

## Preconditions

Lifecycle-owned reconcile is only eligible when all of the following are true:

- freshness validation is `branch-head`
- the selected work resolves in the current owning worktree
- the current session is `top-level`
- the current branch matches the selected work's recorded branch when one is
  recorded
- the worktree is clean before mutation
- the assessed freshness result is `stale` or `diverged`
- the configured reconcile mode is `rebase` or `merge`

If any precondition fails, the helper must fail closed with a structured
result instead of mutating Git state.

## Supported Reconcile Modes

- `rebase` — replay the current branch onto the recorded target ref
- `merge` — merge the recorded target ref into the current branch
- `manual` — explicit fallback; stop and tell the operator to reconcile
  manually in the owning worktree

Queue-managed validation is not a local reconcile mode. When `validation =
queue`, the helper reports `queue-managed` and performs no local rewrite.

## Ownership And Safety

The helper must treat the owning worktree as authoritative.

- Session ownership comes from `session.json`
- `workflow.json.attachment` is a diagnostic snapshot that must agree with the
  current worktree when present
- ownership mismatch is fail-closed
- subordinate sessions must not run local reconcile for the parent work
- dirty worktree state is fail-closed
- conflicted rebase or merge attempts must be aborted before returning

The helper must not rewrite:

- `targetRef`
- workflow ownership state
- approval lineage
- unrelated branches or worktrees

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
  "status": "noop | reconciled | blocked | queue-managed",
  "action": "rebase | merge | null",
  "performed": true,
  "currentBranch": "feature-branch",
  "currentHeadBefore": "sha | null",
  "currentHeadAfter": "sha | null",
  "targetHead": "sha | null",
  "freshnessBefore": "fresh | stale | diverged | blocked | queue-managed",
  "freshnessAfter": "fresh | stale | diverged | blocked | queue-managed | null",
  "recommendedAction": "continue | stop | delegate-to-queue",
  "reasonCode": "manual-policy | dirty-worktree | ownership-mismatch | conflict | assessment-blocked | null",
  "guidance": "short human-readable summary"
}
```

Callers may add diagnostics, but they must preserve the stable fields above.

## Explicit Side-Effect Boundary

Allowed:

- read and fetch the resolved target remote ref
- rebase the current branch onto the resolved target ref
- merge the resolved target ref into the current branch
- abort an in-progress rebase or merge after a conflict

Not allowed:

- checkout a different branch to perform the reconcile
- mutate session ownership or workflow attachment to justify a reconcile
- push, create commits unrelated to the rebase or merge result, or open PRs
- downgrade the recorded checkpoint policy to bypass a stop

## Caller Responsibilities

- lifecycle stages use `git-freshness` first to determine whether reconcile is
  needed
- when reconcile mode is `rebase` or `merge`, the blocked lifecycle stage owns
  the recovery and may continue in that same stage after successful reconcile
- when reconcile mode is `manual`, stop and route the operator to manual
  recovery in the owning worktree
- shipping keeps one explicit exception: after a manual reconcile stop, rerun
  `/sw-verify` before `/sw-ship`
- queue-managed validation remains provider-owned and must not trigger a local
  rewrite attempt

## Non-Goals

- choosing merge queue policy for the repository
- inventing ownership or approval state when they disagree
- hiding branch conflicts behind a best-effort auto-resolution step
