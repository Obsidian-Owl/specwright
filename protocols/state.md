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
    "status": "designing | planning | building | verifying | shipped | abandoned",
    "workDir": ".specwright/work/{id}",
    "unitId": "string | null",
    "tasksTotal": "number | null",
    "tasksCompleted": ["task-id strings"],
    "currentTask": "string | null",
    "intensity": "full | lite | quick (optional, defaults to full)"
  },
  "gates": {
    "{gate-name}": {
      "status": "PASS | FAIL | WARN | ERROR | SKIP",
      "lastRun": "ISO timestamp",
      "evidence": "path to evidence file",
      "findings": { "block": 0, "warn": 0, "info": 0 }
    }
  },
  "workUnits": [
    { "id": "string", "description": "string", "status": "pending | planned | building | verifying | shipped | abandoned", "order": "number", "workDir": "string" }
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

`workUnits` entry statuses: `pending` (not yet planned), `planned` (spec written and approved, waiting to be activated), `building`/`verifying`/`shipped`/`abandoned` (same as currentWork). The `planned` status is set by sw-plan after a unit's spec is individually approved. Each entry's `workDir` is the artifact directory path for that unit (source of truth — skills read this field, never construct paths from id).

## State Transitions

Valid transitions for `currentWork.status`:

| From | To | Triggered by |
|------|----|-------------|
| (none) | `designing` | sw-design (new work) |
| `designing` | `planning` | sw-plan |
| `designing` | `building` | sw-design (Quick intensity only) |
| `planning` | `building` | sw-build |
| `building` | `verifying` | sw-verify |
| `verifying` | `building` | fix after failed verify |
| `verifying` | `shipped` | sw-ship |
| `shipped` | `planning` | next unit advancement |
| any | `abandoned` | sw-status --reset |

**Enforcement:** Skills MUST check `currentWork.status` before mutating. If the current status is not a valid "from" state for the intended transition, STOP with:
> "Cannot transition from {current} to {target}. Run /sw-{correct-skill} instead."

The `designing → building` transition is only valid when `currentWork.intensity` is `"quick"`.

When `workUnits` exists, also update the matching entry's status in the array.

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
