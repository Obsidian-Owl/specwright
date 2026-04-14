---
name: sw-design
description: >-
  Autonomous solution architecture. Researches the codebase, designs a
  solution, challenges it adversarially, and produces design artifacts.
argument-hint: "[what you want to build or change]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Task
---

# Specwright Design

## Goal

Research the codebase, design a solution, challenge it adversarially, and produce
design artifacts. Output is a design — not specs, not code. Operates autonomously
between research and gate handoff, applying `protocols/decision.md` for all decisions.

## Inputs

- The user's request (argument or conversation)
- `{repoStateRoot}/CONSTITUTION.md` -- practices to follow
- `{repoStateRoot}/CHARTER.md` -- vision and invariants
- `{repoStateRoot}/config.json` -- project configuration
- `{worktreeStateRoot}/session.json` -- current worktree attachment, when present
- `{repoStateRoot}/work/*/workflow.json` -- other active works for collision checks
- The codebase itself

## Outputs

When complete, ALL of the following exist in `{repoStateRoot}/work/{id}/`:

- `stage-report.md` -- design handoff digest with attention-required at the top
- `design.md` -- solution overview, approach, integration points, risk assessment
  - Required section: `## Blast Radius` listing: modules/files the design touches, failure propagation scope for each (local/adjacent/systemic), and what the design does NOT change.
- `context.md` -- research findings, file paths, gotchas (travels with downstream agents)
- design assumptions artifact -- classified assumptions with resolution status
- `decisions.md` -- all autonomous decisions recorded per `protocols/decision.md`

When warranted: `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`.

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Produce design artifacts and research context.
NEVER write specs, decompose, implement, branch, or test. After gate handoff, STOP.

**Research (HIGH freedom):**
- Load LANDSCAPE.md, AUDIT.md, research briefs if they exist. Scan code, dependencies, patterns.md.
- Delegate to `specwright-researcher` and `specwright-architect` as needed.
- Derive hard constraints from constitution + charter (do not ask — these are documented).
- When the request itself is ambiguous, apply `protocols/decision.md` DISAMBIGUATION:
  infer intent from the argument, codebase context, and charter vision. Record the
  interpretation in decisions.md. If genuinely undetermined, surface at the gate.
- Research is complete when: integration is described, main risk is identified with
  mitigation, blast radius is bounded, no major gaps remain.

**Design (HIGH freedom):**
- Propose the simplest solution grounded in research. Justify abstractions.
- When choosing between alternatives, apply `protocols/decision.md` DISAMBIGUATION
  hierarchy. Record the choice and which rule resolved it in decisions.md.

**Critic (HIGH freedom):**
- For non-trivial requests, delegate to `specwright-architect` for adversarial review.
- Follow `protocols/decision.md#convergence-loop` for the iterative critic loop.
  Convergence at ≥4/5 on all dimensions with no BLOCKs auto-approves per
  `protocols/decision.md#approval`.
- Auto-revise BLOCKs (up to 2 iterations). Document WARNs in design.md.
- If critic rejects the entire approach: apply DISAMBIGUATION to choose the best
  alternative. Record in decisions.md.

**Assumption resolution (MEDIUM freedom):**
- Follow `protocols/decision.md#assumption-lifecycle` for format, classification,
  and autonomous resolution.
- After critic: auto-resolve per `protocols/decision.md#autonomous-resolution`.
  Clarify+technical → auto-ACCEPT. Reference/external → auto-DEFER to backlog per
  `protocols/backlog.md`.
- Assumptions contradicting an AC are Type 1 structural override — always blocking.
  Type 1 deficiencies halt and surface at the gate (do not auto-proceed).

**Change requests (MEDIUM freedom):**
- `design.md` exists + argument: change request, re-run critic.
- `design.md` exists + no argument: apply DISAMBIGUATION — if the user's prior message
  implies a change, treat as change request. Otherwise, present status at the gate.

**Gate handoff (LOW freedom):**
On completion, emit the three-line handoff per the `protocols/decision.md`
Gate Handoff section. Write `{workDir}/stage-report.md` before the handoff.
The Artifacts line points at `Artifacts: {workDir}/stage-report.md`. Detail
lives in the artifact files (`design.md`, `decisions.md`, design assumptions
artifact, `context.md`). The Next line remains machine-parseable: `Next: /sw-plan`.

**State mutations (LOW freedom):**
Follow `protocols/state.md` for read-modify-write mechanics. Postconditions:
- New work created at `{repoStateRoot}/work/{id}/`.
- `{worktreeStateRoot}/session.json.attachedWorkId` is set to the new work ID for
  the current worktree only.
- Do not clear or rewrite unrelated active works in other top-level worktrees.
  Starting a new design in this worktree changes only this worktree's session
  attachment.
- If this worktree was previously attached to a shipped work and the user starts
  a new design, print exactly one informational notice before retargeting this
  worktree:
  `Clearing prior shipped work {unitId}. Run /sw-learn first if pattern capture is desired.`
  The notice is informational only; `sw-learn` remains optional.
- During legacy fallback migration, if prior `currentWork` has status `shipped`,
  clear that legacy attachment and reset `workUnits` to null before retargeting
  this worktree.
- The new selected work's `workflow.json.status` is `designing`.
- The new selected work's `baselineCommit` is the SHA of
  `origin/{config.git.baseBranch}` (default `origin/main`). Captures base branch
  HEAD before any work begins and is never overwritten on re-entry.
- `baselineCommit` also written to `{workDir}/context.md` for historical
  reference.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework, gate handoff, convergence loop, assumption lifecycle
- `protocols/state.md` -- workflow state updates and locking
- `protocols/context.md` -- anchor doc and config loading
- `protocols/delegation.md` -- agent delegation for research and critic
- `protocols/recovery.md` -- compaction recovery
- `protocols/landscape.md` -- codebase reference document format
- `protocols/audit.md` -- codebase health findings format
- `protocols/backlog.md` -- backlog item format and write targets
- `protocols/research.md` -- external research brief format and consumption

## Failure Modes

| Condition | Action |
|-----------|--------|
| Request too vague | Apply DISAMBIGUATION from codebase + charter context. Record interpretation. If undetermined, surface at gate. |
| Active work in progress | Apply DISAMBIGUATION: if argument provided, start new. If no argument, continue existing. Record choice. |
| `design.md` exists, no argument | Apply DISAMBIGUATION: if user's message implies change, treat as change request. Otherwise, present status at gate. |
| Critic rejects entire approach | Apply DISAMBIGUATION to choose best alternative. Record in decisions.md. |
| User rejects design at gate | Revise per user feedback and re-run critic. User overrides critic — note in design.md. |
| Unresolved Type 1 assumptions | Surface at gate handoff as deficiencies. Do not auto-proceed. |
| Compaction during design | Read workflow.json, check which artifacts exist, resume next missing phase |
