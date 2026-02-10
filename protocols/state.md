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
    "status": "planning | building | verifying | shipped | abandoned",
    "workDir": ".specwright/work/{id}",
    "tasksTotal": "number | null",
    "tasksCompleted": ["task-id strings"],
    "currentTask": "string | null"
  },
  "gates": {
    "{gate-name}": {
      "status": "PASS | FAIL | WARN | ERROR | SKIP",
      "lastRun": "ISO timestamp",
      "evidence": "path to evidence file",
      "findings": { "block": 0, "warn": 0, "info": 0 }
    }
  },
  "lock": {
    "skill": "string",
    "since": "ISO timestamp"
  },
  "lastUpdated": "ISO timestamp"
}
```

`currentWork` is null when no work is active. `lock` is null when unlocked.

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
