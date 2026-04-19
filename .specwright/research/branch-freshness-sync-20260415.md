# Research Brief: Git Branch Freshness And Sync Patterns

Topic-ID: branch-freshness-sync
Created: 2026-04-15
Updated: 2026-04-15
Tracks: 3

## Summary

This research reviewed official Git, GitHub, and GitLab documentation on how parallel branches stay aligned with moving integration targets during worktree-based development and longer-lived release cycles. The sources agree that Git already provides worktree-safe upstream and sync primitives, while hosted platforms add branch-freshness enforcement, merged-result validation, and queue-based merge orchestration that reduce manual rebasing on busy target branches.

## Findings

### Git-Native Worktree And Sync Primitives

#### F1: Git treats linked worktrees as a mix of shared repository state and per-worktree state
- **Claim**: Linked worktrees share common repository data, but keep worktree-local state such as `HEAD`, index data, and worktree-specific config separate, and tooling should resolve those paths through Git rather than assuming fixed filesystem locations.
- **Evidence**: Official `git-worktree` and `git-config` documentation describe shared versus per-worktree files, explain `config.worktree`, and direct tools to use `git rev-parse --git-path` instead of manually deriving internal paths.
- **Source**: https://git-scm.com/docs/git-worktree ; https://git-scm.com/docs/git-config
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; `git-worktree` and `git-config` latest pages current through Git 2.53.0
- **Potential assumption**: No

#### F2: Git can create a worktree branch directly from a remote-tracking branch and wire upstream tracking automatically
- **Claim**: `git worktree add` can base a new branch on a uniquely matching remote-tracking branch and mark that remote-tracking branch as the new branch's upstream, and `worktree.guessRemote` can make that the default behavior.
- **Evidence**: The official `git-worktree` documentation describes automatic remote-tracking branch selection and upstream assignment during `worktree add`, plus the `worktree.guessRemote` configuration option.
- **Source**: https://git-scm.com/docs/git-worktree
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; `git-worktree` latest page current through Git 2.53.0
- **Potential assumption**: No

#### F3: Upstream tracking is the documented mechanism Git uses for default sync behavior on a branch
- **Claim**: Git records upstream relationships with `branch.<name>.remote` and `branch.<name>.merge`, and then uses that relationship for `git pull` without arguments, ahead/behind reporting, and related branch status commands.
- **Evidence**: Official `git-branch` documentation describes `--track` and `--set-upstream-to`, while `git-pull` documents that pull without explicit refs defaults to the current branch's configured upstream.
- **Source**: https://git-scm.com/docs/git-branch ; https://git-scm.com/docs/git-pull
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; latest pages current through Git 2.53.0
- **Potential assumption**: No

#### F4: Git's documented sync choices are explicitly different and safe to abort when conflicts occur
- **Claim**: `git pull` is defined as fetch-then-integrate, and the documented integration choices are fast-forward only, rebase, merge, or squash; Git also documents safe abort paths for merge and rebase conflicts.
- **Evidence**: Official `git-pull` documentation states that pull first runs fetch, then integrates the upstream using one of several modes, and notes that conflicted merge or rebase operations can be aborted safely.
- **Source**: https://git-scm.com/docs/git-pull
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; latest page current through Git 2.53.0
- **Potential assumption**: No

#### F5: Git provides stale remote-ref cleanup, but pruning follows the configured refspec
- **Claim**: `git fetch --prune` and `fetch.prune=true` remove stale remote-tracking refs, but the prune behavior follows the remote's refspecs rather than a special branch-only cleanup path.
- **Evidence**: Official `git-fetch` documentation explains one-off and configured pruning, warns that pruning behavior follows the refspec, and describes remote-tracking refs as the normal outcome of repeated fetches.
- **Source**: https://git-scm.com/docs/git-fetch
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; latest page current through Git 2.53.0
- **Potential assumption**: No

#### F6: Git protects checked-out worktree branches from force-moving branch tips elsewhere
- **Claim**: Git refuses to force-move a branch with `git branch -f` when that branch is checked out in another linked worktree.
- **Evidence**: Official `git-branch` documentation states that force-resetting a branch tip is refused if the branch is checked out in another worktree, even with force.
- **Source**: https://git-scm.com/docs/git-branch
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; latest page current through Git 2.53.0
- **Potential assumption**: No

