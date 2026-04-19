# Research Brief: Specwright Git Worktree State Flexibility

Topic-ID: worktree-safety
Created: 2026-03-31
Updated: 2026-04-10
Tracks: 3

## Summary

This research checked whether Specwright's current git and state protocols are flexible enough to survive alternate git operating modes, especially linked worktrees, without state-management breakpoints. Git itself provides first-class shared-versus-per-worktree primitives, and Specwright already uses some configurable git workflow controls, but current Tier A skills still depend on checkout-local `.specwright/` files and therefore break when that directory is absent in a linked worktree.

## Findings

### Track 1: Git's Native Model For Shared And Per-Worktree State

#### F1: Git exposes distinct shared and per-worktree locations instead of treating a linked worktree as a second-class checkout
- **Claim**: Git explicitly distinguishes the repository's shared common directory from the current worktree's git directory, and exposes both through `git rev-parse`.
- **Evidence**: Official `git rev-parse` documentation states that `--git-common-dir` shows `$GIT_COMMON_DIR` if defined, else `$GIT_DIR`, and that `--git-path <path>` resolves paths relative to `$GIT_DIR` while honoring relocated storage. `gitrepository-layout` separately documents `commondir` and `worktrees/`.
- **Source**: https://git-scm.com/docs/git-rev-parse ; https://git-scm.com/docs/gitrepository-layout
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-10
- **Potential assumption**: No

#### F2: Git supports worktree-specific configuration as a first-class feature, not a workaround
- **Claim**: Git can store per-worktree configuration in `config.worktree` when `extensions.worktreeConfig` is enabled, and `git config --worktree` writes to that location.
- **Evidence**: Official `git-worktree` and `git-config` documentation describe enabling `extensions.worktreeConfig`, locating the file via `git rev-parse --git-path config.worktree`, and reading it after the common config. The docs also note a compatibility tradeoff: older Git versions refuse repositories that enable this extension.
- **Source**: https://git-scm.com/docs/git-worktree ; https://git-scm.com/docs/git-config
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-10
- **Potential assumption**: No

#### F3: Git provides a machine-readable inventory of active worktrees for tooling
- **Claim**: `git worktree list --porcelain` is the supported machine-parseable interface for discovering active worktrees, branches, and lock state.
- **Evidence**: Official `git-worktree` documentation shows `list --porcelain` records with `worktree`, `HEAD`, `branch`, and optional `locked` fields, separated by blank lines.
- **Source**: https://git-scm.com/docs/git-worktree
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-10
- **Potential assumption**: No

#### F4: Git already separates some state by worktree and shares other state globally
- **Claim**: Git's own ref model is hybrid: pseudo-refs like `HEAD` are per-worktree, while most `refs/*` are shared, with documented exceptions such as `refs/bisect`, `refs/worktree`, and `refs/rewritten`.
- **Evidence**: Official `git-worktree` documentation states that "all pseudo refs are per-worktree and all refs starting with refs/ are shared," then documents the exceptions.
- **Source**: https://git-scm.com/docs/git-worktree
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-10
- **Potential assumption**: No

### Track 2: Current Specwright Flexibility And Current Breakpoints

#### F5: Specwright's git workflow policy is already configurable across several common branching models
- **Claim**: Specwright does not hardcode a single branch model; its git protocol supports configurable `strategy`, `baseBranch`, `branchPrefix`, `mergeStrategy`, `prRequired`, and commit formatting.
- **Evidence**: `core/protocols/git.md` defines a config-driven schema with `trunk-based`, `github-flow`, `gitflow`, and `custom` strategies, plus configurable branch naming, PR requirements, and commit formats.
- **Source**: /Users/dmccarthy/Projects/specwright/core/protocols/git.md
- **Confidence**: HIGH
- **Version/Date**: Repository state accessed 2026-04-10
- **Potential assumption**: No

#### F6: Specwright's workflow state is checkout-local by protocol, not git-common-dir-aware
- **Claim**: Specwright's authoritative workflow state and artifact paths are fixed under `.specwright/` in the current checkout rather than being resolved through Git's shared/per-worktree path primitives.
- **Evidence**: `core/protocols/state.md` fixes the workflow state location at `.specwright/state/workflow.json` and resolves work artifacts from `.specwright/work/...`. `core/protocols/context.md` always loads `.specwright/config.json` from the current working tree.
- **Source**: /Users/dmccarthy/Projects/specwright/core/protocols/state.md ; /Users/dmccarthy/Projects/specwright/core/protocols/context.md
- **Confidence**: HIGH
- **Version/Date**: Repository state accessed 2026-04-10
- **Potential assumption**: No

