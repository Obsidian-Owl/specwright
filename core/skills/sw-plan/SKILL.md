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

- `{worktreeStateRoot}/session.json` -- selected work for this worktree
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- selected work state
- `{workArtifactsRoot}/{selectedWork.id}/design.md` -- approved solution design
- `{workArtifactsRoot}/{selectedWork.id}/context.md` -- research findings from sw-design
- `{workArtifactsRoot}/{selectedWork.id}/decisions.md` -- design-phase decisions
- Conditional design artifacts: `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`
- `{projectArtifactsRoot}/CONSTITUTION.md` -- practices to follow
- `{projectArtifactsRoot}/config.json` -- project configuration

## Outputs

**Single-unit work**: `spec.md` + `plan.md` in `{workArtifactsRoot}/{selectedWork.id}/` (flat layout).

**Multi-unit work**: For each unit in `{workArtifactsRoot}/{selectedWork.id}/units/{unit-id}/`:
`spec.md` + `plan.md` + `context.md`. `workUnits` array in workflow.json.
Also: `integration-criteria.md` in the design-level directory (`{workArtifactsRoot}/{selectedWork.id}/`).

Also: `{repoStateRoot}/work/{selectedWork.id}/stage-report.md` for the planning handoff.

Also: `decisions.md` updated with planning-phase autonomous decisions.

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Produce specs and plans. NEVER implement, branch,
test, or commit. After gate handoff, STOP.

**Pre-condition check (LOW freedom):**
Resolve the selected work from the current worktree session. Check that
`selectedWork.status` is `designing` or `planning` and `design.md` exists.
`sw-plan` operates on the current worktree's attached work only.
If another live top-level worktree owns that selected work, STOP and require
explicit `/sw-adopt` guidance before mutating specs or plans here. Matching the
recorded branch alone must not imply takeover.

**Design approval capture (LOW freedom) — on entry:**
Use `protocols/approvals.md` and the shared helper to record the current design
artifact set in `{workArtifactsRoot}/{selectedWork.id}/approvals.md`.
Interactive `/sw-plan` runs may write an `APPROVED` `design` entry with source
classification `command`; headless runs must validate existing human approval
instead of fabricating one.

**Decompose (MEDIUM freedom, only if large):**
- Assess whether the design requires multiple work units. Apply autonomously — use
  design blast radius to determine boundaries. High-blast-radius (systemic) components
  get their own unit.
- Each unit: independently buildable, testable, single purpose, 3+ testable ACs.
- Ordered by dependency. If exactly 1 unit, use flat layout.
- When mutable concurrency would otherwise require multiple top-level worktrees
  on one active workflow, split the effort into separate works and define
  integration criteria between them instead of sharing one mutable workflow.
- Record decomposition rationale in decisions.md per `protocols/decision.md` DISAMBIGUATION.
- On re-entry to `sw-plan` after a structural pivot or decomposition revision,
  regenerate only the affected remaining-unit artifact set. Overwrite each
  affected remaining unit's `spec.md`, `plan.md`, and `context.md`, but keep
  shipped units as immutable baseline scope rather than rewriting their
  artifacts or acceptance history.

**Integration criteria (MEDIUM freedom, multi-unit only):**
- When decomposing into multiple work units, also write `integration-criteria.md` in
  the design-level directory (`{workArtifactsRoot}/{selectedWork.id}/`). Not generated for
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
- On re-entry to `sw-plan` (replanning), regenerate `integration-criteria.md`
  for the affected remaining units only. This uses
  the same overwrite behavior as regenerated unit `spec.md` / `plan.md` /
  `context.md` artifacts while preserving shipped units as immutable baseline
  scope. If replanning reduces the remaining work to single-unit, delete
  `integration-criteria.md` if it exists.
- Consumed by gate-wiring during the final unit's verification.
- If sw-pivot changes unit boundaries mid-build, `integration-criteria.md` may become
  stale. sw-pivot should regenerate ICs when unit boundaries change. If it does not,
  gate-wiring will WARN on unverifiable ICs rather than false-PASS.

