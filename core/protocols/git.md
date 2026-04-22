# Git Operations Protocol

All git behavior is driven by the `git` section of `config.json`. Nothing is
hardcoded.

## Config Schema

```json
{
  "git": {
    "strategy": "trunk-based",
    "baseBranch": "main",
    "targets": {
      "defaultRole": "integration",
      "roles": {
        "integration": { "branch": "main" },
        "release": { "branch": "main" },
        "maintenance": { "pattern": "release/*" }
      }
    },
    "freshness": {
      "validation": "branch-head",
      "reconcile": "rebase",
      "checkpoints": {
        "build": "require",
        "verify": "require",
        "ship": "require"
      }
    },
    "workArtifacts": {
      "mode": "clone-local",
      "trackedRoot": null
    },
    "branchPrefix": "feat/",
    "mergeStrategy": "squash",
    "prRequired": true,
    "commitFormat": "conventional",
    "commitTemplate": null,
    "branchPerWorkUnit": true,
    "cleanupBranch": true,
    "prTool": "gh"
  }
}
```

| Field | Type | Default | Description |
|---|---|---|---|
| `strategy` | enum | `trunk-based` | `trunk-based`, `github-flow`, `gitflow`, `custom` |
| `baseBranch` | string | `main` | compatibility alias for the default integration branch |
| `targets` | object | see above | canonical branch-role defaults used to resolve work-level target refs |
| `freshness` | object | see above | canonical checkpoint policy for build, verify, and ship freshness checks |
| `workArtifacts` | object or null | `null` (`clone-local`) | optional publication mode for auditable work artifacts |
| `branchPrefix` | string | `feat/` | prefix for feature branches |
| `mergeStrategy` | enum | `squash` | `squash`, `rebase`, `merge` |
| `prRequired` | boolean | `true` | whether PRs are required for shipping |
| `commitFormat` | enum | `conventional` | `conventional`, `freeform`, `custom` |
| `commitTemplate` | string | `null` | template for `custom` format |
| `branchPerWorkUnit` | boolean | `true` | create a branch per work unit |
| `cleanupBranch` | boolean | `true` | delete branch after merge |
| `prTool` | string | `gh` | CLI tool for PR creation |

## Branch Role Defaults And Freshness Policy

`git.targets` and `git.freshness` are the canonical config surfaces for branch
targeting and checkpoint policy.

`git.targets` stays intentionally small:

- `defaultRole` selects the role used when the work does not specify one
- `roles.{role}.branch` sets a concrete default branch such as `main` or `develop`
- `roles.{role}.pattern` allows constrained families such as `release/*`

Pattern-based defaults are templates, not autonomous selectors. `sw-design`
may resolve a `roles.{role}.pattern` entry automatically only when exactly one
remote branch matches. Zero or multiple matches require an explicit user choice
so the work records a concrete `targetRef.branch` instead of guessing.

`git.baseBranch` remains supported as a compatibility alias for the default
integration branch. Writers should prefer `git.targets.roles.integration.branch`
when the expanded shape exists, but readers must keep honoring `baseBranch`
during migration.

`git.freshness` defines the lifecycle policy that later stages resolve onto the
selected work:

- `validation`: `branch-head` or `queue`
- `reconcile`: `manual`, `rebase`, or `merge`
- `checkpoints.build|verify|ship`: `ignore`, `warn`, or `require`

This keeps the branch-target model explicit without introducing a custom branch
DSL.

## Work-Artifact Publication Mode

`git.workArtifacts` is the canonical config surface for optional auditable work
artifacts. It is optional; when omitted, those artifacts remain clone-local.

Supported shape:

- `mode`: `clone-local` or `tracked`
- `trackedRoot`: repo-relative path required when `mode = tracked`

Semantics:

- `clone-local` resolves `workArtifactsRoot = {repoStateRoot}/work` and keeps
  optional auditable work artifacts under clone-local Specwright state. They do
  not become tracked project files by default.
- `tracked` resolves `workArtifactsRoot = {projectRoot}/{trackedRoot}` and
  publishes only the optional auditable work artifacts under that explicit
  tracked root inside `projectRoot`.
- `trackedRoot` must not point at `.git`, `repoStateRoot`,
  `worktreeStateRoot`, session state, or a symlinked mirror of those runtime
  roots.
- This setting does not move project-level artifacts such as `config.json`,
  `CONSTITUTION.md`, `CHARTER.md`, or `TESTING.md`; those remain under
  `projectArtifactsRoot` regardless of work-artifact publication mode.

## Logical Roots And Selected Work

Git operations that participate in the Specwright workflow use the same logical
roots as `protocols/context.md` and `protocols/state.md`:

| Root | Resolution | Purpose |
|---|---|---|
| `projectRoot` | `git rev-parse --show-toplevel` | checkout path and command cwd |
| `projectArtifactsRoot` | `{projectRoot}/.specwright` | tracked config and anchor docs |
| `repoStateRoot` | `git rev-parse --git-common-dir` + `/specwright` | shared runtime work records |
| `worktreeStateRoot` | `git rev-parse --git-dir` + `/specwright` | current session record |
| `workArtifactsRoot` | `{repoStateRoot}/work` or `{projectRoot}/{trackedRoot}` | auditable work artifacts for the selected work |

The selected work comes from `worktreeStateRoot/session.json.attachedWorkId`
unless a later skill introduces an explicit selector.

## Branch Ownership Rules

Top-level Git workflow operations apply only when all of the following are
true:

