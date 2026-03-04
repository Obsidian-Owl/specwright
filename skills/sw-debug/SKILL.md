---
name: sw-debug
description: >-
  Investigation-first debugging workflow. Scopes the problem, delegates root
  cause analysis, produces a diagnosis report, and offers fix/log/defer paths.
argument-hint: "[problem description]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Specwright Debug

## Goal

First-class debugging path. Scope the problem, investigate concurrently,
diagnose with evidence, then decide: fix it now, log it for later, or defer.
Does NOT require going through the full design→plan→build cycle.

## Inputs

- Problem description (argument or conversation)
- Initial evidence: error messages, logs, failing test output
- `.specwright/config.json` — `backlog.type` and `backlog.label` for logging items
- Codebase files — read during investigation

## Outputs

- `diagnosis.md` at `.specwright/work/{id}/` — always produced
- `spec.md` at `.specwright/work/{id}/` — Fix path only (2-3 acceptance criteria)

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You investigate and diagnose. You NEVER write code, run tests, create branches,
  or make commits.
- Fix path: produce `spec.md` and hand off to `/sw-build`. Stop there.
- Log/Defer path: write backlog item and stop.

**Scope (MEDIUM freedom):**
- If problem description provided as argument, use it. Otherwise ask via
  AskUserQuestion: what IS happening, what SHOULD happen.
- Collect any initial evidence the user can share: error messages, stack traces,
  failing test names, logs.
- Define the boundary: what modules or files are likely involved.

**Investigate (HIGH freedom):**
- Delegate concurrently to two agents per `protocols/delegation.md`:
  - `specwright-researcher`: gather code context — read relevant files, trace
    call paths, identify the affected surface area
  - `specwright-architect`: analyze root cause candidates, assess blast radius,
    identify what this does NOT affect
- Synthesize findings into `diagnosis.md`.

**Diagnose (MEDIUM freedom):**
- Write `diagnosis.md` with these sections:
  ```
  ## Problem
  [Observed behavior vs expected behavior]

  ## Root Cause
  [Primary cause — confidence: HIGH / MEDIUM / LOW]
  [Supporting evidence with file:line references]

  ## Blast Radius
  [What's affected | What's NOT affected]

  ## Fix Approach
  [High-level fix — no implementation code]

  ## Alternatives Considered
  [Other hypotheses and why they were ruled out]
  ```
- If agents return insufficient evidence: present "low confidence" diagnosis.
  Offer to expand scope before deciding.

**Decision (LOW freedom):**
- Present AskUserQuestion with exactly three options:
  - **Fix it now** → write `spec.md` with 2-3 acceptance criteria for the fix.
    Set workflow status to `planning`. Hand off to `/sw-build`.
    WARN if the fix spans many files/modules: "This may need `/sw-design` first."
  - **Log it** → write a `BL-{n}` backlog item (`debug` tag) per `protocols/backlog.md`. Stop.
  - **Defer** → write a `BL-{n}` item (`defer` tag), mark diagnosis.md DEFERRED. Stop.

**State (LOW freedom):**
- Follow `protocols/state.md`. Set status to `designing` when work begins.
- Work ID format: `debug-{short-description}` (e.g., `debug-n1-query`).
- "Fix it now": transition status to `planning` after spec.md is written.

## Protocol References

- `protocols/stage-boundary.md` -- scope and handoff
- `protocols/state.md` -- workflow state updates
- `protocols/delegation.md` -- concurrent researcher + architect delegation
- `protocols/backlog.md` -- backlog item format and write targets

## Failure Modes

| Condition | Action |
|-----------|--------|
| No problem description | Ask via AskUserQuestion before investigating |
| Agents return no evidence | Present low-confidence diagnosis; ask to expand scope or log |
| Fix is architectural (many files) | WARN: suggest `/sw-design` instead of direct fix |
| Compaction during investigation | Re-run investigation; diagnosis.md is rebuilt from scratch |