**Spec writing (MEDIUM freedom):**
- Write acceptance criteria the tester can turn into brutal tests. Each answers:
  "How will we KNOW this works?" Include boundary conditions and error cases.
- Check patterns.md for known edge cases.
- Follow `protocols/decision.md#late-discovery-lifecycle`. Auto-resolve per the
  Type 1/2 rules in `protocols/decision.md#autonomous-resolution`.
- Ground criteria in design artifacts.
- For each AC that crosses a boundary classified in TESTING.md, add a `[tier: X]`
  annotation. Tier classification rules are defined in `protocols/testing-strategy.md`
  — apply them declaratively; do not reproduce them here.

**Spec per-unit loop (MEDIUM freedom, multi-unit only):**
For each unit sequentially: create directory, write context.md (self-contained),
plan.md (task breakdown + file change map), spec.md (unit-scoped ACs). Each unit's
context.md must be sufficient for an agent reading only that directory.
If the remaining work truly needs mutable concurrency, stop decomposing it into
one shared workflow and instead create separate works with explicit
integration criteria.

**Spec pre-review (MEDIUM freedom):**
- After drafting each spec, delegate to `specwright-architect` per `protocols/spec-review.md`.
- Auto-revise BLOCKs (up to 2 iterations). Document WARNs in spec.md.
- If BLOCKs persist after 2 revisions: Type 1 deficiency — record and surface at gate.

**Code budget (MEDIUM freedom):**
plan.md contains structure, not implementation. Allowed: signatures, types, contracts,
directory structure, config examples. NOT allowed: function bodies, algorithm logic.

**Gate handoff (LOW freedom):**
On completion, emit the three-line handoff per the `protocols/decision.md`
Gate Handoff section. Write `{repoStateRoot}/work/{selectedWork.id}/stage-report.md`
before the handoff. The Artifacts line points at
`Artifacts: {repoStateRoot}/work/{selectedWork.id}/stage-report.md`. Detail
lives in the auditable artifact files under
`{workArtifactsRoot}/{selectedWork.id}/` (`spec.md` / `plan.md` / `context.md`
for each unit, `integration-criteria.md` for multi-unit work). The Next line
remains machine-parseable: `Next: /sw-build`.

**State mutations (LOW freedom):**
Follow `protocols/state.md`. Mutate only the selected work's `workflow.json` and
the current worktree's `session.json`. Transition `designing` → `planning`.
- Preserve the selected work's recorded `targetRef` and freshness metadata in
  the selected work state and in any regenerated remaining-unit context that
  depends on them. Replanning must not silently clear, downgrade, or rewrite
  the recorded target or freshness policy when regenerating open work.
- Do not collapse back to inferring a single `baseBranch` target.

Multi-unit: populate the selected work's `workUnits` array, set the first unit
to `building`, transition the selected work to `building`, and hand off to
`/sw-build`. Do not clear or retarget unrelated active works owned by other
top-level worktrees.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework, gate handoff, late assumption capture and autonomous resolution
- `protocols/state.md` -- workflow state updates and locking
- `protocols/context.md` -- anchor doc and config loading
- `protocols/recovery.md` -- compaction recovery
- `protocols/approvals.md` -- design approval capture and validation
- `protocols/headless.md` -- non-interactive approval behavior
- `protocols/spec-review.md` -- spec quality review
- `protocols/testing-strategy.md` -- tier tagging for ACs crossing TESTING.md boundaries

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status not `designing`/`planning` | STOP: "Run /sw-design first" |
| Required artifact missing | STOP: "Run /sw-design first" |
| Selected work owned by another live top-level worktree | STOP with explicit `/sw-adopt` guidance |
| Design too vague for specs | Apply DISAMBIGUATION from design context. Record interpretation. Surface at gate if undetermined. |
| Active work in progress | Continue planning the current work. sw-plan always operates on existing design artifacts — it has no "start new" path. |
| Compaction during planning | Read workflow.json. Skip `planned` units, resume first `pending`. |
| Decomposition revision needed | `/sw-status --reset` and re-run `/sw-plan`. |
