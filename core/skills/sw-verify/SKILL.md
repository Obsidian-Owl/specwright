---
name: sw-verify
description: "Runs quality checks (build, tests, security, wiring, semantic, spec compliance) for the current work unit in dependency order and produces a pass/fail summary report. Use when the user asks to verify, validate, run checks, run quality gates, or confirm code is ready before shipping."
allowed-tools: "Read, Write, Bash, Glob, Grep, Task"
metadata:
  argument-hint: "[--gate=<name>]"
---

# Specwright Verify

## Goal

Run quality gates against the current work unit autonomously. Continue through
all gates regardless of individual failures. Present the aggregate report at the
gate handoff using `protocols/decision.md` template.

## Inputs

- `.specwright/state/workflow.json` -- current work unit, previous gate results
- `.specwright/config.json` -- gate configuration (object or array format)
- `{currentWork.workDir}/spec.md` -- for spec compliance gate
- Gate skill files in `skills/gate-*/SKILL.md`

## Outputs

- Evidence files in `{currentWork.workDir}/evidence/`, one per gate
- `workflow.json` gates section updated; status set to `verifying` during run
- Aggregate report presented at gate handoff

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Run quality gates and show findings. NEVER fix
code, create PRs, or ship. After gate handoff, STOP.

**Assumption re-validation (LOW freedom) — before gate execution:**
Scan `assumptions.md` from design-level directory. Check ACCEPTED/VERIFIED assumptions
still hold against current code. Invalid → WARN in aggregate report. Runs silently.

**Gate execution order (LOW freedom):**
Determine enabled gates from config. Two formats exist — support both:
- **Object format**: `config.gates.{gateName}` exists and `.enabled === true`
- **Array format**: gate name present in `config.gates.enabled` array

All six gates are eligible: build, tests, security, wiring, semantic, spec.
Execute enabled gates in dependency order: gate-build → gate-tests →
gate-security, gate-wiring → gate-semantic → gate-spec.
If `--gate=<name>` argument, run only that gate.
Load calibration notes per `protocols/gate-verdict.md`.

**Gate invocation (MEDIUM freedom):**
Gates are internal skills — load SKILL.md and execute inline. Pass work unit context.

**Freshness (LOW freedom):**
Always re-run all gates regardless of existing results or age.

**Failure handling (MEDIUM freedom):**
Gate FAIL or ERROR: continue. Run ALL remaining gates, record all results.
No fix/skip/abort decisions — the gate handoff presents everything for human review.
Headless: write `headless-result.json`.

**Aggregate report (MEDIUM freedom):**
After all gates, present: (1) per-finding detail grouped by gate, (2) summary table
`| Gate | Status | Findings (B/W/I) |`, (3) actionable findings table (WARN → fix
suggestion, BLOCK → "manual review"). SKIP gates prominently marked. Check escalation
heuristics per `protocols/gate-verdict.md`.

**Evidence completeness (LOW freedom):**
Skip when `--gate=<name>` was used (partial run — only the targeted gate is expected).
In full mode: check every enabled gate has a status in `workflow.json` `gates.{name}`.
No status and no evidence file → ERROR: "Gate {name} was enabled but produced no
evidence — gate was not executed."

**Gate handoff (LOW freedom):**
Present using `protocols/decision.md` gate handoff template. Auto-generate recommendation:
BLOCKs → "Fix and re-run `/sw-verify`." WARNs only → "Review, then `/sw-ship`."
All PASS → "Ready for `/sw-ship`." Human reviews and decides.

**State updates (LOW freedom):**
Follow `protocols/state.md`. Set status to `verifying` at start. Update `gates` section
after each gate completes. Do NOT set `shipped`.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework and gate handoff
- `protocols/state.md` -- workflow state and locking
- `protocols/evidence.md` -- evidence freshness and storage
- `protocols/gate-verdict.md` -- verdict rendering and escalation
- `protocols/headless.md` -- non-interactive execution defaults
- `protocols/context.md` -- config and anchor doc loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-design, /sw-plan, and /sw-build first." |
| No gates enabled / all skipped | WARN, proceed to ready-to-ship |
| Gate skill file not found | ERROR for that gate, continue remaining |
| Compaction during verification | Read workflow.json, resume from next gate without fresh results |
