---
name: sw-status
description: >-
  Shows current Specwright state — active work unit, task progress, gate
  results, and lock status. Supports --reset to abandon work in progress.
argument-hint: "[--reset]"
allowed-tools:
  - Read
  - Write
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

## Constraints

**Display (HIGH freedom):**
- Read workflow.json and format it clearly for the user.
- Show gate results with freshness (e.g., "PASS (12 min ago)").
- If no active work: say so and suggest `/sw-plan`.
- If work is complete: suggest `/sw-ship`.
- Be concise. This is a dashboard, not a report.

**Reset mode (LOW freedom):**
- If `--reset` argument is given:
  - Confirm with user: "This will abandon work unit '{id}'. Are you sure?"
  - If confirmed: set `currentWork.status` to `abandoned`, release lock, clear gates.
  - Follow `protocols/state.md` for mutations.
  - Do NOT delete work directory — keep artifacts for reference.

## Protocol References

- `protocols/state.md` -- workflow state reading and reset mutations
- `protocols/context.md` -- config loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| workflow.json doesn't exist | "Specwright not initialized. Run /sw-init" |
| workflow.json parse error | Show raw error. Suggest manual fix or re-init. |
| Stale lock detected (>30 min) | Offer to auto-clear with warning |