### Long-Running Topic, Integration, And Release Branch Cycles

#### F7: Git's own workflow guidance uses multiple branch roles rather than a single universal integration branch
- **Claim**: Official Git workflow guidance distinguishes maintenance, feature-release, and integration/testing branches, with topics graduating upward as they stabilize.
- **Evidence**: `gitworkflows` documents the `maint`, `master`, `next`, and `seen` roles in the `git.git` project and describes features entering less-stable branches before graduating to more stable branches.
- **Source**: https://git-scm.com/docs/gitworkflows
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; `gitworkflows` page current through Git 2.35.0
- **Potential assumption**: No

#### F8: Git recommends branching each topic from the oldest integration branch that will eventually receive it
- **Claim**: Git's official workflow guidance says every feature or fix should use a topic branch, and that branch should start from the oldest integration branch into which it will later merge.
- **Evidence**: `gitworkflows` explicitly recommends making a side branch for each topic and choosing the oldest compatible base branch.
- **Source**: https://git-scm.com/docs/gitworkflows
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; `gitworkflows` page current through Git 2.35.0
- **Potential assumption**: No

#### F9: Git's documented release maintenance rule is to merge fixes upward and cherry-pick only for selective backports
- **Claim**: Official workflow guidance says changes should normally be fixed on the oldest supported branch that needs them and then merged upward, while cherry-pick is the documented tool for carrying a newer fix down to an older maintenance line when needed.
- **Evidence**: `gitworkflows` has a specific "merge upwards" rule and `git-cherry-pick` documents backporting a fix to a maintenance branch as a standard use case.
- **Source**: https://git-scm.com/docs/gitworkflows ; https://git-scm.com/docs/git-cherry-pick
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; latest pages current through Git 2.53.0
- **Potential assumption**: No

#### F10: Git's own rebase guidance says repeated rebasing onto a moving upstream is not always the best choice for long-running feature work
- **Claim**: `git rebase --keep-base` exists specifically for the case where upstream advances while a feature is in progress and the base commit should stay fixed rather than repeatedly rebasing onto the new upstream tip.
- **Evidence**: Official `git-rebase` documentation explains `--keep-base` as preserving the original merge-base while upstream moves forward and explicitly notes that repeated rebasing onto upstream may not be the best idea during ongoing feature development.
- **Source**: https://git-scm.com/docs/git-rebase
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; latest page current through Git 2.53.0
- **Potential assumption**: No

#### F11: Official Git release guidance expects maintenance and feature-release branches to stay ordered and verifiable
- **Claim**: Git's workflow guidance expects the main feature-release branch to be a superset of the maintenance branch and gives explicit verification and fast-forward update steps after a feature release.
- **Evidence**: `gitworkflows` describes checking that the feature-release branch contains the maintenance branch, tagging releases from the appropriate branch, and fast-forwarding maintenance after a feature release when appropriate.
- **Source**: https://git-scm.com/docs/gitworkflows
- **Confidence**: HIGH
- **Version/Date**: Git documentation accessed 2026-04-15; `gitworkflows` page current through Git 2.35.0
- **Potential assumption**: No

### Hosted Branch Freshness And Merge Automation

#### F12: GitHub supports strict branch freshness before merge and exposes a conditional branch-update action
- **Claim**: GitHub can require a pull request branch to be up to date with its base branch before merging, and the UI exposes `Update branch` only when the head branch is stale, conflict-free, and branch updating is allowed.
- **Evidence**: GitHub documentation for protected branches and keeping a pull request in sync describes the freshness requirement and the conditions for the `Update branch` action.
- **Source**: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches ; https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/keeping-your-pull-request-in-sync-with-the-base-branch
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15
- **Potential assumption**: No

#### F13: GitHub's merge queue provides freshness guarantees without requiring every author to manually resync before merge
- **Claim**: GitHub documents merge queue as providing the same freshness guarantees as "require branches to be up to date before merging" while avoiding the need for each pull request author to manually update their branch and rerun checks individually.
- **Evidence**: GitHub's merge queue documentation states that merge queue removes the need for authors to update their own branch before merging and evaluates queued changes against the latest base and earlier queued pull requests.
- **Source**: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/merging-a-pull-request-with-a-merge-queue ; https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15
- **Potential assumption**: No

