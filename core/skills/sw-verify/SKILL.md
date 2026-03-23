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

**Assumption re-validation (LOW freedom) — runs before gate execution:**
- Scan `assumptions.md` from the work unit's design-level directory (`.specwright/work/{currentWork.id}/assumptions.md`). If the file does not exist, skip this step silently.
- For each assumption with status ACCEPTED or VERIFIED: check whether it is still valid given the implementation (file contents, interfaces, behaviour).
- Any assumption that no longer holds becomes a WARN finding in the aggregate report, using the same findings table as gate results.
- This step runs silently — no new user interaction point. Findings appear in the existing aggregate report.

**Gate execution order (LOW freedom):**
- Read enabled gates from `config.json` `gates.enabled`. Skip any gate not in `gates.enabled` silently. Note: `gate-semantic` is disabled by default and must be explicitly enabled.
- Execute in dependency order:
  1. `gate-build` first (if code doesn't compile, nothing else matters)
  2. `gate-tests` second (requires build to pass)
  3. `gate-security`, `gate-wiring` (independent, can be either order)
  4. `gate-semantic`
  5. `gate-spec` last (the ultimate check)
- Before running gates, load calibration notes per `protocols/gate-verdict.md`.
- If `--gate=<name>` argument given, run only that gate.

**Gate invocation (MEDIUM freedom):**
- Gates are internal skills — load their SKILL.md and execute inline (not slash commands). Pass work unit context.

**Freshness (LOW freedom):**
- Check existing gate results in workflow.json before running.
- **Interactive**: If a gate result exists and is less than 30 minutes old, ask the user: re-run or keep?
- **Headless** (per `protocols/headless.md`): Re-run all gates regardless of age.
- If older than 30 minutes, re-run automatically (both modes).

**Failure handling (MEDIUM freedom):**
- If a gate returns FAIL or ERROR:
  - **Interactive**: Show findings immediately. Ask: fix now, skip this gate, or abort?
  - **Headless** (per `protocols/headless.md`): Continue and report. Run all remaining
    gates, record all results. Do not ask fix/skip/abort.
- If user chooses to fix (interactive), pause verification. Resume after fix.
- If user skips (interactive), record SKIP status for that gate.
- On headless completion: write `headless-result.json` with `status: "completed"`,
  aggregate `pass_rate`, and per-gate verdicts.

**Aggregate report (MEDIUM freedom):**
- After all gates, present three tiers:
  1. **Per-finding detail** (first): every BLOCK/WARN grouped by gate — what, why, recommended action.
  2. **Summary table** (after): `| Gate | Status | Findings (B/W/I) |`
  3. **Actionable Findings** (after summary): only shown when WARN or BLOCK findings exist; omit when all gates PASS. Populate from gate evidence as source. Include only WARN and BLOCK severity rows, not INFO.

     | # | Gate | Severity | File | Finding | Recommended Fix |
     |---|------|----------|------|---------|-----------------|
     | 1 | gate-tests | WARN | src/foo.ts | description | concrete fix suggestion or "manual review" |

     - File column: specific file path from gate evidence (not vague references).
     - Recommended Fix column: WARN rows get concrete, actionable fix suggestions; BLOCK rows that require human judgment get "manual review".
     - Summary line: state the count of actionable findings (N of M) and indicate whether any require human judgment before the user proceeds. Wording must remain informational — do not use imperative verbs that imply the skill will perform fixes.
     - All-manual case: when every finding requires manual review, note that no automated resolution is possible.
- SKIP gates MUST be prominently marked in the report. For each skipped gate, add an entry to the summary table with the note: "Gate {name} was SKIPPED — no evidence exists for this dimension."
- After all gates, check escalation heuristics per `protocols/gate-verdict.md`.
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
- `protocols/headless.md` -- non-interactive execution defaults
- `protocols/context.md` -- config and anchor doc loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-design, /sw-plan, and /sw-build first." |
| No gates enabled / all skipped | WARN, proceed to ready-to-ship |
| Gate skill file not found | ERROR for that gate, continue remaining |
| Compaction during verification | Read workflow.json, resume from next gate without fresh results |
