---
name: sw-sync
description: >-
  Syncs the local repository by fetching all remotes, updating the base branch,
  and removing stale local branches that have been deleted upstream.
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Glob
  - AskUserQuestion
---

# Specwright Sync

## Goal

Keep the local repository clean and current. Fetch all remotes with pruning,
sync the base branch, detect stale local branches, and offer to delete them
after showing a preview and receiving explicit confirmation. This is a
read-only utility: it never modifies workflow state.

## Inputs

- `.specwright/config.json` -- `git.baseBranch` and `git.cleanupBranch` settings
- `.specwright/state/workflow.json` -- active feature branch reference (`currentWork`)
- Git repository state: local branches, remote tracking refs, worktrees

## Outputs

- Remote refs pruned via `git fetch --all --prune`
- Base branch updated to match its remote tracking ref
- Stale local branches deleted (only after user confirmation via AskUserQuestion)
- Summary report: branches fetched, branches removed, current branch

## Constraints

**Fetch (HIGH freedom):**
- Run `git fetch --all --prune` to refresh all remotes and remove references
  to deleted remote branches. Using `--all` avoids hardcoding a single remote.

**Stale branch detection (HIGH freedom):**
- Primary method: inspect `git branch -vv` output for the `[gone]` annotation,
  which indicates the remote tracking branch has been deleted. This is the
  most reliable signal.
- Supplementary method: use `git branch --merged` against the base branch to
  surface local-only branches (no tracking ref) whose commits are already in base.
  Do NOT promote a branch to the candidate list solely because it is `--merged`
  if its remote tracking ref is still present; surface those separately for the
  user to review. Deduplicate the combined candidate set.
- Base branch must be read from `config.json` (`git.baseBranch`). Never
  hardcode `main` or any other branch name as a fallback without consulting
  config.

**Safety checks (LOW freedom — never skip):**
- Current branch protection: never delete the branch currently checked out;
  exclude current branch from all candidate lists and skip it silently.
- Base branch and perennial branch protection: never delete the base branch
  or any configured perennial branches (e.g., `develop`, `staging`). Exclude
  them from candidates unconditionally.
- Worktree safety: run `git worktree list` and exclude any branch referenced
  by an active worktree. Deleting a branch in use by another worktree corrupts
  the worktree.
- Active feature branch protection: read `workflow.json` to identify the
  active feature branch (`currentWork.branch`). Exclude it from candidates
  even if its remote tracking ref is gone.
- Branch name validation: validate each candidate branch name before
  passing it to any shell command. Reject names containing metacharacters,
  shell special characters, or path separators to prevent injection. Skip
  and warn on any name that does not pass validation.
- `cleanupBranch` gate: check `config.git.cleanupBranch`. If false, skip
  deletion entirely and inform the user that cleanup is disabled in config.

**Confirmation (LOW freedom):**
- Show the user the full list of candidate branches and their reason for
  deletion (e.g., `[gone]` or `--merged`) before asking anything.
- Use AskUserQuestion to confirm deletion with three options: confirm all,
  select a subset, or abort. Never delete without explicit approval.
- Use `git branch -d` (safe delete) for all deletions. Safe delete refuses
  to delete unmerged branches, providing a second safety layer. Never use
  `-D` (force delete).

**Base branch sync (MEDIUM freedom):**
- After fetch, checkout the base branch and pull to bring it up to date.
  Use `--ff-only` to avoid creating merge commits on the base branch.
- After the base branch pull, switch back to the original branch so the user
  is returned to where they started.

**No state mutation (STRICT):**
- This skill is read-only with respect to Specwright state. It never writes
  to workflow.json or any other `.specwright/` state file. No state changes.
- No exclusive ownership of state is taken. No workflow transition is triggered.
- Reading workflow.json to identify the active feature branch is permitted.

**Non-interactive context:**
- Follow `protocols/headless.md` when AskUserQuestion is unavailable.
- In headless mode, skip deletion (cannot confirm) and report candidates only.

## Protocol References

- `protocols/git.md` -- git config schema, `baseBranch`, `cleanupBranch`, branch lifecycle
- `protocols/context.md` -- config loading from `.specwright/config.json`
- `protocols/headless.md` -- non-interactive execution and result file format
- `protocols/state.md` -- workflow state schema, `currentWork` fields, read-only access patterns

## Failure Modes

- **Dirty working tree / uncommitted changes on base branch** — warn the user;
  skip base branch checkout and pull. Continue with fetch and stale detection.
- **No remotes configured** — abort with message: "No remotes found. Configure
  a remote before running sw-sync."
- **No stale branches to clean up** — report "No stale branch candidates found"
  and exit without prompting.
- **`git fetch` fails (network error or auth)** — surface the error output;
  skip stale detection; still report current local state.
- **Worktree check fails** — treat all branches as potentially in use; skip
  deletion and warn the user.
- **Branch name fails validation (metacharacter detected)** — skip that branch,
  log a warning with the branch name, continue with remaining candidates.
- **Active build in progress** — if `workflow.json` shows `currentWork.status`
  is `building` or `verifying`, abort with an error message and instructions
  to wait for the build to complete or cancel it first. Do not proceed.
- **Base branch cannot fast-forward** — if `git pull --ff-only` fails (e.g.,
  upstream was rebased), warn the user that the base branch has diverged; skip
  the pull and continue with the summary report. Never attempt a merge or
  reset automatically.
