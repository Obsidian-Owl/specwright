---
name: sw-verify
description: >-
  Orchestrates quality gates for the current work unit. Runs enabled gates
  in dependency order, shows findings interactively, produces an aggregate
  evidence report.
argument-hint: "[--gate=<name>]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Specwright Verify

## Goal

Run quality gates against the current work unit and show the user what
was found. The user should see every finding, understand why it matters,
and be able to discuss or override before proceeding to ship.

## Inputs

- `.specwright/state/workflow.json` -- current work unit, previous gate results
- `.specwright/config.json` -- `gates.enabled` list
- `.specwright/work/{id}/spec.md` -- for spec compliance gate
- Gate skill files in `skills/gate-*/SKILL.md`

## Outputs

- Each gate produces its own evidence file in `.specwright/work/{id}/evidence/`
- `workflow.json` gates section updated with status per gate
- Aggregate summary shown to user with all findings across all gates
- `workflow.json` currentWork status set to `verifying` during run

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You run quality gates and show findings. You NEVER fix code, create PRs, or ship.
- After showing the aggregate report, STOP and present the handoff using
  the three-tier posture defined in the aggregate report constraint below.

**Gate execution order (LOW freedom):**
- Read enabled gates from `config.json` `gates.enabled`.
- Execute in dependency order:
  1. `gate-build` first (if code doesn't compile, nothing else matters)
  2. `gate-tests` second (requires build to pass)
  3. `gate-security`, `gate-wiring` (independent, can be either order)
  4. `gate-spec` last (the ultimate check)
- If `--gate=<name>` argument given, run only that gate.

**Gate invocation (MEDIUM freedom):**
- Load each gate's SKILL.md and follow its instructions.
- Gates are internal skills — read their SKILL.md and execute inline, don't try to invoke them as slash commands.
- Pass the current work unit context to each gate.

**Freshness (LOW freedom):**
- Check existing gate results in workflow.json before running.
- If a gate result exists and is less than 30 minutes old, ask the user: re-run or keep?
- If older than 30 minutes, re-run automatically.

**Failure handling (MEDIUM freedom):**
- If a gate returns FAIL or ERROR, show findings to the user immediately.
- Ask: fix now, skip this gate, or abort verification?
- If user chooses to fix, pause verification. Resume after fix.
- If user skips, record SKIP status for that gate.

**Aggregate report (MEDIUM freedom):**
- After all gates run, present findings in two tiers:

  **Tier 1 — Per-finding detail** (shown FIRST):
  For every BLOCK and WARN finding across all gates:
  - What was found (specific location, pattern, or gap)
  - Why it matters (impact on users, security, correctness, or maintainability)
  - Recommended action (specific, not generic)
  Group by gate. Show the full picture before any summary.

  **Tier 2 — Summary table** (shown AFTER detail):
  | Gate | Status | Findings (B/W/I) |
  |------|--------|-------------------|

- Handoff posture:
  - Any BLOCK findings: "These issues must be resolved before shipping. Fix
    and re-run `/sw-verify`." Do NOT mention `/sw-ship`.
  - WARN findings only (no BLOCKs): "These warnings deserve attention. Review
    each one — then decide whether to fix or proceed to `/sw-ship`."
  - All PASS, no warnings: "All gates passed. Ready to ship with `/sw-ship`."

**State updates (LOW freedom):**
- Follow `protocols/state.md`.
- Set `currentWork.status` to `verifying` at start.
- Update `gates` section after each gate completes.
- Do NOT change status to `shipped` — that's the ship skill's job.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/state.md` -- workflow state and locking
- `protocols/evidence.md` -- evidence freshness and storage
- `protocols/gate-verdict.md` -- verdict rendering
- `protocols/context.md` -- config and anchor doc loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Nothing to verify. Run /sw-design, /sw-plan, and /sw-build first." |
| No gates enabled in config | WARN and skip to ready-to-ship state |
| Gate skill file not found | ERROR for that gate, continue with remaining gates |
| All gates skipped by user | WARN: "All gates skipped. Proceed at own risk." |
| Compaction during verification | Read workflow.json, check which gates have fresh results, resume from next gate |
