# Research Brief: Generalisable Workflow Commands

Topic-ID: workflow-commands
Created: 2026-03-23
Updated: 2026-03-23
Tracks: 4

## Summary

Research into how proposed Specwright commands (`/review-pr`, `/sync`, `/sw-verify --fix`,
broadcast) can be designed generalisably across git workflow models. Investigated 5 git
workflow models, PR review APIs across GitHub/GitLab, auto-fix UX patterns from 7 quality
tools, and multi-project orchestration patterns from 8+ tools. Key finding: config-driven
workflow abstraction (git-town model) is the proven pattern for portability.

## Findings

### Track 1: Git Workflow Model Diversity

#### F1: Five workflow models have distinct sync, review, and cleanup primitives
- **Claim**: Trunk-based, GitHub Flow, GitFlow, forking, and release-train models differ
  in target branch (main vs. develop), sync strategy (rebase vs. merge vs. no-ff), remote
  topology (origin-only vs. origin+upstream), and stale branch detection method.
- **Evidence**: Trunk-based uses single main target with rapid integration. GitFlow uses
  develop as integration target with `--no-ff` merges. Forking model uses two remotes
  (origin + upstream). Release trains use permanent environment branches that are never deleted.
- **Source**: trunkbaseddevelopment.com, nvie.com, docs.github.com, about.gitlab.com/topics/version-control/what-is-gitlab-flow/
- **Confidence**: HIGH
- **Potential assumption**: no

#### F2: git-town provides the reference model for workflow-agnostic git commands
- **Claim**: git-town abstracts across all 5 models using typed branch categories (main,
  perennial, feature, contribution, observed) with configurable sync strategies per type.
  `sync-feature-strategy` (merge/rebase/compress), `sync-upstream` (boolean for fork model),
  and perennial branch names (configurable) are the key knobs.
- **Evidence**: git-town docs: "sync-feature-strategy: merge (default), rebase, or compress."
  Branch types control sync source, push behavior, and auto-delete policy. The `--gone` flag
  on sync removes branches whose remote tracking was deleted.
- **Source**: git-town.com/branch-types.html, git-town.com/preferences/sync-feature-strategy.html
- **Confidence**: HIGH
- **Potential assumption**: no

#### F3: Stale branch detection requires two methods depending on merge strategy
- **Claim**: `git branch --merged <branch>` is reliable for merge-commit workflows but
  unreliable after rebase (different SHAs). `git fetch --prune` + `[gone]` detection
  (via `git branch -vv | grep '\[gone\]'`) works for all models but only catches branches
  whose remote tracking was removed. A generalisable sync must support both.
- **Evidence**: git-scm.com: "The pruning feature doesn't actually care about branches,
  instead it'll prune local ←→ remote-references." git-town uses `--gone` for rebase
  workflows. GitHub auto-deletes remote branches on PR merge; `fetch --prune` + `[gone]`
  then catches them locally.
- **Source**: git-scm.com/docs/git-fetch, git-town.com/commands/sync.html
- **Confidence**: HIGH
- **Potential assumption**: no

#### F4: GitHub and GitLab differ in merge strategy configuration and enforcement
- **Claim**: GitHub allows 3 merge strategies per PR (author chooses). GitLab enforces
  a single merge method per project (admin sets). GitLab 18.0+ auto-rebases for
  semi-linear and fast-forward methods. GitHub requires manual rebase.
- **Evidence**: GitLab docs: "Merge methods — Merge commit, Semi-linear history, Fast-forward."
  GitHub docs: "Allow merge commits, Allow squash merging, Allow rebase merging" as
  independent toggles.
- **Source**: docs.gitlab.com/user/project/merge_requests/methods/, docs.github.com/en/repositories
- **Confidence**: HIGH
- **Potential assumption**: no

### Track 2: PR Review Automation Patterns

#### F5: GitHub exposes 3 distinct comment types across different API namespaces
- **Claim**: Issue comments (PR-level discussion), review comments (inline/diff), and
  reviews (container objects with verdict) use different REST endpoints. Thread resolution
  status (`isResolved`) requires GraphQL — it is not available via REST.
- **Evidence**: REST: `/issues/{n}/comments`, `/pulls/{n}/comments`, `/pulls/{n}/reviews`.
  GraphQL: `PullRequestReviewThread.isResolved`. Community discussion #9175 confirms:
  "there is no way to find out which conversation is resolved/unresolved through the
  github [REST] api."
