# Parallel Build Protocol

Experimental parallel task execution using helper worktrees. Only used by
`sw-build` when all prerequisites are met. Falls back to sequential execution
otherwise.

## Prerequisites

All three conditions must be true:

1. `config.experimental.agentTeams.enabled` is `true`
2. `SPECWRIGHT_AGENT_TEAMS=1` is set
3. the selected work unit has 4 or more tasks

If any condition fails, skip parallel execution entirely.

## Parent And Subordinate Sessions

Parallel execution never creates a second top-level owner for the selected
work.

- the current worktree remains the parent `top-level` session
- each helper worktree is a `subordinate` session under the same `workId`
- subordinate sessions inherit context from the parent work
- subordinate sessions do not claim ownership in
  `workflow.json.attachment`

Subordinate sessions may read the parent work's shared artifacts and use local
continuation state, but they must not directly ship, verify, or rewrite shared
work selection.

## Independence Analysis

Read `plan.md` to extract each task's file targets (`**Files**:`).

| Condition | Classification |
|---|---|
| no file overlap with another task | independent |
| shares a file target with another task | dependent |
| no explicit file targets | dependent (conservative) |

Group independent tasks into a parallel batch. Remaining tasks form a
sequential tail. Minimum batch size is 2.

## Worktree Setup

For each task in the parallel batch, create an isolated helper worktree:

```bash
git worktree add .specwright/worktrees/{task-id} -b specwright-wt-{task-id} HEAD
git worktree lock .specwright/worktrees/{task-id} --reason "Specwright parallel build"
```

For each helper worktree, materialize a subordinate session at its
`worktreeStateRoot/session.json` with:

- the helper `worktreeId`
- `attachedWorkId = {parentWorkId}`
- `mode = "subordinate"`
- the helper branch name

If `git worktree lock` fails, warn and continue without the lock.

## Team Creation

Spawn one helper per parallel task, capped by
`config.experimental.agentTeams.maxTeammates`.

Each helper prompt includes:

- the task acceptance criteria and relevant plan/context sections
- the parent work's shared artifact path under `repoStateRoot`
- the helper worktree path
- the rule that only the helper worktree may be edited
- the rule that shared work selection and shipping remain parent-only

If plan approval is required, the helper submits a plan before starting.

## Parallel Execution

Each subordinate helper:

1. changes to its helper worktree
2. runs the normal RED -> GREEN -> REFACTOR loop for its task
3. commits to `specwright-wt-{task-id}`
4. reports completion back to the parent

The parent session remains the only authority that updates the selected work's
shared workflow state.

If a helper fails, the parent records the failure and retries that task in the
sequential tail.

## Cherry-Pick

After helpers finish, the parent top-level session cherry-picks completed
helper commits onto the feature branch in task order:

```bash
git checkout {feature-branch}
git cherry-pick HEAD..specwright-wt-{task-id}
```

If cherry-pick conflicts, abort the cherry-pick and hand the task back to the
sequential tail or the user.

## Cleanup

After cherry-pick or any exit path:

```bash
git worktree unlock .specwright/worktrees/{task-id}
git worktree remove .specwright/worktrees/{task-id}
git branch -d specwright-wt-{task-id}
```

Also remove the helper's subordinate session data with the worktree itself.
Never force-remove helper worktrees.

## Sequential Tail

Run all dependent tasks, failed helper tasks, and cherry-pick conflicts through
the normal sequential build loop in the parent top-level session.

## Failure Modes

| Condition | Action |
|---|---|
| Compaction during parallel execution | inspect helper worktrees, remove subordinate sessions, resume sequentially |
| Orphaned helper worktrees | warn, offer cleanup, never force-remove |
| Helper failure | retry in sequential tail |
| Cherry-pick conflict | abort and retry sequentially or surface to user |
| Team creation failure | fall back to sequential execution |
| `git worktree lock` unavailable | warn and continue without lock |
