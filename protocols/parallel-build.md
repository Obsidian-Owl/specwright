# Parallel Build Protocol

Experimental parallel task execution using Claude Code Agent Teams. Only used by sw-build when all prerequisites are met. Falls back to sequential execution otherwise.

## Prerequisites

All three conditions must be true:

1. `config.experimental.agentTeams.enabled` is `true`
2. Environment variable `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set
3. The work unit has 4 or more tasks

If any condition fails: skip parallel execution entirely. No error, no warning. Execute tasks sequentially (normal behavior).

## Independence Analysis

Read `plan.md` to extract each task's file targets (files listed under `**Files**:`).

Classification rules:

| Condition | Classification |
|-----------|---------------|
| No file overlap with any other task | Independent |
| Shares a file target with another task | Dependent |
| No explicit file targets listed in plan.md | Dependent (conservative) |

Group independent tasks into a parallel batch. Remaining tasks form a sequential tail.

**Minimum batch size:** 2. If fewer than 2 tasks are independent, skip parallel execution.

Present the partition to the user via AskUserQuestion:
- List independent tasks (parallel batch) and dependent tasks (sequential tail)
- User must confirm before proceeding

## Worktree Setup

For each task in the parallel batch, create an isolated git worktree:

```bash
git worktree add .specwright/worktrees/{task-id} -b specwright-wt-{task-id} HEAD
```

`.specwright/worktrees/` is project-local and gitignored.

If `config.commands.build` or `config.commands.test` require installed dependencies (e.g., `node_modules/`), the lead must install dependencies in each worktree before spawning teammates:

```bash
cd .specwright/worktrees/{task-id} && {package-manager-install-command}
```

Record all worktree paths for cleanup.

## Team Creation

Create an agent team with one teammate per parallel task, capped at `config.experimental.agentTeams.maxTeammates`.

If the parallel batch exceeds `maxTeammates`, split into sub-batches and execute them sequentially.

### Spawn Prompt Template

Each teammate's spawn prompt includes:

- **Acceptance criteria**: the task's criteria from spec.md (inline, not by reference)
- **Plan details**: relevant plan.md and context.md sections (inline)
- **Constitution practices**: relevant principles from CONSTITUTION.md
- **Build/test commands**: from config.json `commands` section
- **Worktree path (absolute)**: "Your working directory is `{absolute-project-path}/.specwright/worktrees/{task-id}`"
- **Main tree artifacts path**: "Read spec, plan, context, and constitution from `{absolute-project-path}/.specwright/`"
- **File scope constraint**: "You may ONLY modify files within your worktree"
- **State restriction**: "Do NOT read or modify any files in `.specwright/state/`"
- **TDD delegation chain**: delegate RED phase to `specwright-tester`, then GREEN phase to `specwright-executor`, then refactor
- **Commit instruction**: "After passing tests, commit your changes to your worktree branch using conventional commit format"
- **Wait instruction**: "When done, mark your task as completed. Do NOT start additional tasks after completing yours"

If `config.experimental.agentTeams.requirePlanApproval` is `true`, include: "Submit your implementation plan before starting. Wait for lead approval."

## Parallel Execution

The lead waits for all teammates to complete. Do NOT start implementing tasks while teammates are working.

Each teammate independently:
1. Changes to their worktree directory
2. Runs RED phase (delegates to `specwright-tester` subagent)
3. Runs GREEN phase (delegates to `specwright-executor` subagent)
4. Runs REFACTOR (executor or self)
5. Runs build/test commands to verify (if configured)
6. Commits to their worktree branch (`specwright-wt-{task-id}`)
7. Marks task as completed

**Failure handling:** If a teammate fails (build-fixer exhausted after max 2 attempts), the lead records the failure and continues monitoring other teammates. Failed tasks move to the sequential tail for retry.

## Cherry-Pick

After all teammates finish, the lead cherry-picks each completed worktree branch's commit(s) onto the feature branch:

```bash
git checkout {feature-branch}
git cherry-pick specwright-wt-{task-id}
```

Cherry-pick in task order (task-1 before task-2, etc.) for deterministic history.

**Conflict handling:**
- Abort the cherry-pick: `git cherry-pick --abort`
- Present the conflict to the user via AskUserQuestion
- Offer options: resolve manually, or re-run the conflicting task sequentially after other tasks

## Cleanup

After cherry-pick (or on any exit path):

```bash
git worktree remove .specwright/worktrees/{task-id}
git branch -d specwright-wt-{task-id}
```

Use `git branch -d` (not `-D`) and `git worktree remove` (no `--force` flag). If removal fails, warn the user. Do not force-remove.

Clean up the agent team after all worktrees are removed.

## Sequential Tail

Execute remaining tasks using the normal sequential TDD loop (unchanged sw-build behavior):
- Tasks classified as dependent during independence analysis
- Tasks that failed during parallel execution
- Tasks that couldn't be cherry-picked due to conflicts

The lead handles these tasks directly, one at a time, with normal state updates.

## Failure Modes

| Condition | Action |
|-----------|--------|
| Compaction during parallel execution | Read workflow.json, check `.specwright/worktrees/` for orphaned worktrees, clean up worktrees and branches, resume with sequential execution for remaining tasks |
| Orphaned worktrees (from crash or prior failure) | Check `.specwright/worktrees/` at build start. If non-empty, warn user. Offer cleanup or resume. |
| Teammate failure (build-fixer exhausted) | Record failure, continue with other teammates, retry failed task in sequential tail |
| Cherry-pick conflict | Abort cherry-pick, present to user, offer manual resolution or sequential re-run |
| Agent team creation failure | Fall back to sequential execution for all tasks. No error — graceful degradation. |
