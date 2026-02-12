---
name: sw-plan
description: >-
  Understands the user's request, researches the codebase deeply, designs
  a solution, challenges it adversarially, and produces actionable specs.
argument-hint: "<what you want to build or change>"
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

Turn the user's request into a verified, challenged plan with specs that
will lead to the right outcome. The user should feel confident that you
deeply understand their codebase, have considered alternatives, and have
anticipated what will go wrong.

## Inputs

- The user's request (argument or conversation)
- `.specwright/CONSTITUTION.md` -- practices to follow
- `.specwright/CHARTER.md` -- vision and invariants
- `.specwright/config.json` -- project configuration
- `.specwright/state/workflow.json` -- current state
- The codebase itself

## Outputs

When complete, ALL of the following exist:

- `.specwright/work/{id}/spec.md` -- acceptance criteria (each testable)
- `.specwright/work/{id}/plan.md` -- architecture decisions and approach
- `.specwright/work/{id}/context.md` -- research findings (travels with executor and tester)
- `.specwright/state/workflow.json` -- updated with `currentWork`
- If large: multiple work units, each with own spec

## Phases

### Triage (MEDIUM freedom)

Assess request size and complexity:
- **Small** (one session, single concern) → one spec.
- **Large** (multi-session, multiple concerns) → decompose into work units.
- When uncertain, ask the user. Show what you see and let them decide.

### Research (HIGH freedom)

Understand the codebase BEFORE designing anything:
- Scan relevant code, dependencies, APIs, frameworks, existing patterns.
- Check official documentation for SDKs and libraries involved.
- Identify constraints, risks, and things that will break.
- Produce `context.md` summarizing findings for downstream agents.
- Delegate to `specwright-researcher` for external documentation.
- Delegate to `specwright-architect` for deep codebase analysis if needed.

### Design (HIGH freedom)

Propose a solution grounded in research findings:
- Reference the charter for vision alignment.
- Reference the constitution for practice compliance.
- Present alternatives when reasonable. Let the user choose.
- Don't design in a vacuum -- ground every decision in evidence from research.

### Critic (HIGH freedom)

Challenge the design adversarially before committing:
- Delegate to `specwright-architect` with explicit instruction to find flaws.
- The critic asks: What did you miss? What assumptions are wrong? What will break?
- Show the user what the critic found and how you addressed it.
- Incorporate valid criticisms. Dismiss invalid ones with reasoning shown.

### Spec (MEDIUM freedom)

Write acceptance criteria the tester can turn into brutal tests:
- Each criterion answers: "How will we KNOW this works?"
- Include boundary conditions and error cases, not just happy paths.
- Bad: "The API handles errors gracefully."
- Good: "POST /users with missing email returns 400 with body `{error: 'email_required'}`."
- The user must approve the spec before it's saved.

### Decompose (MEDIUM freedom, only if large)

Break into session-sized work units:
- Each unit is independently buildable and testable.
- Each has its own spec with its own acceptance criteria.
- Ordered by dependency (what must be built first).
- The user approves the decomposition.
- Present the expected cycle per unit:
  ```
  Unit 1: {name} → /sw-build → /sw-verify → /sw-ship
  Unit 2: {name} → /sw-build → /sw-verify → /sw-ship
  ```

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You produce specs, plans, and context documents.
- You NEVER write implementation code, create branches, run tests, or commit changes.
- After the user approves the spec, STOP and present the handoff to `/sw-build`.

**User checkpoints throughout:**
- After triage: confirm size assessment.
- After research: share surprising findings, risks, or unknowns.
- After design: present approach with alternatives.
- After critic: show what was challenged and how it was resolved.
- After spec: approve acceptance criteria.
- Use AskUserQuestion with options grounded in codebase evidence.

**Context document (`context.md`):**
- This is the briefing that travels with the executor and tester.
- Include: relevant file paths, API signatures, framework patterns, gotchas.
- Make it useful, not exhaustive. The executor has its own Read/Grep tools.

**State mutations (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json updates.
- Work directory: `.specwright/work/{id}/`
- Work ID: short, descriptive, kebab-case (e.g., `add-auth-middleware`).

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
| Codebase too large to fully scan | Focus on files relevant to request. Use Glob/Grep strategically. |
| Critic rejects entire approach | Present rejection to user with alternatives. Don't silently override. |
| User disagrees with critic | User wins. Note disagreement in plan.md for the record. |
| Active work already in progress | Ask user: continue existing, or start new? |
| Compaction during planning | Read workflow.json, check which artifacts exist, resume next missing phase |
