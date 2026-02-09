---
name: validate
description: >-
  Quality gates orchestrator. Runs enabled gate skills sequentially with evidence
  management, freshness checks, and pipeline locking.
argument-hint: "[--gate=<name>] [--no-stop-on-failure] [--unlock]"
allowed-tools:
  - Skill
  - Bash
  - Read
  - Write
---

# Specwright Validate: Quality Gates Orchestrator

Runs all enabled validation gates sequentially with evidence management and freshness checks.

## Arguments

Parse `$ARGUMENTS` for:
- `--gate=<name>` — Run only a specific gate (e.g., `--gate=build`)
- `--no-stop-on-failure` — Continue running gates even if one fails
- `--unlock` — Force-clear a stuck pipeline lock

## Steps

### 1. Read Configuration
Read `.specwright/config.json` to get:
- `gates.enabled` — list of enabled gates (e.g., ["build", "tests", "wiring", "security"])
- Note: "spec" (spec compliance) gate is always enabled regardless of config

### 2. Read Workflow State
Read `.specwright/state/workflow.json` to get current epic context and gate status.
If no active epic: STOP with "No active epic. Run /specwright:specify first."

### 3. Handle Force Unlock
If `--unlock` flag present:
- Clear the `lock` field in workflow.json
- Output "Pipeline lock cleared"
- Exit

### 4. Check Pipeline Lock
If `lock` field exists in workflow.json:
- Calculate lock age from `lock.since` timestamp
- If age > 30 minutes: auto-clear stale lock, log warning
- If age <= 30 minutes: STOP with "Pipeline locked by {lock.skill} since {lock.since}. Use --unlock to force-clear."

### 5. Acquire Pipeline Lock
Set `lock: {"skill": "validate", "since": "<ISO-timestamp>"}` in workflow.json.

### 6. Check Evidence Freshness
For each gate in the `gates` object of workflow.json:
- If gate has `lastRun` timestamp older than 5 minutes, mark as stale
- If `--gate=<name>` specified, only check that gate
- Log which gates need re-run due to stale evidence

### 7. Run Gates Sequentially

Determine which gates to run:
- If `--gate=<name>` specified: run ONLY that gate
- Otherwise: run all enabled gates from config + always include "spec"

For each gate in order [review, build, tests, wiring, security, spec], perform the following sequence:

1. Invoke the gate skill using Skill tool: `skill: "gate-{gateName}"` (e.g., `gate-build`, `gate-tests`)
2. After completion, read `.specwright/state/workflow.json` and check `gates.{gateName}.status`
3. Handle result:
   - Status `"FAIL"` + no `--no-stop-on-failure` flag: release lock, report failure, STOP
   - Status `"PASS"`: proceed to next gate
   - Skill not found or invocation failure: mark as `"ERROR"`, log issue, continue only if `--no-stop-on-failure` set

Note: Skip gates not in the enabled list (except "spec" which always runs).

### 8. Compile Evidence Report
Read all gate results from workflow.json:
- Extract status (PASS/FAIL/SKIP) for each gate
- Extract evidence paths from gate results
- Calculate overall: PASS if all gates PASS, otherwise FAIL

### 9. Release Pipeline Lock
Clear the `lock` field in workflow.json.

### 10. Update Timestamp
Set `lastUpdated` to current ISO timestamp in workflow.json.

### 11. Report Results

Output structured summary:
```
=== VALIDATION RESULTS ===
Gate: review   [PASS/FAIL/ERROR/SKIP]  Evidence: {path}  Last Run: {timestamp}
Gate: build    [PASS/FAIL/ERROR/SKIP]  Evidence: {path}  Last Run: {timestamp}
Gate: tests    [PASS/FAIL/ERROR/SKIP]  Evidence: {path}  Last Run: {timestamp}
Gate: wiring   [PASS/FAIL/ERROR/SKIP]  Evidence: {path}  Last Run: {timestamp}
Gate: security [PASS/FAIL/ERROR/SKIP]  Evidence: {path}  Last Run: {timestamp}
Gate: spec     [PASS/FAIL/ERROR/SKIP]  Evidence: {path}  Last Run: {timestamp}

Overall: PASS/FAIL
```

Only show gates that are enabled. Mark disabled gates as SKIP.

## Compaction Recovery

If compaction occurs during validation:
1. Read `.specwright/state/workflow.json` — check lock and gate status
2. If lock exists with skill "validate": resume from where gates left off
3. If some gates have fresh results: skip those, run remaining

## Error Handling

| Error | Action |
|-------|--------|
| No active epic | "No active epic. Run /specwright:specify first." |
| Config missing | "Run /specwright:init first." |
| Gate skill not found/fails to invoke | Mark gate as ERROR (distinct from FAIL), log error, continue if --no-stop-on-failure |
| Lock conflict | Show lock info, suggest --unlock |

## Notes

- Pipeline lock prevents concurrent validation runs
- 5-minute evidence freshness ensures current results
- Single-gate mode (--gate=) is useful for rapid iteration
- Stale locks auto-clear after 30 minutes