1. the current session exists and `session.json.mode == "top-level"`
2. the session is attached to the selected work
3. the selected work's `workflow.json.attachment.worktreeId` matches the
   current session's `worktreeId`
4. no other live top-level session claims that work

If any check fails, STOP with explicit adopt/takeover guidance. Do not allow
two top-level worktrees to mutate or ship the same work silently.

Subordinate sessions may create temporary helper branches for orchestration,
but they must not push, verify, or ship the parent work directly.

## Branch Lifecycle

If the selected work already records `targetRef`, branch setup uses that
concrete target before falling back to `git.targets` defaults or the
`baseBranch` compatibility alias.

**Create** (at build start):

```bash
TARGET_REMOTE="{resolved target remote}"
TARGET_BRANCH="{resolved target branch}"
git fetch "$TARGET_REMOTE"
git checkout "$TARGET_BRANCH"
git pull --ff-only "$TARGET_REMOTE" "$TARGET_BRANCH"
git checkout -b {config.git.branchPrefix}{work-or-unit-id}
```

If the branch already exists during recovery, switch to it instead of creating
it again.

When a branch becomes the active branch for a work:

- record it in the selected work's `workflow.json.branch`
- mirror the current branch in `session.json.branch`

Branch names remain config-driven. Specwright must not hardcode `main`, a
single remote, or a single unit naming scheme outside the config contract.

## Lifecycle Freshness Checkpoints

Lifecycle skills consume the shared freshness contract from
`protocols/git-freshness.md`; this protocol defines when each stage performs the
check and which target it uses.

- `sw-build` consumes the `build` checkpoint after branch setup, using the
  selected work's recorded target before any fallback defaults.
- `sw-verify` consumes the `verify` checkpoint before gate execution.
- `sw-ship` consumes the `ship` checkpoint during shipping pre-flight, before
  push or PR creation.

For `branch-head` validation, the stage interprets stale, diverged, and blocked
results according to the checkpoint policy:

- `require` stops the stage
- `warn` records advisory drift and continues
- `ignore` continues without escalation

When `rebase` or `merge` reconcile is configured, the blocked lifecycle stage
may use `protocols/git-reconcile.md` to perform `rebase` or `merge`
reconcile in-place. `manual` remains the explicit fallback and
stops with operator guidance.

Queue-managed results stay distinct from local rewrite policy. Skills may
surface queue status, but they must not silently rebase or merge the selected
work just to satisfy queue validation.

## Strategy: Branch + PR Targets

Read `config.git.strategy`:

| Strategy | Branch from | PR targets | Merge style |
|---|---|---|---|
| `trunk-based` | base branch | base branch | squash (default) |
| `github-flow` | base branch | base branch | merge or squash |
| `gitflow` | `develop` | `develop` (feature), `main` (release) | merge |
| `custom` | ask user | ask user | ask user |

For `custom` strategy: prompt the user for operations that are not derivable
from config.

`sw-init` and `sw-guard` seed or migrate `git.targets` and `git.freshness`
from the detected workflow strategy. `sw-design` then resolves the selected
work's concrete `targetRef` from those defaults instead of inferring a target
from the current checkout alone.

## Staging Rules

Always stage specific files by path:

```bash
git add src/foo.ts core/protocols/git.md
```

Never use:

- `git add -A`
- `git add .`
- `git add --all`

## Blocked Operations

Never run these commands:

- `git worktree prune`
- `git worktree remove --force`
- `git checkout .`
- `git restore .`

These are destructive to worktree safety or working state.

## Commit Format

Read `config.git.commitFormat`.

**conventional** (default):

```text
{type}({scope}): {description}
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`.

**freeform:** no enforced structure.

**custom:** use `config.git.commitTemplate`.

Always use a heredoc for the commit message:

```bash
git commit -m "$(cat <<'EOF'
feat(scope): description

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Commit Recovery

If `git commit` fails and the output shows formatter-like rewrites, re-stage
only the affected paths and retry once. If the second attempt fails, stop and
show the error.

## Push

Only the attached top-level owner of a work may push its workflow branch:

```bash
git push -u origin {branch}
```

If the session branch does not match the selected work's recorded branch,
STOP and surface the mismatch before any push.

## PR Creation

PR creation is allowed only when all of the following are true:

1. the selected work's `workflow.json.status` is `shipping`
2. the current session is `top-level`
3. the current session is attached to that work
4. the work's recorded attachment still points at this worktree
5. the current branch matches the selected work's recorded branch

If any prerequisite fails, STOP with:

> "PR creation requires the attached work to be in shipping state and owned by this top-level worktree. Run /sw-verify then /sw-ship from the owning checkout."

Read `config.git.prTool` (default: `gh`).
If `config.git.prRequired` is false, ask the user for preference.

```bash
gh pr create --title "{title}" --base {target} --body "$(cat <<'EOF'
{body}
EOF
)"
```

PR title follows the configured commit format style.

## Cleanup

After merge, if `config.git.cleanupBranch` is true:

- delete the local feature branch with `git branch -d`
- delete the remote branch only if it still exists
- prune stale remote refs
- sync the base branch with `--ff-only`

Never delete branches referenced by live sessions or subordinate worktrees.

For sync-oriented cleanup flows such as `sw-sync`:

- keep `git branch -d` as the default delete path
- allow `git branch -D` only for branches flagged `[gone]`
- require an explicit second confirmation before any `[gone]`-only `git branch -D`
- never use `git branch -D` for merged-only, protected, invalid, or
  live-session-owned branches
