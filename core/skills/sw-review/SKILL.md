---
name: sw-review
description: Fetches and displays PR review comments from GitHub, grouped by priority, and allows the user to reply to or resolve individual threads.
argument-hint: "[pr-number]"
allowed-tools:
  - Read
  - Bash
  - Grep
  - AskUserQuestion
---

# Specwright Review

## Goal

Surface all open PR review comments for the current branch so the user can
read, respond to, and resolve reviewer feedback without leaving the terminal.
This is a read-only utility skill with respect to Specwright workflow state —
it never modifies workflow.json or any `.specwright/` state file.

Unresolved review threads are the highest priority. Fetch all three comment
types (issue comments, review comments, thread resolution state), group them
by status, and present them in a structured format showing author, timestamp,
and file/line context. The user can then post replies or mark threads resolved.

## Inputs

- `.specwright/config.json` — `git.prTool` and `git.baseBranch` settings
- Current branch: detected via `git branch --show-current`
- GitHub PR: discovered via `gh pr list --head {branch}`
- PR comments fetched via `gh api` REST and GraphQL endpoints

## Outputs

- Grouped display of all PR comments by status and type:
  - Unresolved threads (highest priority, shown first)
  - Open issue comments (general PR conversation)
  - Resolved or addressed threads (shown last)
- Each comment shows: author, timestamp, file path, line number (where applicable), and body
- User responses posted via `gh api` POST to the appropriate endpoint
- Resolved threads marked via `resolveReviewThread` GraphQL mutation

## Constraints

**PR detection (MEDIUM freedom):**
- Detect the current branch with `git branch --show-current`. If the result
  is empty or HEAD is detached, report the detached HEAD condition and stop.
- Discover the associated PR using `gh pr list --head {branch} --json number,title,url`.
  If no open PR is found, retry with `--state merged` as a fallback for merged PRs.
- If multiple PRs are returned, use AskUserQuestion to disambiguate — present
  titles and numbers so the user can select one. Do not guess.
- If a PR number is passed as an argument, use it directly instead of detecting
  from the current branch.
- Read `config.git.prTool` before invoking `gh`; if the value is not `gh` or is
  unset, degrade to URL display. sw-review only supports the `gh` CLI.

**Comment fetching (MEDIUM freedom):**
- Fetch all three comment types via `gh api`:
  - Issue comments (general PR conversation): `GET /repos/{owner}/{repo}/issues/{n}/comments`
  - Review comments (inline code comments): `GET /repos/{owner}/{repo}/pulls/{n}/comments`
  - Thread resolution state: GraphQL query on `reviewThreads` with `isResolved` field.
    To correlate: match REST review comment `id` against GraphQL
    `reviewThreads.comments.nodes[].databaseId`. If correlation fails, treat
    as unresolved.
- Cap fetched comments at 50 per type using `--per-page 50`. If exactly 50
  results are returned, assume more may exist and display: "Showing first 50 —
  view full thread at {url}." Pagination state is in `Link` response headers,
  not in the JSON body.
- Display each comment with: author (`user.login`), timestamp (`created_at`),
  file path and line number (`path`, `line`) for review comments, and body text.

**Comment grouping and prioritization (MEDIUM freedom):**
- Present unresolved review threads as the highest priority group at the top.
- Group comments into categories: unresolved threads, general issue comments,
  resolved threads. Do not interleave types.
- Within each group, order by timestamp (newest first for unresolved, oldest
  first for general comments).

**Responding and resolving (MEDIUM freedom):**
- To post a reply to a review comment, use `gh api` with an HTTP POST:
  `gh api --method POST /repos/{owner}/{repo}/pulls/{n}/comments/{id}/replies`.
- To post a new top-level PR conversation comment, POST to
  `/repos/{owner}/{repo}/issues/{n}/comments` with a `body` field. Issue
  comments have no threading — there is no `in_reply_to_id` for this endpoint.
- To resolve a review thread, call the `resolveReviewThread` GraphQL mutation
  via `gh api graphql`. The `gh pr edit` command is for PR metadata only — it
  cannot post replies or resolve threads; always use `gh api` instead.
- After the user responds, re-fetch the relevant comment to confirm the reply
  was posted.

**Graceful degradation without gh (LOW freedom):**
- If `gh` is not available or not installed, degrade gracefully: construct the
  PR URL from the `git remote` URL (convert SSH or HTTPS remote to a browser
  URL), display it, and inform the user: "Install gh CLI to fetch and respond
  to comments from the terminal." Do not abort or STOP — present the URL as a
  fallback so the user can open the PR in a browser.
- In headless mode, follow `protocols/headless.md`. Skip AskUserQuestion
  disambiguation; if multiple PRs exist, report them all and exit.

**Stateless utility (STRICT):**
- This skill is stateless with respect to Specwright state. It never writes
  workflow.json, never claims exclusive workflow ownership, and makes no state
  changes to the Specwright workflow. It is a read-only utility skill for
  GitHub review comments only.
- Reading config.json for `prTool` is permitted. No writes to `.specwright/`.

## Protocol References

- `protocols/git.md` — PR operations, remote URL conventions, gh CLI patterns
- `protocols/headless.md` — non-interactive execution and result file format
- `protocols/context.md` — config loading from `.specwright/config.json`

## Failure Modes

- **Detached HEAD** — `git branch --show-current` returns empty. Report "Cannot
  detect branch: HEAD is detached. Check out a branch and try again." Do not proceed.
- **No PR found** — `gh pr list --head` returns no results and the `--state merged`
  fallback also returns nothing. Report "No pull request found for branch
  `{branch}`" and exit without error.
- **No comments** — PR exists but all three comment type queries return zero
  results. Report "No review comments found on this PR." and exit cleanly.
- **Rate limit exceeded** — `gh api` returns HTTP 429, or HTTP 403 with
  `X-RateLimit-Remaining: 0`. Surface the error message and the
  `X-RateLimit-Reset` time. Ask the user to retry after the reset window.
- **Authorization failure** — `gh api` returns HTTP 403 without rate-limit
  headers. Report "Access denied. Run `gh auth status` to check token scopes
  and repository access." Do not retry automatically.
- **gh CLI not available** — Degrade gracefully: construct PR URL from remote
  URL, display it, and print "Install gh CLI to enable full comment review from
  the terminal." Do not abort.
