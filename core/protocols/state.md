# State Management Protocol

## Workflow State File

**Location:** `.specwright/state/workflow.json`

## Schema

```json
{
  "version": "2.0",
  "currentWork": {
    "id": "string, kebab-case",
    "description": "string",
    "status": "designing | planning | building | verifying | shipping | shipped | abandoned",
    "workDir": ".specwright/work/{id}",
    "unitId": "string | null",
    "tasksTotal": "number | null",
    "tasksCompleted": ["task-id strings"],
    "currentTask": "string | null",
    "baselineCommit": "string | null — SHA of baseBranch HEAD at design start"
  },
  "gates": {
    "{gate-name}": {
      "verdict": "PASS | FAIL | WARN | ERROR | SKIP",
      "lastRun": "ISO timestamp",
      "evidence": "path to evidence file",
      "findings": { "block": 0, "warn": 0, "info": 0 }
    }
  },
  "workUnits": [
    { "id": "string", "description": "string", "status": "pending | planned | building | verifying | shipping | shipped | abandoned", "order": "number", "workDir": "string" }
  ],
  "lock": {
    "skill": "string",
    "since": "ISO timestamp"
  },
  "lastUpdated": "ISO timestamp"
}
```

`currentWork` is null when no work is active. `lock` is null when unlocked.
`workUnits` is null for single-unit work (backward compatible). When present, `currentWork` still points to the active unit.

`unitId` is the active unit within the work. Null for single-unit work. In multi-unit mode, `workDir` points to the active unit's directory (e.g., `.specwright/work/{id}/units/{unitId}/`). For single-unit work, `workDir` points to the work root (unchanged).

`baselineCommit` is the SHA of the base branch HEAD at design start. Set by sw-design when creating `currentWork`. Never mutated after initial set (sw-pivot does not change it). Cleared when `currentWork` is cleared to null by sw-learn. Also recorded in `{workDir}/context.md` by sw-design for historical reference (survives currentWork clearing).

`workUnits` entry statuses: `pending` (not yet planned), `planned` (spec written and approved, waiting to be activated), `building`/`verifying`/`shipping`/`shipped`/`abandoned` (same as currentWork). The `planned` status is set by sw-plan after a unit's spec is individually approved. Each entry's `workDir` is the artifact directory path for that unit (source of truth — skills read this field, never construct paths from id).

## State Transitions

Valid transitions for `currentWork.status`:

| From | To | Triggered by |
|------|----|-------------|
| (none) | `designing` | sw-design (new work) |
| `designing` | `planning` | sw-plan |
| `planning` | `building` | sw-plan (all specs approved) or sw-build |
| `building` | `verifying` | sw-verify |
| `verifying` | `building` | fix after failed verify |
| `verifying` | `shipping` | sw-ship (gates pass, evidence exists) |
| `shipping` | `shipped` | sw-ship (PR created successfully) |
| `shipping` | `verifying` | sw-ship (push or PR creation failed — rollback) |
| `shipped` | `building` | sw-ship (next unit advancement) |
| `shipped` | `designing` | sw-design (clears prior shipped work to start new) |
| `shipped` | (none) | sw-learn (clears `currentWork` to null — optional) |
| any | `abandoned` | sw-status --reset |
| `abandoned` | (none) | sw-status --cleanup or sw-design (clears abandoned work before starting new) |

**sw-learn is an optional capture step.** The state machine permits exit from
`shipped` directly via sw-design (to start new work) or via sw-ship (to advance
to the next queued unit). sw-learn remains valid for pattern capture before
clearing, but it is never required to unblock the next pipeline run. Core
pipeline skills never enforce sw-learn as a hard prerequisite.

**Enforcement:** Skills MUST check `currentWork.status` before mutating. If the current status is not a valid "from" state for the intended transition, STOP with:
> "Cannot transition from {current} to {target}. Run /sw-{correct-skill} instead."

When `workUnits` exists, also update the matching entry's status in the array.

**Gates reset:** When a new unit is activated (via sw-plan or sw-ship unit advancement), the `gates` section is reset to `{}`. Historical gate results for shipped units persist in their `{unitWorkDir}/evidence/` directories.

## Path Resolution Convention

Two scopes exist for resolving work artifact paths:

| Scope | How to resolve | Contains |
|-------|---------------|----------|
| **Unit-local** | `{currentWork.workDir}/` | `spec.md`, `plan.md`, `context.md`, `evidence/` |
| **Design-level** | `.specwright/work/{currentWork.id}/` | `design.md`, `assumptions.md`, `decisions.md`, conditional artifacts |

For single-unit work, both scopes resolve to the same directory. For multi-unit work, unit-local points to `units/{unitId}/` while design-level points to the work root.

**Rule:** Skills MUST resolve unit-local artifacts through `currentWork.workDir`. Never construct paths from `currentWork.id` for unit-local artifacts.

## Read-Modify-Write Sequence

**This is the most fragile operation. Follow exactly.**

1. Read the file. Parse as JSON. If parse fails, STOP with diagnostic.
2. Apply your specific mutation to the parsed object.
3. Write back the FULL object with `JSON.stringify(state, null, 2)` formatting.
4. Always set `lastUpdated` to current ISO timestamp.

## Lock Protocol

**Before mutating:**
- Check `state.lock`
- If lock exists AND age <= 30 minutes AND holder is not your skill: STOP with lock info

**Acquire:**
- Set `lock: {"skill": "{name}", "since": "{ISO}"}` before other mutations

**Release:**
- Set `lock: null` after all mutations complete

**Stale locks:**
- Locks > 30 minutes may be auto-cleared with a warning

## Critical Rules

- **NEVER** partially update the file
- **ALWAYS** read full → modify → write full
- **NEVER** assume structure -- check fields after parse
- **ALWAYS** preserve existing fields not being modified
