---
name: sw-design
description: >-
  Interactive solution architecture. Researches the codebase, designs a
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
  - AskUserQuestion
---

# Specwright Design

## Goal

Research the codebase, design a solution, challenge it adversarially, and produce
design artifacts the user trusts. Output is a design — not specs, not code.

## Inputs

- The user's request (argument or conversation)
- `.specwright/CONSTITUTION.md` -- practices to follow
- `.specwright/CHARTER.md` -- vision and invariants
- `.specwright/config.json` -- project configuration
- `.specwright/state/workflow.json` -- current state
- The codebase itself

## Outputs

When complete, ALL of the following exist in `.specwright/work/{id}/`:

- `design.md` -- solution overview, approach, integration points, risk assessment
- `context.md` -- research findings, file paths, gotchas (travels with downstream agents)
- `assumptions.md` -- classified assumptions with resolution status (Full intensity only; Lite inlines in context.md; Quick skips)

When warranted: `decisions.md`, `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`. Only produce conditional artifacts when needed.

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You produce design artifacts and research context.
- You NEVER write specs, decompose into work units, write implementation code, create branches, or run tests.
- After the user approves the design, STOP and present the handoff to `/sw-plan`.

**Triage (MEDIUM freedom):**
- Assess request size and complexity. Recommend an intensity level via AskUserQuestion:
  - **Full**: multi-file, architectural, ambiguous → full design cycle, handoff to `/sw-plan`
  - **Lite**: single concern, 1-3 files, clear scope → minimal `context.md` only (no design.md), status → `planning`, handoff to `/sw-plan`
  - **Quick**: trivial fix, <20 lines → minimal `context.md` + `spec.md` (1-3 criteria), status → `building`, handoff to `/sw-build`
- Default to Full when uncertain.

**Research (HIGH freedom):**
- If `.specwright/LANDSCAPE.md` exists, load it first. If stale per `protocols/landscape.md`, refresh inline and update `Snapshot:` timestamp. If missing, proceed without. Use as baseline for research.
- If `.specwright/AUDIT.md` exists and fresh per `protocols/audit.md`, surface relevant findings for the area being designed.
- Scan code, dependencies, APIs, existing patterns. Check `.specwright/patterns.md` and `.specwright/learnings/INDEX.md` if they exist.
- Delegate to `specwright-researcher` and `specwright-architect` as needed.
- Produce `context.md` summarizing findings for downstream agents.
- Research is complete when: can describe how the solution integrates with existing code (specific files/modules), can identify the main risk and at least one mitigation, can list what the solution does NOT change (blast radius is bounded), and no major "I'm guessing" gaps remain.

**Design (HIGH freedom):**
- Propose the simplest solution grounded in research. Justify any abstractions.
- Reference charter (vision) and constitution (practices). Present alternatives when reasonable.

**Critic (HIGH freedom):**
- For non-trivial requests, delegate to `specwright-architect` to find flaws AND identify assumptions. Show user findings and resolutions.
- Skip for straightforward requests.

**Assumption resolution (MEDIUM freedom):**
- Follow `protocols/assumptions.md` for format and classification.
- After critic, present UNVERIFIED assumptions to the user grouped by resolution type:
  - `clarify` -- ask the user specific questions to resolve ambiguity
  - `reference` -- ask the user to provide API docs, schemas, interface definitions, or types
  - `external` -- flag items the user must resolve with other teams or third parties
- User resolves each: answer the question, provide the doc, accept the risk, or mark as resolved.
- Design CANNOT be approved while UNVERIFIED assumptions remain. User may ACCEPT any assumption (acknowledging risk) to unblock.
- For Lite intensity: capture assumptions inline in `context.md` instead of a separate artifact.
- For Quick intensity: skip assumption tracking entirely.

**Change requests (MEDIUM freedom):**
- `design.md` exists + argument: change request, re-run critic. No argument: ask — redesign, continue, or changes.

**User checkpoints:**
- Ask for hard constraints before research. Share findings after research, alternatives after design, resolutions after critic, assumption resolution before approval. User approves design before saving.

**State mutations (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json updates.
- Set `currentWork.status` to `designing`. Set `currentWork.intensity` to chosen level. Create work directory.
- Work ID: short, descriptive, kebab-case.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/state.md` -- workflow state updates and locking
- `protocols/context.md` -- anchor doc and config loading
- `protocols/delegation.md` -- agent delegation for research and critic
- `protocols/recovery.md` -- compaction recovery
- `protocols/assumptions.md` -- assumption format, classification, and lifecycle
- `protocols/landscape.md` -- codebase reference document format
- `protocols/audit.md` -- codebase health findings format

## Failure Modes

| Condition | Action |
|-----------|--------|
| Request too vague | Ask user with concrete options based on codebase scan |
| Active work already in progress | Ask user: continue existing, or start new? |
| `design.md` exists, no argument | Ask: redesign from scratch, continue to `/sw-plan`, or describe changes? |
| Critic rejects entire approach | Present rejection to user with alternatives. Don't silently override. |
| User disagrees with critic | User wins. Note disagreement in design.md for the record. |
| Unresolved assumptions block approval | Present grouped by resolution type. User must clarify, provide references, or accept risk. |
| User cannot resolve external assumption now | Mark as ACCEPTED with note. Design proceeds; assumption becomes a tracked risk in plan. |
| Compaction during design | Read workflow.json, check which artifacts exist, resume next missing phase |
