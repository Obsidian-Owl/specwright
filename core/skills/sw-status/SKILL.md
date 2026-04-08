---
name: sw-status
description: >-
  Shows current Specwright state — active work unit, task progress, gate
  results, and lock status. Supports --reset to abandon work, --cleanup
  to remove orphaned work directories, and --repair {unitId} to repair
  shipped-unit PR metadata drift.
argument-hint: "[--reset | --cleanup | --repair {unitId}]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - AskUserQuestion
---

# Specwright Status

## Goal

Tell the user where they are. What's in progress, what's done, what's
next. If they're stuck, give them a way out with `--reset`.

## Inputs

- `.specwright/state/workflow.json` -- all state
- `.specwright/config.json` -- project info
- `.specwright/work/` -- work unit directories

## Outputs

- Formatted status display showing:
  - Current work unit (if any): ID, description, status
  - Task progress: completed/total
  - Gate results: status per gate, freshness
  - Lock status: who holds it, how long
  - Next action recommendation
- In `--repair` mode: remediation outcome (`repaired`, `report-only`, or
  user-selected fallback) for the target unit

## Constraints

**Display (HIGH freedom):**
- Read workflow.json and format it clearly for the user.
- Show gate results with freshness (e.g., "PASS (12 min ago)").
- If `currentWork.unitId` is present, show the active unit ID in the current work display.
- If `workUnits` array exists, show the full queue with `workDir` paths:
  ```
  Work Units:
    1. [SHIPPED] stage-boundary-enforcement (.specwright/work/{id}/units/stage-boundary-enforcement/)
    2. [BUILDING] git-operations-overhaul (.specwright/work/{id}/units/git-operations-overhaul/)  ← current
    3. [PLANNED] state-enhancements (.specwright/work/{id}/units/state-enhancements/)
    4. [PENDING] final-cleanup (.specwright/work/{id}/units/final-cleanup/)
  ```
- If no active work: say so and suggest `/sw-design`.
- If work is complete: suggest `/sw-ship`.
- Be concise. This is a dashboard, not a report.

**Non-interactive context (LOW freedom):**
- Follow `protocols/headless.md` when AskUserQuestion is unavailable.
- `--reset`: **abort** without confirming (do not reset without explicit human confirmation).
  Write `headless-result.json` with `status: "aborted"`, `error: "reset requires confirmation"`.
- `--cleanup`: **report-only** — list orphaned directories but do not delete any.
  Output the list so the calling system can process it.
- `--repair`: **report-only** — inspect the target unit, print what interactive
  repair would do, suggest rerunning `sw-status --repair {unitId}` interactively,
  and never mutate workflow.json.
- Default display mode (no flags): already headless-safe — reads state and formats output.
- Write `headless-result.json` with `status: "completed"`, `pass_rate: null`.

**Reset mode (LOW freedom):**
- If `--reset` argument is given:
  - Confirm with user: "This will abandon work unit '{id}'. Are you sure?"
  - If confirmed: set `currentWork.status` to `abandoned`, release lock, clear gates.
  - Follow `protocols/state.md` for mutations.
  - Do NOT delete work directory — keep artifacts for reference.

**Cleanup mode (MEDIUM freedom):**
- If `--cleanup` argument is given:
  - Scan `.specwright/work/` for subdirectories.
  - If `.specwright/work/` does not exist or contains no subdirectories: report "No work directories found" and exit without prompting.
  - Determine which directories are **active** (not deletable):
    - If `currentWork` is non-null: the directory `.specwright/work/{currentWork.id}/` is active (not deletable).
    - If `currentWork` is null: no directories are active — all are eligible for cleanup.
  - Present the directory list to the user via AskUserQuestion with multiSelect:
    - Active directories are displayed as "(active — not deletable)" and excluded from selection options.
    - Non-active directories are selectable for deletion.
  - Before deleting, use `realpath` to canonicalize each selected path, then verify the canonical path is a direct child of the canonical `.specwright/work/` path. If canonicalization fails or the resolved path escapes `.specwright/work/`, skip it with a warning.
  - Delete only the verified, user-selected directories (`rm -rf` each selected path).
  - Report which directories were deleted and the count.

**Repair mode (MEDIUM freedom):**
- If `--repair {unitId}` argument is given:
  - Locate the matching `workUnits[{n}]` entry. If absent: report "Unknown unitId".
  - Repair applies only to `status=shipped` and `prNumber=null`.
  - If `gh` confirms a merged PR for that unit: populate `prNumber` and
    `prMergedAt` (when known), report `repaired`, and leave `status=shipped`.
    In short: merged PR confirmed → repaired.
  - If no PR can be proven, ask the user to choose one of exactly three options:
    1. `revert-to-building`
    2. `mark-abandoned`
    3. `force-shipped-with-note`
  - `revert-to-building`: set the unit and `currentWork` back to `building`
    when the repaired unit is the active one.
  - `mark-abandoned`: set the unit status to `abandoned` and record that no PR
    was confirmed.
  - `force-shipped-with-note`: keep `status=shipped`, keep `prNumber=null`, and
    append a note to `{workDir}/decisions.md` recording the user's assertion that
    the work shipped via an out-of-band path.
  - All workflow.json mutations follow `protocols/state.md`.

## Protocol References

- `protocols/state.md` -- workflow state reading and reset mutations
- `protocols/context.md` -- config loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| workflow.json doesn't exist | "Specwright not initialized. Run /sw-init" |
| workflow.json parse error | Show raw error. Suggest manual fix or re-init. |
| Stale lock detected (>30 min) | Offer to auto-clear with warning |
