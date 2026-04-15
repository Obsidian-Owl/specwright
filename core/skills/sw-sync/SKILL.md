---
name: sw-sync
description: >-
  Syncs the local repository by fetching all remotes, updating the base branch,
  and removing stale local branches that are not protected by live sessions or
  helper worktrees.
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Glob
  - AskUserQuestion
---

# Specwright Sync

## Goal

Keep the local repository current without deleting branches that are still
claimed by a live Specwright session or a subordinate helper worktree.

## Inputs

- `{repoStateRoot}/config.json`
- `{worktreeStateRoot}/session.json`
- `{repoStateRoot}/work/*/workflow.json`
- `git worktree list --porcelain`

## Outputs

- Remotes fetched and pruned
- Base branch fast-forwarded when safe
- Candidate stale branches previewed, then deleted only after confirmation
- Summary report: branches fetched, removed, skipped, protected, and any stale
  active works detected

## Advisory Reporting

- After fetch/prune completes, `sw-sync` may report stale active works against
  their recorded targets and latest known freshness state.
- This report is advisory only and does not take ownership of
  reconcile-or-ship decisions away from the lifecycle skills.
- `sw-sync` never rebases, merges, retargets, or clears a freshness block on
  behalf of `sw-build`, `sw-verify`, or `sw-ship`.

## Constraints

**Fetch (HIGH freedom):**
- Run `git fetch --all --prune`.

**State-aware protection set (LOW freedom):**
- Build a branch protection set from:
  - the currently checked out branch
  - the configured base branch and perennial branches
  - branches recorded by live `session.json` files across `git worktree list`
  - branches recorded in attached work `workflow.json.branch`
  - helper branch patterns `worktree-*` and `specwright-wt-*`
- Treat subordinate helper worktrees discovered via `git worktree list --porcelain`
  as protected branch owners even when they are not user-facing sessions.
- Never delete a branch that appears in that protection set.

**Stale branch detection (HIGH freedom):**
- Primary signal: `git branch -vv` entries with `[gone]`
- Supplementary signal: `git branch --merged` against the configured base branch
- Do not promote a branch to deletion solely because it is merged if a live
  session still references it.
- Do not delete a branch when a live session or subordinate helper still claims it.

**Safety checks (LOW freedom):**
- Validate each candidate branch with `git check-ref-format --branch` before
  passing it to shell commands.
- Reject names that start with `-`, contain shell metacharacters or control
  whitespace, or fail ref-format validation.
- Pass branch names to Git as quoted positional arguments after `--`.
- If `config.git.cleanupBranch` is false, skip deletion entirely and say so.
- If worktree enumeration fails, skip deletion and warn rather than guessing.

**Confirmation (LOW freedom):**
- Show the candidate branch list with deletion reasons.
- Use AskUserQuestion for confirm-all, select-subset, or abort.
- In non-interactive context, skip deletion and report candidates only per
  `protocols/headless.md`.
- Delete with `git branch -d` only. Never use `-D`.

**Base branch sync (MEDIUM freedom):**
- Checkout the configured base branch and pull with `--ff-only`.
- Return to the original branch afterward.
- If the working tree is dirty, warn and skip the checkout/pull path.
- If `--ff-only` reports divergence, warn and continue without creating a merge
  commit.

**No state mutation (LOW freedom):**
- `sw-sync` never writes Specwright state.
- Reading session and workflow files to protect branches is allowed.

## Protocol References

- `protocols/git.md` -- branch lifecycle and cleanup rules
- `protocols/git-freshness.md` -- freshness result shape and status semantics for advisory reporting
- `protocols/context.md` -- logical roots and session loading
- `protocols/state.md` -- per-work workflow fields used for protection
- `protocols/headless.md` -- non-interactive behavior

## Failure Modes

| Condition | Action |
|---|---|
| no remotes configured | stop with a remote-setup error |
| `git fetch` fails | surface the error and skip deletion |
| no stale branch candidates | report that nothing is deletable |
| worktree/session inspection fails | skip deletion and warn |
| current session's attached work is building or verifying | abort and tell the user to finish or reset that work first |
| base branch cannot fast-forward | warn and continue without merging or resetting |
