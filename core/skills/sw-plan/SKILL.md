---
name: sw-plan
description: >-
  Breaks a design into work units with testable specs. Reads design
  artifacts from sw-design and produces implementation-ready plans.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
---

# Specwright Plan

## Goal

Turn the approved design into implementation-ready specs with testable acceptance
criteria. Decompose into ordered work units if large. Operates autonomously,
applying `protocols/decision.md` for all decisions. Gate handoff at the end.

## Inputs

- `.specwright/state/workflow.json` -- current state (must be `designing` or `planning`)
- `.specwright/work/{currentWork.id}/design.md` -- approved solution design
- `.specwright/work/{currentWork.id}/context.md` -- research findings from sw-design
- `.specwright/work/{currentWork.id}/decisions.md` -- design-phase decisions
- Conditional design artifacts: `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`
- `.specwright/CONSTITUTION.md` -- practices to follow
- `.specwright/config.json` -- project configuration

## Outputs

**Single-unit work**: `spec.md` + `plan.md` in `.specwright/work/{id}/` (flat layout).

**Multi-unit work**: For each unit in `.specwright/work/{id}/units/{unit-id}/`:
`spec.md` + `plan.md` + `context.md`. `workUnits` array in workflow.json.
Also: `integration-criteria.md` in the design-level directory (`.specwright/work/{id}/`).

Also: `decisions.md` updated with planning-phase autonomous decisions.

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Produce specs and plans. NEVER implement, branch,
test, or commit. After gate handoff, STOP.

**Pre-condition check (LOW freedom):**
Check `currentWork.status` is `designing` or `planning` and `design.md` exists.

**Decompose (MEDIUM freedom, only if large):**
- Assess whether the design requires multiple work units. Apply autonomously — use
  design blast radius to determine boundaries. High-blast-radius (systemic) components
  get their own unit.
- Each unit: independently buildable, testable, single purpose, 3+ testable ACs.
- Ordered by dependency. If exactly 1 unit, use flat layout.
- Record decomposition rationale in decisions.md per `protocols/decision.md` DISAMBIGUATION.

**Integration criteria (MEDIUM freedom, multi-unit only):**
- When decomposing into multiple work units, also write `integration-criteria.md` in
  the design-level directory (`.specwright/work/{currentWork.id}/`). Not generated for
  single-unit work.
- Two IC types coexist in `integration-criteria.md`: structural (IC-{n}) and behavioral
  (IC-B{n}). Both types go to the same file.
- **Structural ICs (IC-{n}):** Each structural IC must be structurally verifiable —
  reference specific module paths, export names, or import relationships.
  Example (valid): "Module `src/routes/index.ts` imports handler from
  `src/handlers/payment.ts`". Example (invalid): "The payment feature works
  end-to-end" (too abstract — use a spec AC instead).
  Format: `- [ ] IC-{n}: {assertion with file paths or export names}`.
- **Behavioral ICs (IC-B{n}):** Reference observable outputs — return values, state
  changes, or emitted events — that are only verifiable when multiple units interact.
  Example (valid): `- [ ] IC-B1: calling checkout() returns an order ID after the
  payment and inventory units are both active`.
  Format: `- [ ] IC-B{n}: {assertion referencing observable outputs}`.
  spec-review validates IC-B quality: each behavioral IC must name a concrete observable,
  not restate implementation intent.
- ICs are derived from the design's integration points and blast radius. They answer:
  "After all units are built, what structural connections must exist, and what observable
  behaviors must hold?"
- On re-entry to sw-plan (replanning), overwrite `integration-criteria.md` with freshly
  generated criteria (same behavior as spec.md/plan.md regeneration). If replanning
  reduces from multi-unit to single-unit, delete `integration-criteria.md` if it exists.
- Consumed by gate-wiring during the final unit's verification.
- If sw-pivot changes unit boundaries mid-build, `integration-criteria.md` may become
  stale. sw-pivot should regenerate ICs when unit boundaries change. If it does not,
  gate-wiring will WARN on unverifiable ICs rather than false-PASS.

**Spec writing (MEDIUM freedom):**
- Write acceptance criteria the tester can turn into brutal tests. Each answers:
  "How will we KNOW this works?" Include boundary conditions and error cases.
- Check patterns.md for known edge cases.
- Follow `protocols/assumptions.md` late discovery lifecycle. Auto-resolve per Type 1/2
  rules in the assumptions protocol.
- Ground criteria in design artifacts.
- For each AC that crosses a boundary classified in TESTING.md, add a `[tier: X]`
  annotation. Tier classification rules are defined in `protocols/testing-strategy.md`
  — apply them declaratively; do not reproduce them here.

**Spec per-unit loop (MEDIUM freedom, multi-unit only):**
For each unit sequentially: create directory, write context.md (self-contained),
plan.md (task breakdown + file change map), spec.md (unit-scoped ACs). Each unit's
context.md must be sufficient for an agent reading only that directory.

**Spec pre-review (MEDIUM freedom):**
- After drafting each spec, delegate to `specwright-architect` per `protocols/spec-review.md`.
- Auto-revise BLOCKs (up to 2 iterations). Document WARNs in spec.md.
- If BLOCKs persist after 2 revisions: Type 1 deficiency — record and surface at gate.

**Code budget (MEDIUM freedom):**
plan.md contains structure, not implementation. Allowed: signatures, types, contracts,
directory structure, config examples. NOT allowed: function bodies, algorithm logic.

**Gate handoff (LOW freedom):**
Present the gate using `protocols/decision.md` gate handoff template: artifact (spec.md
for all units), decision digest, quality checks (spec-review results), deficiencies,
recommendation. The user reviews and approves before `/sw-build` begins.

**State mutations (LOW freedom):**
Follow `protocols/state.md`. Transition `designing` → `planning`. Multi-unit: populate
workUnits array, set first unit to `building`, transition to `building`, handoff to
`/sw-build`.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework and gate handoff
- `protocols/state.md` -- workflow state updates and locking
- `protocols/context.md` -- anchor doc and config loading
- `protocols/recovery.md` -- compaction recovery
- `protocols/assumptions.md` -- late assumption capture and autonomous resolution
- `protocols/spec-review.md` -- spec quality review
- `protocols/testing-strategy.md` -- tier tagging for ACs crossing TESTING.md boundaries

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status not `designing`/`planning` | STOP: "Run /sw-design first" |
| Required artifact missing | STOP: "Run /sw-design first" |
| Design too vague for specs | Apply DISAMBIGUATION from design context. Record interpretation. Surface at gate if undetermined. |
| Active work in progress | Apply DISAMBIGUATION: argument provided → start new. No argument → continue. Record. |
| Compaction during planning | Read workflow.json. Skip `planned` units, resume first `pending`. |
| Decomposition revision needed | `/sw-status --reset` and re-run `/sw-plan`. |