- **Source**: docs.github.com/en/rest/pulls/comments, docs.github.com/en/graphql/reference/objects
- **Confidence**: HIGH
- **Potential assumption**: no

#### F6: gh CLI cannot list inline review comments or thread resolution status
- **Claim**: `gh pr view --json comments` returns only PR-level issue comments, not
  inline review comments. No command exists to list review threads, reply to specific
  threads, or compose pending reviews. This is tracked as issue cli/cli#12232.
- **Evidence**: Issue #12232: "Reading and replying can leverage REST endpoints" but
  "True pending-review composition...is best supported via GraphQL mutations."
- **Source**: github.com/cli/cli/issues/12232
- **Confidence**: HIGH
- **Potential assumption**: no

#### F7: Bot comment deduplication requires editing a single comment rather than creating new ones
- **Claim**: Both Danger.js and Prow use a "post once, edit on subsequent runs" pattern
  to avoid notification spam. Danger.js identifies its own comment by bot user ID. Prow
  posts a single approval-status comment updated as approvals arrive.
- **Evidence**: Danger.js has documented breakage when using a GitHub App instead of a bot
  user (issues #936, #1054). Prow explicitly edits its approval-tracking comment.
- **Source**: github.com/danger/danger-js, docs.prow.k8s.io
- **Confidence**: HIGH
- **Potential assumption**: no

#### F8: Prow's `/command` model separates LGTM from approval with ownership enforcement
- **Claim**: Prow uses `/lgtm` (any collaborator) and `/approve` (OWNERS file approvers
  only) as distinct actions. `/lgtm` is automatically revoked on new commits. PR authors
  cannot `/lgtm` their own PR. This separation enables accountability.
- **Evidence**: Prow docs: "The /lgtm must be renewed whenever the Pull Request changes."
  OWNERS files define per-directory approval authority.
- **Source**: docs.prow.k8s.io/docs/components/plugins/approve/approvers/
- **Confidence**: HIGH
- **Potential assumption**: no

#### F9: GitLab uses discussions/notes model with per-note resolution
- **Claim**: GitLab's thread model differs from GitHub. Resolution is per-note via
  `resolved` boolean on `DiffNote` types. Only diff notes are resolvable; standalone
  notes are not. The discussions API is the primary interface: `PUT .../discussions/:id`
  with `resolved: true`.
- **Evidence**: GitLab docs: discussions API returns `individual_note` (boolean),
  notes have `resolvable` and `resolved` fields.
- **Source**: docs.gitlab.com/api/discussions/
- **Confidence**: HIGH
- **Potential assumption**: no

#### F10: "New since last check" requires `since` parameter or diff-aware filtering
- **Claim**: GitHub's comment endpoints support `since` (ISO 8601) for incremental polling.
  reviewdog takes a different approach: filtering linter output against the PR diff to
  report only findings in changed code. Both patterns avoid re-processing all comments.
- **Evidence**: GitHub REST: "Parameters: since — Only show results that were last updated
  after the given time." reviewdog: filters against PR diff to avoid pre-existing violations.
- **Source**: docs.github.com/en/rest/pulls/comments, github.com/reviewdog/reviewdog
- **Confidence**: HIGH
- **Potential assumption**: no

### Track 3: Auto-Fix UX Patterns

#### F11: Industry converges on binary safe/unsafe fix taxonomy
- **Claim**: ESLint (fixable vs. suggestion), RuboCop (safe vs. unsafe autocorrect),
  Ruff (safe vs. unsafe fixes), and cargo clippy (MachineApplicable vs. MaybeIncorrect)
  all use a binary distinction. Safe = auto-applied. Unsafe = requires explicit opt-in.
- **Evidence**: Ruff: "Safe fixes: the meaning and intent of your code will be retained."
  RuboCop: `-a` for safe, `-A` for all including unsafe. Clippy: only MachineApplicable
  applied by default.
- **Source**: docs.astral.sh/ruff/linter/, docs.rubocop.org, doc.rust-lang.org/clippy/usage.html
- **Confidence**: HIGH
- **Potential assumption**: no

#### F12: Ruff has the clearest partial-result communication model
- **Claim**: Ruff outputs `Found N errors (M fixed, K remaining)` with exit codes
  encoding fix status. `--show-fixes` enumerates fixed violations. `--fix-only`
  applies fixes without reporting remaining. `--exit-non-zero-on-fix` signals that
  changes were made.
- **Evidence**: Ruff docs: exit code 0 = no violations remain, 1 = unfixed violations
  remain, 2 = abnormal termination.
- **Source**: docs.astral.sh/ruff/linter/
- **Confidence**: HIGH
- **Potential assumption**: no

#### F13: Overlapping fixes cause corruption without conflict resolution
- **Claim**: golangci-lint documented an incident where overlapping fixes from
  multiple linters deleted code (issue #3819). ESLint handles this by applying
  only one fix when spans overlap, leaving the other reported. Clippy and RuboCop
  do not document conflict resolution.
- **Evidence**: golangci-lint issue #3819: gocritic and gofumpt conflicted on comment
  formatting, deleting entire lines. PR #5232 added span-based deconfliction.
- **Source**: github.com/golangci/golangci-lint/issues/3819
- **Confidence**: HIGH
- **Potential assumption**: no

#### F14: CI/CD consensus is check-mode + fail-fast, not auto-commit
- **Claim**: The dominant CI pattern is linter-in-check-mode (fail the build) with
  fixes applied locally. Auto-commit tools (lint-action, autofix.ci) exist but are
  scoped to formatting-only. autofix.ci includes loop prevention (no patches if
  last 4 commits are bot-authored).
- **Evidence**: lint-action limits auto-fix to PR branches, not main. Copilot Autofix
  docs explicitly acknowledge partial fixes. Community consensus: auto-commit viable
  for formatting, not for semantic fixes.
- **Source**: github.com/wearerequired/lint-action, docs.github.com/en/code-security
- **Confidence**: HIGH
- **Potential assumption**: no

#### F15: No tool has built-in rollback — version control is the expected undo
- **Claim**: None of the 7 tools surveyed (ESLint, Prettier, cargo clippy, RuboCop,
  Ruff, golangci-lint, SonarQube) have built-in backup or rollback. All modify files
  in place. Git is the assumed rollback mechanism.
- **Evidence**: RuboCop docs: "Always review the diff and run your test suite after
  autocorrecting." ESLint: no backup, files modified in place.
- **Source**: docs.rubocop.org, eslint.org
- **Confidence**: HIGH
- **Potential assumption**: no

### Track 4: Multi-Project Orchestration

#### F16: Polyrepo tools use explicit repo lists with script-based changes
- **Claim**: multi-gitter discovers repos via org, user, topic, or explicit list,
  then runs arbitrary scripts in cloned repos. Changes are committed and PR'd per repo.
  Renovate discovers package manifests automatically and uses a 9-layer config hierarchy
  with org-level preset inheritance.
- **Evidence**: multi-gitter: 6 targeting mechanisms (org, user, topic, search, explicit,
  regex filter). Renovate: org-level config via `{org}/renovate-config/org-inherited-config.json`.
- **Source**: github.com/lindell/multi-gitter, docs.renovatebot.com/config-overview/
- **Confidence**: HIGH
- **Potential assumption**: no

#### F17: Failure handling splits into fail-fast vs. continue-on-error
- **Claim**: Turborepo offers 3 modes: `never` (fail-fast), `dependencies-successful`
  (skip downstream), `always` (run all). Lerna: `--no-bail` for continue-on-error.
  Nx: `--nxBail` for fail-fast. multi-gitter: per-repo isolation with skip-on-conflict.
- **Evidence**: Turborepo docs: `--continue=dependencies-successful` runs tasks whose
  dependencies all passed. Lerna: "Pass --no-bail to run in all packages regardless of
  exit code."
- **Source**: turborepo.dev/docs/reference/run, lerna.js.org/docs/features/run-tasks
- **Confidence**: HIGH
- **Potential assumption**: no

#### F18: Dry-run / preview is available in Turborepo, multi-gitter, Renovate — not in Nx run-many or Lerna
- **Claim**: Turborepo's `--dry` shows task details without executing. multi-gitter's
  `--dry-run` runs scripts locally without committing or creating PRs. Renovate's
  `--dry-run` logs what would be done. Nx has dry-run only on `nx release`, not `run-many`.
  Lerna has no documented dry-run.
- **Evidence**: Turborepo: "--dry-run shows task execution details (taskId, hash, command,
  inputs, outputs, dependencies) without executing."
- **Source**: turborepo.dev/docs/reference/run, github.com/lindell/multi-gitter
- **Confidence**: HIGH
- **Potential assumption**: no

#### F19: Config drift is the #1 documented anti-pattern in multi-repo tooling
- **Claim**: AWS Well-Architected, GitHub's polyrepo guidance, and HashiCorp all identify
  config drift as the primary multi-repo risk. Documented mitigations: shared presets with
  explicit inheritance (Renovate), semantic versioning of shared resources with pinned
  references, and org-level policy enforcement (GitHub Enterprise, GitLab groups).
- **Evidence**: AWS: anti-patterns for software component management. GitHub Well-Architected:
  "Ad-hoc coordination via Slack/spreadsheets loses auditability." Renovate: org-level
  presets solve this for dependency config.
- **Source**: docs.aws.amazon.com/wellarchitected, wellarchitected.github.com, docs.renovatebot.com
- **Confidence**: HIGH
- **Potential assumption**: no

#### F20: Backstage and Port delegate cross-repo operations to external backends
- **Claim**: Neither Backstage nor Port have native "fan out to N repos" primitives.
  Backstage scaffolds new repos via templates. Port triggers actions (GitHub Actions,
  webhooks) that backends must implement. Multi-repo operations are achieved by the
  backend, not the platform.
- **Evidence**: Backstage: `publish:github:pull-request` opens a PR in one repo per
  template execution. Port: "loosely coupled to your infrastructure — the platform
  sends a payload to the configured backend."
- **Source**: backstage.io/docs/features/software-templates/, docs.port.io
- **Confidence**: MEDIUM
- **Potential assumption**: yes — Backstage may have evolved since research; community plugins could add bulk operations

## Conflicts & Agreements

### Agreements
- **All tracks**: Config-driven abstraction over workflow-specific primitives is the
  industry pattern. git-town, Renovate presets, Turborepo config inheritance, and
  GitHub Actions reusable workflows all solve "same operation, different context"
  through configuration, not code branching.
- **Tracks 3 & 1**: Auto-fix and sync both require a safety taxonomy. Fixes have
  safe/unsafe. Sync has merge/rebase/compress. Both need explicit user-facing config
  with safe defaults.
- **Tracks 2 & 4**: Both PR review and broadcast need platform abstraction. GitHub
  and GitLab have fundamentally different comment/thread models. Multi-repo tools
  that hardcode GitHub API calls cannot support GitLab.

### Conflicts
- **Track 1 vs. Track 3**: git-town's `sync` command is opinionated about stale branch
  cleanup (auto-deletes with `--gone`). The auto-fix research shows that aggressive
  auto-cleanup has corruption risk (golangci-lint #3819). A `/sync` command should
  default to preview before deleting.
- **Track 2**: Danger.js edits-in-place vs. Prow's command model represent different
  philosophies. Danger is CI-triggered and bot-authored. Prow is human-triggered via
  comment commands. Specwright's `/review-pr` is human-triggered but delegates to an
  AI agent — a hybrid model not directly represented in existing tools.

## Open Questions

1. Should `/review-pr` use `gh api` for REST + GraphQL, or depend on a higher-level
   abstraction? The gh CLI gap (no inline comments, no thread resolution) means raw API
   calls are needed regardless.
2. Should broadcast be atomic (all succeed or all rollback) or independent (continue-on-error)?
   No existing tool offers atomic cross-repo operations — multi-gitter and Renovate are
   both independent.
3. How should `/sync` handle protected branches? git-town skips perennial branches by
   design. GitHub auto-delete exempts protected branches. The command must not delete
   branches the user intends to keep.
4. Should `/sw-verify --fix` distinguish between BLOCK (must fix) and WARN (judgment call)
   findings? The auto-fix research shows safe/unsafe as the dominant pattern. Mapping:
   BLOCK → auto-fix if possible, WARN → present for judgment.
5. Most Specwright users are assumed to use GitHub. If GitLab support is needed, the
   comment model abstraction is non-trivial (3 comment types + GraphQL on GitHub vs.
   discussions/notes on GitLab).
