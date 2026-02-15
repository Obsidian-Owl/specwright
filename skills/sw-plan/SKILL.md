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
- `.specwright/work/{id}/design.md` -- approved solution design (full intensity only)
- `.specwright/work/{id}/context.md` -- research findings from sw-design (all intensities)
- Conditional design artifacts: `decisions.md`, `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`
- `.specwright/CONSTITUTION.md` -- practices to follow
- `.specwright/config.json` -- project configuration

## Outputs

When complete, ALL of the following exist in `.specwright/work/{id}/`:

- `spec.md` -- acceptance criteria (each testable)
- `plan.md` -- task breakdown, file change map, architecture decisions

When the work is large, also:

- `workUnits` array populated in `workflow.json` per `protocols/state.md`
- Each unit with its own acceptance criteria section in spec.md

`context.md` may be appended with decomposition-specific context but the
design research content is never overwritten.

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
- Each has its own acceptance criteria section.
- Ordered by dependency (what must be built first).
- The user approves the decomposition.
- Write `workUnits` array to workflow.json per `protocols/state.md`.
- Present the expected cycle per unit:
  ```
  Unit 1: {name} → /sw-build → /sw-verify → /sw-ship
  Unit 2: {name} → /sw-build → /sw-verify → /sw-ship
  ```

**Spec (MEDIUM freedom):**
- Write acceptance criteria the tester can turn into brutal tests.
- Each criterion answers: "How will we KNOW this works?"
- Include boundary conditions and error cases, not just happy paths.
- If `.specwright/patterns.md` exists, check for patterns that should inform
  acceptance criteria (e.g., known edge cases, testing approaches that worked).
- Ground criteria in the design artifacts — reference specific decisions, contracts, data models.
- The user must approve the spec before it's saved.

**User checkpoints:**
- After decomposition (if large): approve unit breakdown.
- After spec: approve acceptance criteria.
- Use AskUserQuestion with options grounded in design artifacts.

**State mutations (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json updates.
- Transition `currentWork.status` from `designing` to `planning`.
- When decomposing: populate `workUnits` array, set first unit to `planning`.

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
| Compaction during planning | Read workflow.json, check which artifacts exist, resume |
