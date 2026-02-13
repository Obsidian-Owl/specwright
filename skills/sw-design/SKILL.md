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

Deeply understand the user's request, research the codebase and external
systems, design a solution, challenge it adversarially, and produce design
artifacts the user trusts. The output is a design — not specs, not code.

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

When the request warrants them, also:

- `decisions.md` -- architecture decision records (ADR-style)
- `data-model.md` -- entity definitions, schema changes, data flows
- `contracts.md` -- API specifications, interface definitions, event schemas
- `testing-strategy.md` -- test levels, coverage goals, infrastructure decisions
- `infra.md` -- topology changes, resource requirements, CI/CD changes
- `migrations.md` -- schema migrations, data migrations, rollback plans

Only produce conditional artifacts when the project and request need them.

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You produce design artifacts and research context.
- You NEVER write specs, decompose into work units, write implementation code, create branches, or run tests.
- After the user approves the design, STOP and present the handoff to `/sw-plan`.

**Triage (MEDIUM freedom):**
- Assess request size and complexity. This determines which phases to run and which conditional artifacts to produce.
- When uncertain, ask the user.

**Research (HIGH freedom):**
- Understand the codebase BEFORE designing. Scan relevant code, dependencies, APIs, frameworks, existing patterns.
- Delegate to `specwright-researcher` for external documentation.
- Delegate to `specwright-architect` for deep codebase analysis if needed.
- Produce `context.md` summarizing findings for downstream agents.

**Design (HIGH freedom):**
- Propose a solution grounded in research findings.
- Prefer the simplest approach that meets the requirements.
- If proposing abstractions or indirection, justify why simpler alternatives won't work.
- Reference the charter for vision alignment and the constitution for practice compliance.
- Present alternatives when reasonable. Let the user choose.

**Critic (HIGH freedom):**
- For non-trivial requests, challenge the design adversarially before committing.
- Delegate to `specwright-architect` with instruction to find flaws.
- Show the user what the critic found and how you addressed it.
- Small requests may skip the critic phase when the design is straightforward.

**Change requests (MEDIUM freedom):**
- If `design.md` already exists AND the user provides an argument: treat as a change request. Load the existing design, apply the requested changes, re-run the critic.
- If `design.md` exists AND no argument: ask the user — redesign, continue to `/sw-plan`, or describe changes.

**User checkpoints throughout:**
- Before research: if the request has multiple viable approaches (deployment
  strategy, auth method, UI framework, etc.), ask for hard constraints FIRST.
  Record in design.md under "## User Preferences". These constrain all
  subsequent research and design.
- After research: share surprising findings, risks, or unknowns.
- After design: present approach with alternatives.
- After critic: show what was challenged and how it was resolved.
- The user must approve the design before it is saved.

**State mutations (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json updates.
- Set `currentWork.status` to `designing`. Create work directory.
- Work ID: short, descriptive, kebab-case.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/state.md` -- workflow state updates and locking
- `protocols/context.md` -- anchor doc and config loading
- `protocols/delegation.md` -- agent delegation for research and critic
- `protocols/recovery.md` -- compaction recovery

## Failure Modes

| Condition | Action |
|-----------|--------|
| Request too vague | Ask user with concrete options based on codebase scan |
| Active work already in progress | Ask user: continue existing, or start new? |
| `design.md` exists, no argument | Ask: redesign from scratch, continue to `/sw-plan`, or describe changes? |
| Critic rejects entire approach | Present rejection to user with alternatives. Don't silently override. |
| User disagrees with critic | User wins. Note disagreement in design.md for the record. |
| Compaction during design | Read workflow.json, check which artifacts exist, resume next missing phase |