#### F14: GitHub invalidates merge readiness when freshness changes alter the review or check basis
- **Claim**: GitHub requires required checks to succeed against the latest relevant commit and can dismiss approvals as stale when the merge base changes.
- **Evidence**: GitHub troubleshooting and ruleset documentation describe required-status behavior on the latest SHA and explain that review approval can become stale if the merge base changes.
- **Source**: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/collaborating-on-repositories-with-code-quality-features/troubleshooting-required-status-checks ; https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15
- **Potential assumption**: No

#### F15: GitLab distinguishes source-only merge request pipelines from target-aware merged-results pipelines
- **Claim**: GitLab documents that merge request pipelines run on the source branch only, while merged-results pipelines test a temporary commit that combines source and target branch content.
- **Evidence**: Official GitLab CI documentation contrasts merge request pipelines with merged-results pipelines and states that merged-results pipelines are specifically for testing the merge result against the latest target branch.
- **Source**: https://docs.gitlab.com/ci/pipelines/merge_request_pipelines/ ; https://docs.gitlab.com/ci/pipelines/merged_results_pipelines/
- **Confidence**: HIGH
- **Version/Date**: GitLab Docs accessed 2026-04-15
- **Potential assumption**: No

#### F16: GitLab's merge trains validate queued merge requests against cumulative train state and restart downstream validation when the train changes
- **Claim**: GitLab merge trains queue merge requests, run merged-results-style validation against the accumulated train state, and restart or cancel downstream validations when an earlier train entry fails or is removed.
- **Evidence**: Official `merge_trains` documentation describes the merged-results train workflow, parallel pipeline execution across the queue, and downstream cancellation/restart behavior when earlier queue entries change.
- **Source**: https://docs.gitlab.com/ci/pipelines/merge_trains/
- **Confidence**: HIGH
- **Version/Date**: GitLab Docs accessed 2026-04-15
- **Potential assumption**: No

#### F17: GitLab documents auto-rebase-at-merge for fast-forward and semi-linear workflows, but says CI is not rerun on the rebased result
- **Claim**: GitLab can automatically rebase branches at merge time in fast-forward and semi-linear merge methods, reducing manual rebases, but the docs note that this rebased result does not trigger another CI pipeline.
- **Evidence**: Official GitLab merge-method documentation explains automatic rebasing behavior for these merge methods and warns that pipelines are not rerun after the rebase at merge time.
- **Source**: https://docs.gitlab.com/user/project/merge_requests/methods/
- **Confidence**: HIGH
- **Version/Date**: GitLab Docs accessed 2026-04-15
- **Potential assumption**: No

## Conflicts & Agreements

The sources agree that branch freshness matters at merge boundaries, but they describe two different enforcement families. Git's native documentation centers on explicit branch relationships, explicit fetch/pull/rebase/merge choices, and workflow rules such as topic-branch isolation and merge-upwards across maintenance and release lines.

GitHub and GitLab add a second model that validates integration state closer to merge time rather than requiring every author to keep rebasing a long-lived topic branch onto a constantly moving target. This does not contradict Git's native model, but it does shift where freshness is enforced: on the author branch itself, on a temporary merged result, or on a queue entry that represents the next merge state.

Git's own `git rebase --keep-base` documentation reinforces that repeated rebasing is not always the right answer for longer-running feature work. That aligns more naturally with queue-based and merged-result validation than with policies that rewrite topic history at every stage boundary.

## Open Questions

1. Which Specwright stages should require freshness against the target branch: build start only, verify, ship, or every stage transition?
2. Should freshness enforcement update the user's topic branch directly, or validate against a temporary merged result that leaves authored history unchanged?
3. How should branch roles be represented when a repository uses more than one integration target, such as `main`, `develop`, `release/*`, or maintenance branches?
4. Does Specwright need to integrate with hosted merge queues and trains when available, or remain git-only and enforce freshness locally?
5. How should branch-freshness policy interact with worktree ownership rules when the same repository has multiple active work units in parallel?
