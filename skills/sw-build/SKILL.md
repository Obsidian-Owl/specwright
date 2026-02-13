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
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskGet
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
- `.specwright/work/{id}/design.md` -- solution design from sw-design
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

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You implement ONE work unit via TDD. You NEVER run quality gates, create PRs, ship code, or start the next work unit.
- After all tasks for this unit are committed, STOP and present the handoff to `/sw-verify`.

**Branch setup (LOW freedom) — FIRST action before any coding:**
- Read `config.json` `git` section. Follow `protocols/git.md` branch lifecycle.
- If `git.branchPerWorkUnit` is true (default):
  - Check if branch `{git.branchPrefix}{work-unit-id}` already exists (recovery case).
  - If exists: `git checkout {branch}`. Pull latest if remote tracking exists.
  - If not: checkout `git.baseBranch`, pull latest, create branch.
- If `git.branchPerWorkUnit` is false: stay on current branch.
- All task commits happen on the feature branch. NEVER commit to baseBranch.

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
3. **REFACTOR**: Executor may refactor code written in THIS task only. Tests must still pass. No adjacent code cleanup.

**Context envelope (LOW freedom):**
When delegating, include in the prompt:
- The specific task and its acceptance criteria
- Relevant sections of design.md, plan.md, and context.md
- File paths the agent needs to read or modify
- The constitution's relevant practices
- Build and test commands from config.json
- Behavioral reminder: surface confusion, prefer simplicity, touch only task files

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

**Task tracking (LOW freedom):**
- At build start, create Claude Code tasks from spec/plan for visual progress tracking (subject = task name, description = acceptance criteria summary, activeForm = present-continuous).
- Write ordering: update workflow.json FIRST (source of truth), then TaskUpdate as best-effort. Task tracking failures never halt the build.
- Orchestrator-only: delegated agents (tester, executor, build-fixer) do not update task status.
- Do not use `blockedBy`/`blocks` dependencies. The sequential task loop handles ordering.
- Disambiguation: `Task` tool = agent delegation (`protocols/delegation.md`). `TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet` = visual progress tracking. Never conflate.
- On recovery after compaction: create fresh tasks from spec/plan, sync status from workflow.json.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/state.md` -- workflow state and locking
- `protocols/git.md` -- commit discipline
- `protocols/delegation.md` -- agent delegation with fallback
- `protocols/recovery.md` -- compaction recovery

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-design and /sw-plan first" |
| Build/test command not configured | STOP: "Configure commands in config.json or run /sw-init" |
| Tester writes tests that pass immediately | Tests are wrong. Re-delegate with instruction to write tests that FAIL first. |
| Executor can't pass tests after 2 build-fixer attempts | STOP. Show error to user. Don't loop forever. |
| Compaction during build | Read workflow.json, find last completed task, resume next task |
| Lock held by another skill | STOP with lock info. Don't force-clear. |
