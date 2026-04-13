# State Management Protocol

## Logical Roots

State is resolved through logical Git roots, not checkout-local path literals.

| Root | Resolution | Purpose |
|---|---|---|
| `projectRoot` | `git rev-parse --show-toplevel` | Source tree and user-facing command cwd |
| `repoStateRoot` | `git rev-parse --git-common-dir` + `/specwright` | Shared repo-wide Specwright state |
| `worktreeStateRoot` | `git rev-parse --git-dir` + `/specwright` | Per-worktree runtime session state |

Callers must not treat `cwd/.specwright/...` as authoritative once the new
layout exists. Legacy working-tree `.specwright/` remains a migration fallback
only.

## State Files And Ownership

Two state files now exist:

| File | Owner | Scope | Mutable by |
|---|---|---|---|
| `{repoStateRoot}/work/{workId}/workflow.json` | one work | lifecycle, units, gates, task progress, attachment, lock | skills operating on that selected work |
| `{worktreeStateRoot}/session.json` | one worktree | local work selection and session mode | skills running in that worktree |

Shared work artifacts live beside the per-work workflow file:

```text
{repoStateRoot}/
  config.json
  CONSTITUTION.md
  CHARTER.md
  TESTING.md
  work/
    {workId}/
      workflow.json
      design.md
      context.md
      decisions.md
      assumptions.md
      stage-report.md
      units/
        {unitId}/
          spec.md
          plan.md
          context.md
          stage-report.md
          evidence/
```

Per-worktree runtime data lives under the active Git admin directory:

```text
{worktreeStateRoot}/
  session.json
  continuation.md
```

## Workflow Schema

Each top-level work owns its own workflow file.

```json
{
  "version": "3.0",
  "id": "string, kebab-case",
  "description": "string",
  "status": "designing | planning | building | verifying | shipping | shipped | abandoned",
  "workDir": "work/{workId}/units/{unitId} or work/{workId}",
  "unitId": "string | null",
  "tasksTotal": "number | null",
  "tasksCompleted": ["task-id strings"],
  "currentTask": "string | null",
  "baselineCommit": "string | null",
  "branch": "string | null",
  "lastCommit": "string | null",
  "workUnits": [
    {
      "id": "string",
      "description": "string",
      "status": "pending | planned | building | verifying | shipping | shipped | abandoned",
      "order": "number",
      "workDir": "relative path under repoStateRoot/work/{workId}",
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
- `workUnits[{n}].prNumber` and `workUnits[{n}].prMergedAt` are optional,
  nullable, backward-compatible fields.
- Older workflow files may omit either field; readers must treat both
  omissions as backward-compatible legacy state.
- `workDir` remains the unit-local artifact path for the selected unit. Skills
  still resolve unit-local files through `workflow.workDir`, never by guessing
  from IDs.
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

If validation fails, STOP with explicit adopt/takeover guidance. Do not
silently allow split-brain mutation of one work from two top-level worktrees.

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
- ship, verify, or otherwise mutate shared work state directly outside the
  parent orchestration contract

## State Transitions

Valid lifecycle transitions are enforced per selected work:

| From | To | Triggered by |
|---|---|---|
| (none) | `designing` | sw-design creates a new work and attaches the current session |
| `designing` | `planning` | sw-plan |
| `planning` | `building` | sw-plan or sw-build |
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

Two artifact scopes remain:

| Scope | How to resolve | Contains |
|---|---|---|
| Unit-local | `workflow.workDir` under `{repoStateRoot}` | `spec.md`, `plan.md`, `context.md`, unit `stage-report.md`, `evidence/` |
| Work-level | `{repoStateRoot}/work/{workId}/` | `workflow.json`, `design.md`, `decisions.md`, `assumptions.md`, work `stage-report.md` |

For single-unit work, both scopes may refer to the same work directory. For
multi-unit work, `workflow.workDir` points at `units/{unitId}/`.

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
artifacts only when the new layout is absent. Once `{repoStateRoot}` or
`{worktreeStateRoot}` exists, writes go only to the new shared/session layout.
Mixed writes are forbidden.

## Critical Rules

- **NEVER** treat one repo-global `workflow.json` as the source of truth in the
  new model
- **ALWAYS** resolve paths through `repoStateRoot` and `worktreeStateRoot`
- **NEVER** let subordinate sessions claim top-level ownership
- **ALWAYS** preserve existing fields not being changed
- **NEVER** partially update a JSON state file
