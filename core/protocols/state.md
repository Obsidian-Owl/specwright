# State Management Protocol

## Logical Roots

State is resolved through logical Git roots, not checkout-local path literals.

| Root | Resolution | Purpose |
|---|---|---|
| `projectRoot` | `git rev-parse --show-toplevel` | Source tree and user-facing command cwd |
| `projectArtifactsRoot` | `{projectRoot}/.specwright` | Tracked project artifacts and guidance |
| `repoStateRoot` | `git rev-parse --git-common-dir` + `/specwright` | Shared clone-local runtime state |
| `worktreeStateRoot` | `git rev-parse --git-dir` + `/specwright` | Per-worktree runtime session state |
| `workArtifactsRoot` | `{repoStateRoot}/work` by default; tracked root from `config.git.workArtifacts` when configured | Auditable work artifacts |

Callers must not treat `cwd/.specwright/...` as authoritative once the new
layout exists. Legacy working-tree `.specwright/` remains a migration fallback
only.

## State Files And Ownership

Two state files now exist:

| File | Owner | Scope | Mutable by |
|---|---|---|---|
| `{repoStateRoot}/work/{workId}/workflow.json` | one work | lifecycle, units, gates, task progress, attachment, lock | skills operating on that selected work |
| `{worktreeStateRoot}/session.json` | one worktree | local work selection and session mode | skills running in that worktree |

For live ownership, `{worktreeStateRoot}/session.json` is the live ownership
truth for that worktree. `workflow.json.attachment` is a per-work diagnostic
snapshot and must not be treated as permission to mutate a work without first
checking live sessions.
Stated plainly: `session.json` is the live ownership truth.

Tracked project artifacts live under the project root:

```text
{projectArtifactsRoot}/
  config.json
  CONSTITUTION.md
  CHARTER.md
  TESTING.md
  LANDSCAPE.md
  AUDIT.md
  patterns.md
  research/
```

Auditable work artifacts live under the selected work root:

```text
{workArtifactsRoot}/
  {workId}/
    design.md
    context.md
    decisions.md
    assumptions.md
    approvals.md
    integration-criteria.md
    units/
      {unitId}/
        spec.md
        plan.md
        context.md
        implementation-rationale.md
        review-packet.md
        evidence/
```

Runtime work and session data stay under the Git admin directories:

```text
{repoStateRoot}/
  work/
    {workId}/
      workflow.json
      stage-report.md
      units/
        {unitId}/
          stage-report.md

{worktreeStateRoot}/
  session.json
  continuation.md
```

## Workflow Schema

Each top-level work owns its own workflow file.

The schema below shows the populated v3 shape. Legacy workflow files may omit
`targetRef`, `freshness`, `prNumber`, or `prMergedAt` until migration or later
stages populate them.

```json
{
  "version": "3.0",
  "id": "string, kebab-case",
  "description": "string",
  "status": "designing | planning | building | verifying | shipping | shipped | abandoned",
  "workDir": "relative path under workArtifactsRoot/{workId} (legacy work/{workId}/... allowed during migration)",
  "unitId": "string | null",
  "tasksTotal": "number | null",
  "tasksCompleted": ["task-id strings"],
  "currentTask": "string | null",
  "baselineCommit": "string | null",
  "targetRef": {
    "remote": "string",
    "branch": "string",
    "role": "string",
    "resolvedBy": "string",
    "resolvedAt": "ISO timestamp"
  },
  "freshness": {
    "validation": "branch-head | queue",
    "reconcile": "manual | rebase | merge",
    "checkpoints": {
      "build": "ignore | warn | require",
      "verify": "ignore | warn | require",
      "ship": "ignore | warn | require"
    },
    "status": "unknown | fresh | stale | diverged | blocked | queue-managed",
    "lastCheckedAt": "ISO timestamp | null"
  },
  "branch": "string | null",
  "lastCommit": "string | null",
  "workUnits": [
    {
      "id": "string",
      "description": "string",
      "status": "pending | planned | building | verifying | shipping | shipped | abandoned",
      "order": "number",
      "workDir": "relative path under workArtifactsRoot/{workId} (legacy work/{workId}/... allowed during migration)",
      "prNumber": "number | null",
      "prMergedAt": "ISO timestamp | null"
    }
  ],
  "gates": {
    "{gate-name}": {
      "verdict": "PASS | FAIL | WARN | ERROR | SKIP",
      "lastRun": "ISO timestamp",
      "evidence": "path relative to the owning work",
      "findings": { "block": 0, "warn": 0, "info": 0 }
    }
  },
  "attachment": {
    "worktreeId": "string",
    "worktreePath": "absolute path",
    "mode": "top-level | subordinate",
    "attachedAt": "ISO timestamp",
    "lastSeenAt": "ISO timestamp"
  },
  "lock": {
    "skill": "string",
    "since": "ISO timestamp",
    "worktreeId": "string"
  },
  "lastUpdated": "ISO timestamp"
}
```

