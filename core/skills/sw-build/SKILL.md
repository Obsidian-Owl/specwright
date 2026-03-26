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
- `{currentWork.workDir}/spec.md` -- acceptance criteria to implement
- `{currentWork.workDir}/plan.md` -- architecture decisions
- `.specwright/work/{currentWork.id}/design.md` -- solution design from sw-design (design-level)
- `{currentWork.workDir}/context.md` -- research findings, file paths, gotchas
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
Follow `protocols/stage-boundary.md`. This skill implements one work unit via TDD. Handoff to `/sw-verify`.

**Branch setup (LOW freedom) — FIRST action before any coding:**
- Read `config.json` `git` section. Follow `protocols/git.md` branch lifecycle.
- Determine branch name:
  - If `currentWork.unitId` is set (multi-unit): `{git.branchPrefix}{currentWork.unitId}`
  - If `currentWork.unitId` is null (single-unit): `{git.branchPrefix}{currentWork.id}`
- If `git.branchPerWorkUnit` is true (default):
  - Check if the determined branch already exists (recovery case).
  - If exists: `git checkout {branch}`. Pull latest if remote tracking exists.
  - If not: checkout `git.baseBranch`, pull latest, create branch.
- If `git.branchPerWorkUnit` is false: stay on current branch.
- All task commits happen on the feature branch. NEVER commit to baseBranch.

**Repo map generation (MEDIUM freedom) — after branch setup, before first task:**
Generate repo map per `protocols/repo-map.md` before the first task.

**Task loop (MEDIUM freedom):**
Work one task at a time. Complete before starting the next. After each task commit, emit a status card.

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
When delegating, include in the prompt (in this order):
- **Repo map content** at the TOP (read from `{currentWork.workDir}/repo-map.md`; skip if absent)
- The specific task and its acceptance criteria
- Relevant sections of design.md, plan.md, and context.md
- File paths the agent needs to read or modify
- The constitution's relevant practices
- Build and test commands from config.json
- Behavioral reminder: surface confusion, prefer simplicity, touch only task files
- For each AC, include one test whose purpose is to find the condition under which this criterion fails silently
- Build agents MAY read parent `.specwright/work/{currentWork.id}/context.md` as a fallback

**Build failures (MEDIUM freedom):**
- If tests fail after GREEN: delegate to `specwright-build-fixer` (max 2 attempts).
  If still failing: apply `protocols/decision.md` ERROR_HANDLING — document failure,
  proceed to next task unless cascading. Headless: abort per `protocols/headless.md`.
- If RED phase tests don't fail: the tests are wrong. Tell the tester to fix them.
- If executor reports a discrepancy (type/interface mismatch): this is a **plan mismatch**
  (Type 1 structural override). Do NOT invoke build-fixer. Present to user and halt.

**Commits (LOW freedom):**
- One commit per completed task. Follow `protocols/git.md`.
- Commit message references the work unit ID and task.
- Stage only files changed for this task. Never `git add -A`.
- Before committing: if `config.commands.format` is configured, run it. If
  `config.commands.lint` is configured, run it. If formatting changes files,
  restage them. If lint fails, fix inline (orchestrator self-heals trivial
  issues; re-delegate to executor for non-trivial). This is task hygiene,
  not a build-fixer scenario.

**Mid-build checks (MEDIUM freedom):**
- Follow `protocols/assumptions.md` late discovery lifecycle at build start and after each task commit.
- Follow `protocols/build-quality.md` for discovered behaviors capture after each task.

**Per-task micro-check (MEDIUM freedom) — after each task commit:**
- Identify changed code files via `git diff --name-only HEAD~1`. Skip if command fails or no code files changed.
- When `sg` is on PATH: run ast-grep extraction per `protocols/repo-map.md` kind rules; feed structural facts to a single LLM prompt checking for error-path issues. Append findings to `{currentWork.workDir}/feedback-log.md` and include in status card as warning lines. Micro-check is non-blocking.
- When `sg` is not on PATH: skip entirely.

