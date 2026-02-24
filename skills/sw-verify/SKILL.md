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
- `{currentWork.workDir}/spec.md` -- for spec compliance gate
- Gate skill files in `skills/gate-*/SKILL.md`

## Outputs

- Evidence files in `{currentWork.workDir}/evidence/`, one per gate
- `workflow.json` gates section updated; status set to `verifying` during run
- Aggregate summary shown to user with all findings

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You run quality gates and show findings. You NEVER fix code, create PRs, or ship.
- After showing the aggregate report, STOP and present the handoff using
  the three-tier posture defined in the aggregate report constraint below.

**Gate execution order (LOW freedom):**
- Read `currentWork.intensity` from workflow.json (default `"full"` if absent). If `"quick"`, run only `gate-spec` (and `gate-build` if `config.commands.build` exists). Otherwise run all enabled gates.
- Read enabled gates from `config.json` `gates.enabled`.
- Execute in dependency order:
  1. `gate-build` first (if code doesn't compile, nothing else matters)
  2. `gate-tests` second (requires build to pass)
  3. `gate-security`, `gate-wiring` (independent, can be either order)
  4. `gate-spec` last (the ultimate check)
- If `--gate=<name>` argument given, run only that gate.

**Gate invocation (MEDIUM freedom):**
- Gates are internal skills — load their SKILL.md and execute inline (not slash commands). Pass work unit context.

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
- After all gates, present two tiers:
  1. **Per-finding detail** (first): every BLOCK/WARN grouped by gate — what, why, recommended action.
  2. **Summary table** (after): `| Gate | Status | Findings (B/W/I) |`
- Handoff: BLOCKs → "Fix and re-run `/sw-verify`." WARNs only → "Review, then fix or `/sw-ship`." All PASS → "Ready for `/sw-ship`."

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
| No active work unit | STOP: "Run /sw-design, /sw-plan, and /sw-build first." |
| No gates enabled / all skipped | WARN, proceed to ready-to-ship |
| Gate skill file not found | ERROR for that gate, continue remaining |
| Compaction during verification | Read workflow.json, resume from next gate without fresh results |