### Workflow Notes

- `gates`, `tasksCompleted`, `workUnits`, and `lock` belong to the work, not
  to the current terminal session.
- `attachment` records the current owner of the work. It replaces the old
  repo-global `currentWork`.
- `targetRef` is work-level state for the selected work, not a repo-global
  singleton. `sw-design` records the concrete remote, branch, role, and
  resolution source once so later stages stop guessing what the work targets.
- `targetRef.resolvedBy` is descriptive provenance such as a config path or
  user override marker. Readers must treat it as explanatory metadata, not as a
  stable enum or branching primitive.
- `baselineCommit` remains the design-time HEAD of the recorded target branch.
  `targetRef` is the live branch target for the work and may stay stable even
  after the remote head advances.
- `freshness` stores the selected work's resolved validation mode, reconcile
  policy, checkpoint severities, and latest known checkpoint result. It belongs
  to the selected work alongside `targetRef`, not to repo-global state.
- `workUnits[{n}].prNumber` is an optional, nullable, backward-compatible `number | null` field.
- `workUnits[{n}].prMergedAt` is an optional, nullable, backward-compatible `ISO timestamp | null` field.
- Older workflow files may omit either field; readers must treat both
  omissions as backward-compatible legacy state.
- Older workflow files may also omit `targetRef` and `freshness`; readers must
  treat both omissions as backward-compatible legacy state until the new model
  is populated, even though the schema block above shows the populated shape.
- `workDir` remains the unit-local auditable artifact path for the selected
  unit. Skills still resolve unit-local files through `workflow.workDir`,
  never by guessing from IDs.
- Readers must accept existing `work/`-prefixed `workDir` values during
  migration and normalize them before joining against `workArtifactsRoot`.
- `stage-report.md` files are runtime-only handoff digests. They resolve from
  `repoStateRoot/work/{workId}` and are not part of the auditable
  `workArtifactsRoot` tree.
- `lock` is per-work. A lock on work A must not block mutations to work B.

## Session Schema

Each worktree owns its own session file.

```json
{
  "version": "3.0",
  "worktreeId": "string",
  "worktreePath": "absolute path",
  "branch": "string | null",
  "attachedWorkId": "string | null",
  "mode": "top-level | subordinate",
  "lastSeenAt": "ISO timestamp"
}
```

### Session Rules

- A top-level session is created for a normal user-facing worktree.
- A subordinate session is created only for orchestrated helper worktrees such
  as `parallel-build`.
- A top-level session may attach to zero or one work.
- A work may have zero or one top-level attachment.
- A subordinate session may reference a parent work, but it never becomes the
  authoritative owner of that work.

## Work Selection

State-aware callers resolve the selected work in this order:

1. explicit work selector, if the skill supports one
2. `{worktreeStateRoot}/session.json.attachedWorkId`
3. legacy fallback during migration only

If no work resolves and the operation requires one, STOP with the same
guidance as today:

> "Run /sw-design first."

## Attachment Ownership

Attaching a top-level session to a work must validate all of the following:

1. the target work exists under `{repoStateRoot}/work/{workId}`
2. no other live top-level session already owns that work
3. the current branch is consistent with the work's recorded branch when the
   work is already in `building`, `verifying`, or `shipping`
4. same-work continuation into a different top-level worktree is being
   requested explicitly via `/sw-adopt`

If validation fails, STOP with explicit adopt/takeover guidance. Do not
silently allow split-brain mutation of one work from two top-level worktrees.
Explicit same-work adoption must not degrade into implicit branch-based
takeover. Matching the recorded branch is necessary for in-flight checks, but
it is never sufficient to transfer ownership on its own.
Stated plainly: explicit same-work adoption is not implicit branch takeover.

## Subordinate Sessions

Subordinate sessions are allowed only as controlled helper contexts.

They may:

- read the parent work's shared artifacts
- keep local continuation or scratch context under `worktreeStateRoot`
- report completion back to the parent orchestrator

They must not:

- create a new top-level `workId`
- rewrite another worktree's `session.json`
- claim top-level ownership in `workflow.json.attachment`
- ship, verify, run `/sw-adopt`, or otherwise mutate shared workflow state directly outside the
  parent orchestration contract

## State Transitions

Valid lifecycle transitions are enforced per selected work:

| From | To | Triggered by |
|---|---|---|
| (none) | `designing` | sw-design creates a new work and attaches the current session |
| `designing` | `planning` | sw-plan |
| `planning` | `building` | sw-plan or sw-build or sw-pivot (work-pivot) |
| `building` | `verifying` | sw-verify |
| `verifying` | `building` | fix after failed verify |
| `verifying` | `shipping` | sw-ship |
| `shipping` | `shipped` | sw-ship |
| `shipping` | `verifying` | sw-ship rollback after push or PR failure |
| `shipped` | `building` | sw-ship advances the same work to its next queued unit |
| `shipped` | `designing` | sw-design creates a new work in the current session |
| `shipped` | (none) | sw-learn clears the session attachment when capture is complete |
| any | `abandoned` | sw-status --reset |

`sw-learn` is an optional capture step after `shipped`. It is never a
prerequisite for starting the next work or queued unit.

### Pivoted Re-entry

`sw-pivot` is not a new persisted workflow status. It operates inside
`planning`, `building`, and `verifying`.

- `task-pivot` keeps the active status unchanged when the active unit still
  holds (`building` or `verifying` as appropriate)
- `unit-pivot` or `work-pivot` may return the touched work to `building` when
  active or affected unit artifacts change
- `sw-pivot` must preserve shipped units as shipped baseline scope rather than
  rewriting them
- no `pivoting` status is added to `workflow.json`; the existing lifecycle
  state remains the only persisted status vocabulary

**Enforcement:** skills check the selected work's `status` before mutating. If
the intended transition is invalid, STOP with:

> "Cannot transition work {workId} from {current} to {target}. Run /sw-{correct-skill} instead."

## Enumeration Model

Known works are discovered by enumerating:

- `{repoStateRoot}/work/*/workflow.json`

Live worktree attachments are discovered by:

1. `git worktree list --porcelain`
2. resolving each listed worktree's Git admin dir
3. reading its `{worktreeStateRoot}/session.json` when present

No repo-global active-work registry is required in the first version.

## Path Resolution Convention

Four artifact scopes remain:

| Scope | How to resolve | Contains |
|---|---|---|
| Project-level tracked | `{projectArtifactsRoot}/` | `config.json`, anchor docs, research, learnings |
| Work-level auditable | `{workArtifactsRoot}/{workId}/` | `design.md`, `context.md`, `decisions.md`, `assumptions.md`, `approvals.md`, `integration-criteria.md` |
| Unit-local auditable | `workflow.workDir` under `{workArtifactsRoot}` | `spec.md`, `plan.md`, `context.md`, `implementation-rationale.md`, `review-packet.md`, `evidence/` |
| Runtime work/session | `{repoStateRoot}/work/{workId}/` and `{worktreeStateRoot}/` | `workflow.json`, work and unit `stage-report.md` files, attachment/lock/task state, `session.json`, `continuation.md` |

For single-unit work, the work-level and unit-local auditable scopes may point
at the same work directory. For multi-unit work, `workflow.workDir` points at
`{workId}/units/{unitId}/` after normalization.

## Read-Modify-Write Sequence

This is the most fragile operation. Follow exactly.

1. Resolve logical roots.
2. Read the current session file if the operation is session-aware.
3. Read the selected work's `workflow.json` if the operation is work-aware.
4. Parse the full JSON document(s). If parse fails, STOP with diagnostics.
5. Apply only the intended mutation.
6. Write back the full object(s) with `JSON.stringify(state, null, 2)`.
7. Always refresh `lastUpdated` on `workflow.json` and `lastSeenAt` on
   `session.json` when those files are written.

## Lock Protocol

Before mutating a work:

- read that work's `workflow.json.lock`
- if a lock exists and is younger than 30 minutes and `lock.worktreeId` does
  not match the current worktree, STOP with lock info

Acquire:

- set `lock = { "skill": "{name}", "since": "{ISO}", "worktreeId": "{currentWorktreeId}" }`
  before other mutations to that work

Release:

- set `lock: null` after the mutation batch completes

Stale locks:

- locks older than 30 minutes may be auto-cleared with a warning
- stale lock repair is scoped to the selected work only

Session files do not use the shared work lock. They are single-writer by
construction because each `session.json` belongs to one worktree.

## Legacy Compatibility

During migration, callers may still read legacy checkout-local `.specwright/`
artifacts only when the new layout is absent. Once the new roots exist, writes
go only to their authoritative surface. Mixed writes are forbidden.

## Critical Rules

- **NEVER** treat one repo-global `workflow.json` as the source of truth in the
  new model
- **ALWAYS** resolve paths through the documented logical roots instead of
  concatenating checkout-local literals
- **NEVER** let subordinate sessions claim top-level ownership
- **ALWAYS** preserve existing fields not being changed
- **NEVER** partially update a JSON state file
