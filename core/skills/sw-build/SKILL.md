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

Implement the current work unit with TDD. The per-task loop is RED → GREEN → REFACTOR; end-of-unit integration and regression checks live in one optional after-build phase.

## Inputs

- `{worktreeStateRoot}/session.json` -- selected work for this worktree
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json`, `{workDir}/spec.md`, `{workDir}/plan.md`
- `{workArtifactsRoot}/{selectedWork.id}/design.md`, `{workDir}/context.md`
- `{workArtifactsRoot}/{selectedWork.id}/approvals.md` -- durable design and unit approval ledger when present
- `{projectArtifactsRoot}/CONSTITUTION.md`, `{projectArtifactsRoot}/config.json`

## Outputs

- After each task: failing tests, passing implementation, task commit, workflow progress, updated `{workDir}/implementation-rationale.md`, refreshed `{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`
- After all tasks: as-built notes in `plan.md`, three-line handoff to `/sw-verify`, ready-to-verify build state; the handoff points at `Artifacts: {repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`

## Constraints

**Execution model (LOW freedom):** Run in the foreground in the current turn. "Autonomous" means unattended decisions inside this build, not background execution.

**Stage boundary (LOW freedom):** Follow `protocols/stage-boundary.md`. Implement only the active unit; never create pull requests, run `gh pr create`, or invoke `/sw-ship`. Before the terminal handoff, write `{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`; the handoff points at it and the Next line is `Next: /sw-verify`.

**Branch setup (LOW freedom):** First action before coding: resolve the session-selected work from the current worktree, verify that no other live top-level worktree owns it, then check out the feature branch from `config.git.branchPrefix` and sync it per `protocols/git.md`. The selected work's recorded `targetRef`, when present, is the first branch-resolution input via `protocols/git.md`; repo config defaults and the `baseBranch` compatibility alias are fallbacks only. Use `{git.branchPrefix}{selectedWork.unitId}` for multi-unit work and never commit to the base branch. If the selected work is already owned elsewhere, STOP with explicit adopt/takeover guidance instead of mutating it silently.

**Build freshness checkpoint (LOW freedom) — after branch setup:** Evaluate the build checkpoint via `protocols/git-freshness.md` using the selected work's recorded `targetRef` and `freshness`. `require` blocks stale, diverged, and blocked freshness results; `warn` surfaces advisory drift; queue-managed results do not trigger hidden rebases or other branch rewrites.

**Approval checkpoint (LOW freedom) — before task loop:** Use `protocols/approvals.md` and the shared helper with the current unit artifact set (`spec.md`, `plan.md`, `context.md`). Interactive `/sw-build` runs may record an `APPROVED` `unit-spec` entry in `{workArtifactsRoot}/{selectedWork.id}/approvals.md` with source classification `command`; headless runs must validate existing human approval instead. Never move approval truth into `workflow.json`.

**Task loop (MEDIUM freedom):** Work one task at a time. Finish it before starting the next and emit a status card after each task commit.

**Implementation rationale (LOW freedom) — at each task commit boundary:**
Maintain `{workDir}/implementation-rationale.md` as an append-only curated
artifact with one section per completed task. In `tracked` work-artifact mode,
stage the task's rationale content before creating the task commit so the
tracked tree stays clean; if the resulting commit SHA is only known after the
commit is created, capture that SHA in the next synchronized rationale update
instead of leaving tracked artifacts dirty between tasks. Each task entry must
record the task ID, relevant AC references, changed files, tests added or
updated, why this approach was chosen, any deviation from the approved unit
artifacts, the execution path (`executor` or `build-fixer`), and the task
commit SHA once it is known. This artifact captures rationale, not transcript
excerpts.

**TDD cycle (LOW freedom for sequence):**
1. **RED:** delegate to `specwright-tester`, write hard-to-pass tests, and confirm they fail.
2. **GREEN:** delegate to `specwright-executor`, pass the failing tests, and stop on any plan mismatch or pre-existing type/signature discrepancy.
3. **REFACTOR:** simplify only code written for the current task; keep behavior unchanged.
Per-task integration and regression runs do not happen inside this loop.

**Mid-build checks (MEDIUM freedom):** Follow `protocols/decision.md#late-discovery-lifecycle` and `protocols/build-quality.md` for late discoveries, behavior capture, and as-built notes.

**Build failures (MEDIUM freedom):** If RED tests pass, the tests are wrong. If GREEN or after-build checks fail, delegate to `specwright-build-fixer` for at most 2 attempts and follow `protocols/headless.md` for persistent failures. Treat executor-reported signature/type mismatches as a plan mismatch, not a build-fixer case.

**Commits (LOW freedom):** One commit per completed task. Stage only the files for that task, never use `git add -A`, and run configured format/lint commands before committing when present.

**After-build (MEDIUM freedom):** Optional end-of-unit phase only. Delegate post-build review, then run `commands.test` and `commands.test:integration` when configured; integration now runs here once per unit, not per task. On failure, use `specwright-build-fixer` (max 2 attempts); if it still fails, surface it to the user in interactive mode and skip with a recorded note in headless mode.

**Task tracking (LOW freedom):** When Claude Code task tools are available, create and update task records, but keep the selected work's `workflow.json` as the source of truth. Tracking failures never block the build.

**State updates (LOW freedom):** Follow `protocols/state.md`: acquire the per-work lock on the selected work before mutations, update the selected work's `tasksCompleted` after each committed task, refresh `currentTask`, and append as-built notes before handoff. Mutate only the selected work's `workflow.json` and the current worktree's session state.

**Parallel execution (MEDIUM freedom):** Only use `protocols/parallel-build.md` when the experimental config flag enables it; otherwise ignore it and stay sequential.

## Protocol References

- `protocols/stage-boundary.md` -- scope and final handoff
- `protocols/git.md` -- branch lifecycle and commit discipline
- `protocols/git-freshness.md` -- build-entry freshness checkpoint
- `protocols/approvals.md` -- spec approval capture and validation
- `protocols/review-packet.md` -- rationale artifact contract consumed by the reviewer packet
- `protocols/delegation.md` -- tester/executor/build-fixer context handoff
- `protocols/build-quality.md` -- post-build review and as-built notes
- `protocols/decision.md` -- late discoveries and error handling
- `protocols/headless.md` -- non-interactive failure handling
- `protocols/parallel-build.md` -- config-gated parallel mode
- `protocols/state.md` -- workflow locking and task progress

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-design and /sw-plan first" |
| Selected work owned by another live top-level worktree | STOP with explicit adopt/takeover guidance |
| Build/test command not configured | STOP: "Configure commands in config.json or run /sw-init" |
| Tester writes tests that pass immediately | Re-delegate RED with stronger failing cases |
| Executor reports a pre-existing type/signature mismatch | STOP and surface the plan mismatch |
| Build-fixer exhausts 2 attempts | STOP and show the failure |
| Per-work lock held by another skill | STOP with lock info |