#### F7: The linked-worktree verify breakpoint is an explicit protocol decision, not a Git limitation
- **Claim**: Specwright intentionally stops Tier A state-mutating skills in linked worktrees when `.specwright/config.json` is absent, even though Git can still identify the repository, common dir, and worktree-specific admin paths.
- **Evidence**: `core/protocols/context.md` defines the degradation rule: linked worktree plus missing `.specwright/config.json` causes Tier A skills including `sw-verify` to STOP with guidance. This is a policy choice in Specwright's context-loading protocol.
- **Source**: /Users/dmccarthy/Projects/specwright/core/protocols/context.md
- **Confidence**: HIGH
- **Version/Date**: Repository state accessed 2026-04-10
- **Potential assumption**: No

#### F8: Specwright is partially worktree-aware already, but only in narrow operational slices
- **Claim**: At least one skill already uses Git's worktree-aware primitives directly, which shows the codebase is not uniformly tied to single-worktree assumptions.
- **Evidence**: `core/skills/sw-sync/SKILL.md` requires `git worktree list --porcelain` for safety checks and excludes branches used by active worktrees from deletion candidates.
- **Source**: /Users/dmccarthy/Projects/specwright/core/skills/sw-sync/SKILL.md
- **Confidence**: HIGH
- **Version/Date**: Repository state accessed 2026-04-10
- **Potential assumption**: No

#### F9: Specwright supports isolated local state in a linked worktree, but not seamless continuation of shared active state across worktrees
- **Claim**: Current protocols allow a linked worktree to run `sw-init` and create its own local `.specwright/`, but they do not provide a shared-state handoff model for continuing the same active work across multiple worktrees.
- **Evidence**: `core/protocols/context.md` and `core/skills/sw-init/SKILL.md` explicitly allow local init in linked worktrees while warning that `.specwright/` created there "will not be visible in other worktrees."
- **Source**: /Users/dmccarthy/Projects/specwright/core/protocols/context.md ; /Users/dmccarthy/Projects/specwright/core/skills/sw-init/SKILL.md
- **Confidence**: HIGH
- **Version/Date**: Repository state accessed 2026-04-10
- **Potential assumption**: No

### Track 3: Reproduced Behavior In This Repository

#### F10: The current linked-worktree failure mode in this repo is caused by local state placement, and Git still exposes the necessary repository metadata
- **Claim**: In this repository, `.specwright/` is gitignored and absent from the linked worktree `specwright-codex-bug`, while Git continues to expose both shared and per-worktree locations from that checkout.
- **Evidence**: `.gitignore` contains `.specwright/`. In `/Users/dmccarthy/Projects/specwright-codex-bug`, `config.json`, `CONSTITUTION.md`, and `CHARTER.md` are missing. From that same worktree, `git rev-parse` reports top-level `/Users/dmccarthy/Projects/specwright-codex-bug`, git dir `/Users/dmccarthy/Projects/specwright/.git/worktrees/codex-bug`, common dir `/Users/dmccarthy/Projects/specwright/.git`, and worktree config path `/Users/dmccarthy/Projects/specwright/.git/worktrees/codex-bug/config.worktree`.
- **Source**: /Users/dmccarthy/Projects/specwright/.gitignore ; local command output from `git -C /Users/dmccarthy/Projects/specwright-codex-bug rev-parse ...` and file existence checks on 2026-04-10
- **Confidence**: HIGH
- **Version/Date**: Repository state accessed 2026-04-10 with `git version 2.48.1`
- **Potential assumption**: No

## Conflicts & Agreements

Git and Specwright agree on one important point: not all repository state should be global. Git natively keeps some information shared and some per-worktree, and Specwright already follows that idea informally by allowing linked worktrees to initialize isolated local `.specwright/` state.

The main conflict is that Specwright's state discovery does not yet use Git's native shared/per-worktree addressing model. Git can always tell a tool where the repository common dir, current worktree admin dir, and worktree-specific config live, but Specwright currently treats missing checkout-local `.specwright/config.json` as a hard stop for Tier A skills. That means current git workflow flexibility is real for branch naming and PR policy, but incomplete for state continuity across linked worktrees.

## Open Questions

1. Which Specwright artifacts are semantically shared across worktrees versus inherently per-worktree: `config.json`, anchor docs, `workflow.json`, lock state, continuation notes, and gate evidence?
2. Is seamless continuation of one active work unit across linked worktrees a requirement, or is "run `sw-init` separately for isolated worktree-local state" sufficient?
3. Is support for older Git versions that reject `extensions.worktreeConfig` still a hard compatibility requirement?
4. Should worktree detection and path resolution rely on Git commands such as `git rev-parse --git-common-dir` and `git rev-parse --git-path ...` rather than on manual parsing of the `.git` file contents?
