# Context Loading Protocol

## Logical Roots

Every skill, hook, and adapter resolves the same five logical roots on every
invocation:

| Root | Resolution | Purpose |
|---|---|---|
| `projectRoot` | `git rev-parse --show-toplevel` | source tree and user-facing cwd |
| `projectArtifactsRoot` | `{projectRoot}/.specwright` | tracked project artifacts and shared agent guidance |
| `repoStateRoot` | depends on `config.git.runtime.mode`: `git-admin` -> `git rev-parse --git-common-dir` + `/specwright`; `project-visible` -> `<git common-dir parent>/{config.git.runtime.projectVisibleRoot}/repo` | shared clone-local runtime state |
| `worktreeStateRoot` | depends on `config.git.runtime.mode`: `git-admin` -> `git rev-parse --git-dir` + `/specwright`; `project-visible` -> `<git common-dir parent>/{config.git.runtime.projectVisibleRoot}/worktrees/{worktreeId}` | per-worktree session and continuation state |
| `workArtifactsRoot` | clone-local mode follows the runtime mode: `git-admin` -> `{repoStateRoot}/work`, `project-visible` -> `<git common-dir parent>/{config.git.runtime.projectVisibleRoot}/work`; tracked publication uses `{projectRoot}/{config.git.workArtifacts.trackedRoot}` when configured | auditable work artifacts |

Callers must prefer those logical roots over hardcoded `.specwright/...` or
`.git/specwright/...` path concatenation.

## Runtime Mode Policy

The runtime-root policy surface lives under tracked config:

- `config.git.runtime.mode` — `git-admin` or `project-visible`
- `config.git.runtime.projectVisibleRoot` — repo-visible clone-local runtime
  root name, default `.specwright-local`

If the `runtime` block is absent, callers must default to `git-admin` for
backward compatibility with existing installs.

Runtime mode governs clone-local runtime placement only. Work-artifact
publication remains separate from runtime mode and is still controlled by
`config.git.workArtifacts`.

### Runtime Mode Mapping

| Mode | Runtime mapping |
|---|---|
| `git-admin` | `repoStateRoot = {gitCommonDir}/specwright`, `worktreeStateRoot = {gitDir}/specwright`, clone-local `workArtifactsRoot = {repoStateRoot}/work` |
| `project-visible` | shared runtime root = `<git common-dir parent>/{config.git.runtime.projectVisibleRoot}`, `repoStateRoot = {sharedRuntimeRoot}/repo`, `worktreeStateRoot = {sharedRuntimeRoot}/worktrees/{worktreeId}`, clone-local `workArtifactsRoot = {sharedRuntimeRoot}/work` |

Guardrails for `project-visible` mode:

In `project-visible` mode, the repo state root, worktree state root, and work
artifacts root all move under the shared runtime root instead of `.git`.
Project-visible maps the repo state root to `{sharedRuntimeRoot}/repo`, the
worktree state root to `{sharedRuntimeRoot}/worktrees/{worktreeId}`, and the
work artifacts root to `{sharedRuntimeRoot}/work`.

- the resolved `projectVisibleRoot` must stay clone-local and untracked by
  default
- it must resolve from the Git common-dir parent, not from `.git/`
- tracked project artifacts remain under `projectArtifactsRoot`
- tracked work-artifact publication, when enabled, remains independent from the
  runtime-mode root

## Standard Context Documents

### Tracked project artifacts

Load from `projectArtifactsRoot` when needed for alignment or verification:

- `{projectArtifactsRoot}/config.json` — tracked project settings, commands,
  gates, git, integration, and backlog settings
- `{projectArtifactsRoot}/CONSTITUTION.md` — development practices and
  principles
- `{projectArtifactsRoot}/CHARTER.md` — technology vision and project purpose
- `{projectArtifactsRoot}/TESTING.md` — testing strategy (optional; if absent,
  Constitution testing rules remain authoritative)
- `{projectArtifactsRoot}/LANDSCAPE.md` — codebase architecture and module
  knowledge (optional)
- `{projectArtifactsRoot}/AUDIT.md` — codebase health findings and tech debt
  tracking (optional)
- `{projectArtifactsRoot}/research/*.md` — external research briefs (loaded by
  `sw-design` on demand; warn if stale per `protocols/research.md`)

### Runtime work records

