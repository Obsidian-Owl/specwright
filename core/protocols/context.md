# Context Loading Protocol

## Logical Roots

Every skill, hook, and adapter resolves the same three logical roots on every
invocation:

| Root | Resolution | Purpose |
|---|---|---|
| `projectRoot` | `git rev-parse --show-toplevel` | source tree and user-facing cwd |
| `repoStateRoot` | `git rev-parse --git-common-dir` + `/specwright` | shared repo-level Specwright state |
| `worktreeStateRoot` | `git rev-parse --git-dir` + `/specwright` | per-worktree session and continuation state |

Callers must prefer those logical roots over checkout-local `.specwright/...`
path concatenation.

## Standard Context Documents

### Shared repo documents

Load from `repoStateRoot` when needed for alignment or verification:

- `{repoStateRoot}/config.json` — project settings, commands, gates, git,
  integration, backlog settings
- `{repoStateRoot}/CONSTITUTION.md` — development practices and principles
- `{repoStateRoot}/CHARTER.md` — technology vision and project purpose
- `{repoStateRoot}/TESTING.md` — testing strategy (optional; if absent,
  Constitution testing rules remain authoritative)
- `{repoStateRoot}/LANDSCAPE.md` — codebase architecture and module knowledge
  (optional)
- `{repoStateRoot}/AUDIT.md` — codebase health findings and tech debt tracking
  (optional)
- `{repoStateRoot}/research/*.md` — external research briefs (loaded by
  `sw-design` on demand; warn if stale per `protocols/research.md`)

### Per-work documents

Load from the selected work under `repoStateRoot/work/{workId}`:

- `workflow.json` — lifecycle, gates, units, attachment, per-work lock
- `design.md`, `context.md`, `decisions.md`, `assumptions.md`
- `units/{unitId}/spec.md`, `plan.md`, `context.md`, `stage-report.md`,
  `evidence/`

### Per-worktree documents

Load from `worktreeStateRoot`:

- `session.json` — the current worktree's attached work, mode, branch, and
  `lastSeenAt`
- `continuation.md` — worktree-local continuation snapshot (optional)

## Root Resolution Sequence

Run this sequence before loading Specwright state:

1. resolve `projectRoot`
2. resolve `gitDir`
3. resolve `gitCommonDir`
4. derive `repoStateRoot`
5. derive `worktreeStateRoot`

If Git root resolution fails, report which root failed and whether the problem
is local to this worktree or repo-wide.

## Loading Mode

### Preferred mode: shared/session layout

If `{repoStateRoot}/config.json` exists, the repository is using the shared
state layout. That is the normal path for both primary and linked worktrees.

**Important:** a linked worktree is not degraded merely because the checkout
lacks a working-tree `.specwright/` directory. Shared repo state lives under
`repoStateRoot`, and session-local state lives under `worktreeStateRoot`.

### Migration fallback: legacy working-tree layout

If the shared/session layout is absent, callers may read legacy files from
`{projectRoot}/.specwright/` during migration:

- `{projectRoot}/.specwright/config.json`
- `{projectRoot}/.specwright/CONSTITUTION.md`
- `{projectRoot}/.specwright/CHARTER.md`
- `{projectRoot}/.specwright/TESTING.md`
- `{projectRoot}/.specwright/state/workflow.json`
- `{projectRoot}/.specwright/state/continuation.md`

Legacy `workflow.json` remains a migration-only bridge. It still uses the v2
`currentWork` wrapper, so work-aware callers must normalize that wrapper
explicitly or stop and direct the user to `/sw-init` before relying on work
status, branch, or unit fields.

Once either new logical root exists, writes go only to the new layout. Mixed
read/write behavior is forbidden.

## Session And Work Resolution

State-aware callers resolve the selected work in this order:

1. explicit selector, if the skill introduces one
2. `{worktreeStateRoot}/session.json.attachedWorkId`
3. legacy fallback during migration only

Session-aware callers also read:

- `session.json.mode` to distinguish `top-level` from `subordinate`
- `session.json.branch` to compare the current checkout with the attached work
- `session.json.lastSeenAt` for freshness and repair logic

If no work can be resolved for an operation that requires one, STOP with:

> "Run /sw-design first."

## Initialization Checks

Before any operation:

```javascript
resolveLogicalRoots();

if (exists(repoStateRoot + "/config.json")) {
  config = read(repoStateRoot + "/config.json");
} else if (exists(projectRoot + "/.specwright/config.json")) {
  config = read(projectRoot + "/.specwright/config.json"); // migration only
  warn("Using legacy working-tree Specwright layout — run /sw-init to migrate shared/session roots.");
} else {
  error("Run /sw-init first.");
}

if (!config.version) {
  warn("Config missing version field — re-run /sw-init to upgrade.");
}
```

`config.version` validates the config document only. It does not advertise the
selected work's workflow schema version, so callers detect legacy versus
shared/session state layout from the resolved roots above, not by comparing
`config.version` to `workflow.json.version`.

Before work-aware operations:

```javascript
session = readIfExists(worktreeStateRoot + "/session.json");
workId = explicitSelector || session?.attachedWorkId || legacyFallbackWorkId;

if (requiresWorkUnit && !workId) {
  error("Run /sw-design first.");
}
```

## Worktree Modes

| Mode | Source | Behavior |
|---|---|---|
| `top-level` | normal user-facing worktree | may own one attached work and mutate its workflow state |
| `subordinate` | internal helper worktree such as `parallel-build` | may inherit context, but does not claim top-level ownership or rewrite shared work selection |

Skills that require top-level ownership must enforce it explicitly. They must
not infer "top-level" from the absence of a linked-worktree marker.

## Loading Strategy

Always load:

- `config.json`
- `session.json` for session-aware operations

Load on demand:

- the selected work's `workflow.json`
- `CONSTITUTION.md`, `CHARTER.md`, `TESTING.md`
- work-local artifacts for the selected work and unit

Read-only repo-wide views such as `sw-status`, `sw-sync`, and `sw-doctor` may
enumerate all works from `{repoStateRoot}/work/*/workflow.json` in addition to
reading the current session.

## Error Handling

If required context is missing:

1. stop immediately
2. say which logical root or file could not be resolved
3. say whether legacy fallback was attempted
4. indicate which command or repair path should run next

Failures that are local to the current worktree should say so explicitly rather
than implying the whole repository is broken.