**Post-build review (MEDIUM freedom):**
- After all tasks committed, delegate review to `specwright-reviewer`.
- Follow `protocols/build-quality.md` for trigger, depth calibration, delegation details, and findings triage.

**Inner-loop validation (MEDIUM freedom) — runs after post-build review:**
If `commands.test:integration` is configured, run it (5-minute timeout). On pass, note
in status card. On fail, delegate to `specwright-build-fixer` (max 2 attempts) — the
fixer should check infrastructure health before assuming code is wrong. If still failing
after 2 attempts: interactive — present to user (including abort); headless — skip and
record in headless-result.json. If unconfigured, skip silently. Note: verify re-runs
integration tests via gate-build; the inner-loop catch is earlier, when fixer context
is fresh.

**Parallel execution — experimental (MEDIUM freedom):**
- Follow `protocols/parallel-build.md` when all prerequisites are met:
  `config.experimental.agentTeams.enabled`, `SPECWRIGHT_AGENT_TEAMS` env var, 4+ tasks.
- If any prerequisite fails: execute tasks sequentially (normal behavior). No error.
- Do NOT start implementing tasks yourself while teammates are working.

**As-built notes (LOW freedom):**
- After all tasks committed (and after post-build review), append `## As-Built Notes` to `{currentWork.workDir}/plan.md`: plan deviations, implementation decisions, actual file paths.
- spec.md stays untouched. gate-spec does NOT consume as-built notes. Primary consumer: sw-learn.
- Follow `protocols/build-quality.md` for content scope.

**State updates (LOW freedom):**
- Follow `protocols/state.md` for all workflow.json mutations.
- Acquire lock before starting. Release after each task commit.
- Update `tasksCompleted` array after each successful task.

**Context management (MEDIUM freedom):**
- Follow `protocols/build-context.md` for continuation snapshots, status cards, and context nudge.

<!-- platform:claude-code -->
**Task tracking (LOW freedom):**
- At build start, create Claude Code tasks from spec/plan (subject = task name, description = AC summary, activeForm = present-continuous).
- Update workflow.json FIRST; TaskUpdate is best-effort. Tracking failures never halt the build.
- Orchestrator-only: delegated agents do not update task status.
- Disambiguation: `Task` tool = agent delegation. `TaskCreate`/`TaskUpdate`/`TaskList`/`TaskGet` = visual tracking. Never conflate.
- On compaction recovery: create fresh tasks from spec/plan, sync from workflow.json.
<!-- /platform -->

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/state.md` -- workflow state and locking
- `protocols/git.md` -- commit discipline
- `protocols/delegation.md` -- agent delegation with fallback
- `protocols/recovery.md` -- compaction recovery
- `protocols/build-quality.md` -- post-build review and as-built notes
- `protocols/build-context.md` -- continuation snapshots, status cards, context nudge, repo map injection
- `protocols/repo-map.md` -- repo map format, generation, token budget, truncation
- `protocols/decision.md` -- autonomous decision framework (ERROR_HANDLING for build failures)
- `protocols/headless.md` -- non-interactive execution defaults
- `protocols/parallel-build.md` -- parallel task execution with agent teams

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-design and /sw-plan first" |
| Build/test command not configured | STOP: "Configure commands in config.json or run /sw-init" |
| Tester writes tests that pass immediately | Tests are wrong. Re-delegate with instruction to write tests that FAIL first. |
| Executor can't pass tests after 2 build-fixer attempts | STOP. Show error to user. Don't loop forever. |
| Compaction during build | Read workflow.json, find last completed task, resume next task. |
| Compaction during parallel execution | Read workflow.json, check `.specwright/worktrees/` for orphans, clean up, resume sequential. |
<!-- platform:claude-code -->
| Task tracking tools unavailable | Continue with workflow.json-only tracking. Best-effort. |
<!-- /platform -->
| Lock held by another skill | STOP with lock info. Don't force-clear. |