Load from the selected work under `repoStateRoot/work/{workId}`:

- `workflow.json` — lifecycle, gates, units, attachment, per-work lock
- `stage-report.md` — runtime-local stage handoff digest
- `units/{unitId}/stage-report.md` — runtime-local unit handoff digest

### Auditable work artifacts

Load from the selected work under `{workArtifactsRoot}/{workId}`:

- `design.md`, `context.md`, `decisions.md`, `assumptions.md`
- `approvals.md`, `integration-criteria.md`
- `units/{unitId}/spec.md`, `plan.md`, `context.md`
- `units/{unitId}/implementation-rationale.md`
- `units/{unitId}/review-packet.md`
- `units/{unitId}/evidence/`

### Per-worktree documents

Load from `worktreeStateRoot`:

- `session.json` — the current worktree's attached work, mode, branch, and
  `lastSeenAt`
- `continuation.md` — worktree-local continuation snapshot (optional)

## Root Resolution Sequence

Run this sequence before loading Specwright state:

1. resolve `projectRoot`
2. derive `projectArtifactsRoot`
3. resolve `gitDir`
4. resolve `gitCommonDir`
5. read `config.git.runtime` from `{projectArtifactsRoot}/config.json` when
   present; if the block is absent, default to `git-admin`
6. derive `repoStateRoot` and `worktreeStateRoot` from the resolved runtime
   mode and `worktreeId`
7. resolve `workArtifactsRoot`: keep tracked publication separate from runtime
   mode by reading `config.git.workArtifacts` from
   `{projectArtifactsRoot}/config.json` when present, else from
   `{repoStateRoot}/config.json`; default the clone-local path from the active
   runtime mode when the tracked mode is not configured

If Git root resolution fails, report which root failed and whether the problem
is local to this worktree or repo-wide.

## Loading Mode

### Tracked project-artifact root

If `{projectArtifactsRoot}/config.json` exists, that path is authoritative for
tracked project config and anchor docs.

If only `{repoStateRoot}/config.json` exists, callers may read it as a
compatibility bridge for migrated runtime state, but they should warn that the
tracked config has not yet been moved back to `projectArtifactsRoot`.

If callers fall all the way back to `{projectArtifactsRoot}/state/`, they
should explicitly say the repository is using the legacy working-tree Specwright layout.

### Preferred mode: shared/session runtime layout

If `{projectArtifactsRoot}/config.json` exists, `{worktreeStateRoot}/session.json`
exists, `{repoStateRoot}/work/` exists, or `{repoStateRoot}/config.json`
exists, the repository is using the shared/session root model. Tracked project
config alone is enough to opt into that model even before any work or session
file exists. That is the normal path for both primary and linked worktrees.

**Important:** a linked worktree is not degraded merely because the checkout
lacks a working-tree `.specwright/` directory. Shared repo state lives under
`repoStateRoot`, and session-local state lives under `worktreeStateRoot`.

### Migration fallback: legacy working-tree layout

If the shared/session runtime layout is absent, callers may read legacy runtime
files from `{projectArtifactsRoot}/state/` during migration:

- `{projectArtifactsRoot}/state/workflow.json`
- `{projectArtifactsRoot}/state/continuation.md`

Legacy `workflow.json` remains a migration-only bridge. It still uses the v2
`currentWork` wrapper, so work-aware callers must normalize that wrapper
explicitly or stop and direct the user to `/sw-init` before relying on work
status, branch, or unit fields.

Once the new roots exist, writes go only to their authoritative surface:

- tracked project artifacts -> `projectArtifactsRoot`
- auditable work artifacts -> `workArtifactsRoot`
- runtime work state -> `repoStateRoot`
- runtime session state -> `worktreeStateRoot`

Mixed read/write behavior is forbidden.

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

if (exists(projectArtifactsRoot + "/config.json")) {
  config = read(projectArtifactsRoot + "/config.json");
} else if (exists(repoStateRoot + "/config.json")) {
  config = read(repoStateRoot + "/config.json"); // compatibility bridge only
  warn("Using runtime-local config compatibility path — run /sw-init to migrate tracked config back to projectArtifactsRoot.");
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
- runtime `stage-report.md` digests from `repoStateRoot`
- auditable work artifacts for the selected work and unit from
  `workArtifactsRoot`

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
