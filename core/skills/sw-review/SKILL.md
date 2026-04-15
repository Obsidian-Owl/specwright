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

Surface PR review comments, triage autonomously per Google severity framework
(`protocols/decision.md`), draft replies, and present for approval before
posting. When the associated Specwright work can be resolved safely, use
`review-packet.md`, `approvals.md`, and unit evidence as the primary reply
context instead of reasoning from the diff alone. Stateless with respect to
Specwright state — never modifies workflow.json.

Fetch all comment types, group by status, apply autonomous triage:
- Functional issues (API misuse, missing validation): fix code and draft reply
- Nits (style, naming): acknowledge, apply if <2 minutes
- Suggestions: apply if they improve code health, push back with reasoning if not
- Conflicting comments: follow the one most aligned with constitution/spec

The PR itself is the review surface — reviewers see replies directly. When no
associated work can be matched, say so explicitly and use a diff-only fallback.

## Inputs

- `{projectArtifactsRoot}/config.json` — `git.prTool` and `git.baseBranch` settings
- Current branch: detected via `git branch --show-current`
- GitHub PR: discovered via `gh pr list --head {branch}`
- PR comments fetched via `gh api` REST and GraphQL endpoints
- Associated Specwright work when it can be matched safely from PR number or branch:
  - `{repoStateRoot}/work/*/workflow.json`
  - `{workDir}/review-packet.md`
  - `{workArtifactsRoot}/{workId}/approvals.md`
  - `{workDir}/evidence/*.md`

## Outputs

- Grouped display of all PR comments by status and type:
  - Unresolved threads (highest priority, shown first)
  - Open issue comments (general PR conversation)
  - Resolved or addressed threads (shown last)
- Each comment shows: author, timestamp, file path, line number (where applicable), and body
- When associated work is available, replies and findings use the review packet,
  approval lineage, and evidence as first-class context
- User responses posted via `gh api` POST to the appropriate endpoint
- Resolved threads marked via `resolveReviewThread` GraphQL mutation

## Constraints

**PR detection (MEDIUM freedom):**
- Detect the current branch with `git branch --show-current`. If the result
  is empty or HEAD is detached, report the detached HEAD condition and stop.
- Discover the associated PR using `gh pr list --head {branch} --json number,title,url`.
  If no open PR is found, retry with `--state merged` as a fallback for merged PRs.
- If multiple PRs are returned and interactive questioning is available, use
  AskUserQuestion to disambiguate. In headless mode, use the most recent and
  record the fallback choice in output.
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

**Associated work context (MEDIUM freedom):**
- Resolve the associated work from PR context by matching the explicit PR
  number when provided, then `workUnits[].prNumber`, then the PR head branch
  against `workflow.json.branch`. If more than one work matches, report the
  ambiguity and fall back instead of picking one silently.
- When a unique associated work is found, load `review-packet.md`,
  `approvals.md`, and unit evidence before drafting replies or validating bot
  comments.
- Use `review-packet.md` as the primary reviewer-response context. Use
  `approvals.md` to verify approval lineage claims and evidence files to verify
  gate-status claims. Do not default to diff-only reasoning when these audit
  artifacts are available.
- If no work match is available, say so explicitly and use diff-only fallback.

**Responding and resolving (MEDIUM freedom):**
- To post a reply to a review comment, use `gh api` with an HTTP POST:
  `gh api --method POST /repos/{owner}/{repo}/pulls/{n}/comments/{id}/replies`.
- To post a new top-level PR conversation comment, POST to
  `/repos/{owner}/{repo}/issues/{n}/comments` with a `body` field. Issue
  comments have no threading — there is no `in_reply_to_id` for this endpoint.
- To resolve a review thread, call the `resolveReviewThread` GraphQL mutation
  via `gh api graphql`. The `gh pr edit` command is for PR metadata only — it
  cannot post replies or resolve threads; always use `gh api` instead.
- In clone-local work-artifact mode, replies must quote or paraphrase the
  relevant packet/evidence summary instead of depending on local-only file
  links. In tracked work-artifact mode, replies may reference tracked audit
  artifact paths or sections when that improves reviewer navigation.
- After the user responds, re-fetch the relevant comment to confirm the reply
  was posted.

**Graceful degradation without gh (LOW freedom):**
- If `gh` is not available or not installed, degrade gracefully: construct the
  PR URL from the `git remote` URL (convert SSH or HTTPS remote to a browser
  URL), display it, and inform the user: "Install gh CLI to fetch and respond
  to comments from the terminal." Do not abort or STOP — present the URL as a
  fallback so the user can open the PR in a browser.
- In headless mode, follow `protocols/headless.md`.

**Stateless utility (LOW freedom):**
- This skill is stateless with respect to Specwright state. It never writes
  workflow.json, never claims exclusive workflow ownership, and makes no state
  changes to the Specwright workflow. It is a read-only utility skill for
  GitHub review comments only.
- Reading config.json for `prTool` is permitted. No writes to `.specwright/`.

## Protocol References

- `protocols/decision.md` — autonomous decision framework (Google severity triage, external reply gate)
- `protocols/git.md` — PR operations, remote URL conventions, gh CLI patterns
- `protocols/evidence.md` — gate evidence as canonical detail
- `protocols/approvals.md` — approval lineage contract
- `protocols/review-packet.md` — reviewer packet contract for reply context
- `protocols/headless.md` — non-interactive execution and result file format
- `protocols/context.md` — logical-root config loading

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
