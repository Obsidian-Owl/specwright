---
name: sw-build
description: >-
  TDD implementation of one work unit. Delegates test writing to the tester
  agent and implementation to the executor agent. Commits per task.
argument-hint: "[work-id] [task-id]"
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

# Specwright Build

## Goal

Implement the current work unit using test-driven development. Each task
goes through RED (tester writes failing tests) → GREEN (executor makes
them pass) → REFACTOR. The user sees progress after every task and the
codebase stays green between tasks.

## Inputs

- `.specwright/state/workflow.json` -- current work unit and task progress
- `.specwright/work/{id}/spec.md` -- acceptance criteria to implement
- `.specwright/work/{id}/plan.md` -- architecture decisions
- `.specwright/work/{id}/context.md` -- research findings, file paths, gotchas
- `.specwright/CONSTITUTION.md` -- coding standards to follow
- `.specwright/config.json` -- build/test commands, agent config

## Outputs

After each task:
- Tests written and passing
- Implementation committed (one commit per task)
- `workflow.json` updated with task progress

After all tasks:
- `workflow.json` status set to `building` → ready for verify
- All acceptance criteria have corresponding tests and implementation

## Constraints

**Task loop (MEDIUM freedom):**
- Work one task at a time. Complete it before starting the next.
- If no task ID given, pick the next incomplete task from spec.md.
- If no work unit ID given, use `currentWork` from workflow.json.

**TDD cycle (HIGH freedom for test design, LOW freedom for sequence):**

The sequence is strict: RED → GREEN → REFACTOR. Never skip RED.

1. **RED**: Delegate to `specwright-tester` with the task's acceptance criteria,
   context.md, and constitution. The tester writes tests designed to be hard to
   pass. Run tests to confirm they fail.
2. **GREEN**: Delegate to `specwright-executor` with the failing tests, context.md,
   plan.md, and constitution. The executor writes minimal code to pass. Run
   build + tests to confirm they pass.
3. **REFACTOR**: Executor may refactor if needed. Tests must still pass.

**Context envelope (LOW freedom):**
When delegating, include in the prompt:
- The specific task and its acceptance criteria
- Relevant sections of plan.md and context.md
- File paths the agent needs to read or modify
- The constitution's relevant practices
- Build and test commands from config.json

**Build failures (MEDIUM freedom):**
- If tests fail after GREEN: delegate to `specwright-build-fixer` (max 2 attempts)
- If build-fixer fails twice: STOP and show the user the error. Don't loop.
- If RED phase tests don't fail: the tests are wrong. Tell the tester to fix them.

**Commits (LOW freedom):**
- One commit per completed task. Follow `protocols/git.md`.
- Commit message references the work unit ID and task.
- Stage only files changed for this task. Never `git add -A`.

**State updates (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json mutations.
- Acquire lock before starting. Release after each task commit.
- Update `tasksCompleted` array after each successful task.

## Protocol References

- `protocols/state.md` -- workflow state and locking
- `protocols/git.md` -- commit discipline
- `protocols/delegation.md` -- agent delegation with fallback
- `protocols/recovery.md` -- compaction recovery

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-plan first" |
| Build/test command not configured | STOP: "Configure commands in config.json or run /sw-init" |
| Tester writes tests that pass immediately | Tests are wrong. Re-delegate with instruction to write tests that FAIL first. |
| Executor can't pass tests after 2 build-fixer attempts | STOP. Show error to user. Don't loop forever. |
| Compaction during build | Read workflow.json, find last completed task, resume next task |
| Lock held by another skill | STOP with lock info. Don't force-clear. |
