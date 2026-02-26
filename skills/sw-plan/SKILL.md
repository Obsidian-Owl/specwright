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
  - AskUserQuestion
---

# Specwright Plan

## Goal

Turn the approved design into implementation-ready specs with testable
acceptance criteria. If the work is large, decompose into ordered work
units. The user should feel confident every criterion is testable and
every unit is independently buildable.

## Inputs

- `.specwright/state/workflow.json` -- current state (must be `designing` or `planning`)
- `.specwright/work/{currentWork.id}/design.md` -- approved solution design (full intensity only)
- `.specwright/work/{currentWork.id}/context.md` -- research findings from sw-design (all intensities)
- Conditional design artifacts at `.specwright/work/{currentWork.id}/`: `decisions.md`, `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`
- `.specwright/CONSTITUTION.md` -- practices to follow
- `.specwright/config.json` -- project configuration

## Outputs

**Single-unit work** (not decomposed):

All of the following exist in `.specwright/work/{id}/` (flat layout, unchanged):

- `spec.md` -- acceptance criteria (each testable)
- `plan.md` -- task breakdown, file change map, architecture decisions

**Multi-unit work** (decomposed into 2+ units):

For each unit, the following exist in `.specwright/work/{id}/units/{unit-id}/`:

- `spec.md` -- unit-scoped acceptance criteria
- `plan.md` -- unit-scoped task breakdown, file change map
- `context.md` -- curated subset of parent context relevant to this unit

Also:
- `workUnits` array populated in `workflow.json` per `protocols/state.md`, each entry with `workDir` set
- No `spec.md` or `plan.md` at the work root — the `units/` directory is the multi-unit indicator

The parent `context.md` (design research) is never overwritten.

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You produce specs and plans. You NEVER write implementation code, create branches, run tests, or commit changes.
- After the user approves the spec, STOP and present the handoff to `/sw-build`.

**Pre-condition check (LOW freedom):**
- Check `currentWork.status` is `designing` or `planning`. If neither: "Run /sw-design first."
- If `currentWork.intensity` is `full` or absent: check `design.md` exists. If not: "Run /sw-design first."
- If `currentWork.intensity` is `lite`: check `context.md` exists. If not: "Run /sw-design first."

**Decompose (MEDIUM freedom, only if large):**
- Assess whether the design requires multiple work units.
- Each unit is independently buildable and testable.
- Ordered by dependency (what must be built first).
- If decomposition results in exactly 1 unit, use the single-unit flat layout (no `units/` directory, no `workUnits` array). Proceed to Spec constraint.
- Present the decomposition to the user. The user approves before any unit directories are created.
- After approval, populate `workUnits` array in workflow.json with all units at status `pending`, per `protocols/state.md`.
- Present the expected cycle per unit:
  ```
  Unit 1: {name} → /sw-build → /sw-verify → /sw-ship
  Unit 2: {name} → /sw-build → /sw-verify → /sw-ship
  ```
- Decomposition is complete when: each unit has a clear single purpose (describable in one sentence), dependencies are identified and ordered, each unit's spec has 3+ testable acceptance criteria, and an implementer could start any unit from its artifacts alone.

**Spec — single-unit (MEDIUM freedom):**
- Write acceptance criteria the tester can turn into brutal tests.
- Each criterion answers: "How will we KNOW this works?"
- Include boundary conditions and error cases, not just happy paths.
- If `.specwright/patterns.md` exists, check for patterns that should inform
  acceptance criteria (e.g., known edge cases, testing approaches that worked).
- Ground criteria in the design artifacts — reference specific decisions, contracts, data models.
- The user must approve the spec before it's saved.

**Spec — per-unit loop (MEDIUM freedom, multi-unit only):**
- For each unit (sequentially, in dependency order):
  1. Create directory: `.specwright/work/{id}/units/{unit-id}/`
  2. Write `context.md` — curated subset of parent context.md containing:
     - File paths and module boundaries relevant to this unit
     - Integration points this unit touches
     - Gotchas and patterns from the parent context that apply
     - Dependency notes (what other units this one builds on)
     - Relevant design excerpts summarized inline
     - The unit's context.md must be self-contained — an agent reading only the unit directory has sufficient context to build
  3. Write `plan.md` — task breakdown and file change map scoped to this unit
  4. Write `spec.md` — acceptance criteria scoped to this unit
  5. Present the spec to the user via AskUserQuestion for individual approval
  6. If the user requests changes, revise and re-present (loop until approved)
  7. After approval, update this unit's `workUnits` entry: status → `planned`, `workDir` set
- Criteria quality: same standards as single-unit (testable, boundary conditions, grounded in design).

**Code budget (MEDIUM freedom):**
- plan.md files contain structure, not implementation. Allowed: function/method signatures (no bodies), type/interface definitions, API endpoint contracts (method, path, request/response shapes), directory/file structure, configuration examples, CLI commands.
- NOT allowed: function implementations, algorithm logic, business rule code, full test implementations. The tester and executor receive the plan — keeping it focused gives them cleaner signal about *what* to build without biasing *how*.

**User checkpoints:**
- After decomposition (if large): approve unit breakdown before creating directories.
- After each unit's spec (multi-unit): approve acceptance criteria individually.
- After spec (single-unit): approve acceptance criteria.
- Use AskUserQuestion with options grounded in design artifacts.

**State mutations (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json updates.
- Transition `currentWork.status` from `designing` to `planning` at the start.
- Single-unit: transition to `planning`, no `workUnits` array. Handoff to `/sw-build`.
- Multi-unit: after all units approved:
  - Set `currentWork.unitId` to the first unit's ID
  - Set `currentWork.workDir` to the first unit's `workDir`
  - Set the first unit's `workUnits` entry status to `building`
  - Transition `currentWork.status` from `planning` to `building`
  - Reset the `gates` section to `{}`
  - Handoff to `/sw-build`

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/state.md` -- workflow state updates and locking
- `protocols/context.md` -- anchor doc and config loading
- `protocols/recovery.md` -- compaction recovery

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status not `designing`/`planning` | STOP: "Run /sw-design first" |
| Required artifact missing | STOP: "Run /sw-design first" (design.md for full, context.md for lite) |
| Design too vague for specs | Ask user for clarification with concrete options |
| Active work already in progress | Ask user: continue existing, or start new? |
| Compaction during planning | Read workflow.json. Check `workUnits` entries: skip `planned` units, resume from first `pending` unit. If a `pending` unit has partially written artifacts (spec.md exists), re-present to user for approval. |
| Decomposition revision after partial approval | Partial teardown not supported. User must `/sw-status --reset` and re-run `/sw-plan`. |
