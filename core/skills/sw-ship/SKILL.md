---
name: sw-ship
description: >-
  Ships the current work unit. Verifies all gates passed, creates a PR
  with evidence-mapped body, updates workflow state to shipped.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Specwright Ship

## Goal

Merge the current work unit to main via a pull request. The PR body maps
evidence to acceptance criteria so reviewers can verify the work. Only
ships when gates have passed.

## Inputs

- `.specwright/state/workflow.json` -- current work unit, gate results
- `{currentWork.workDir}/spec.md` -- acceptance criteria for PR body
- `{currentWork.workDir}/evidence/` -- gate evidence files
- `.specwright/config.json` -- git config (PR tool, branch prefix, main branch)

## Outputs

- Pull request created with evidence-mapped body
- `workflow.json` currentWork status set to `shipped`
- Feature branch cleaned up after merge (if configured)

## Constraints

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You create PRs and mark work as shipped. You NEVER start new work, run builds, or begin the next work unit.
- After PR creation, STOP and present:
  - The PR URL
  - "Consider running `/sw-learn` to capture learnings."
  - If more work units pending: "Then run `/sw-build` for the next unit."
  - If no more units: "All work units complete."

**Pre-flight checks (LOW freedom):**
- Verify `currentWork` exists and status is `verifying` or `building`.
- Check gate results in workflow.json:
  - All enabled gates must have status PASS, WARN, or SKIP.
  - If any gate is FAIL or has no result: STOP and tell the user to run verify.
- Check evidence freshness: gate results older than 30 minutes trigger a warning.
- Check for uncommitted changes. If any, ask user: commit them or abort.

**PR creation (MEDIUM freedom):**
- Follow `protocols/git.md` for push and PR operations.
- Read `config.json` `git` section for strategy-aware behavior:
  - Push feature branch to remote: `git push -u origin {branch}`
  - PR target: determined by `git.strategy` (see protocol strategy table)
  - PR tool: `config.git.prTool` (default: `gh`)
  - If `config.git.prRequired` is false: ask user whether to create a PR or merge directly
- PR title follows `config.git.commitFormat` style (e.g., `feat(scope): description` for conventional).
- PR body structure:
  ```
  ## Summary
  <1-3 bullet points from spec description>

  ## Acceptance Criteria
  <For each criterion: status + evidence reference>

  ## Gate Results
  <Summary table: gate, status, findings count>

  ## Evidence
  <Links to evidence files or inline summaries>
  ```
- Use HEREDOC for PR body to preserve formatting.

**State updates (LOW freedom):**
- Follow `protocols/state.md`.
- Set `currentWork.status` to `shipped` after PR creation.
- If `workUnits` array exists:
  - Update the matching entry's status to `shipped`.
  - Find the next `planned` entry by `order`. If found:
    - Set that entry's status to `building`
    - Set `currentWork.unitId` to the next unit's `id`
    - Set `currentWork.workDir` to the next unit's `workDir`
    - Set `currentWork.status` to `building`
    - Reset `gates` to `{}`, `tasksCompleted` to `[]`, `tasksTotal` to `null`, `currentTask` to `null`
    - Handoff: "Next: {unit-name}. Run `/sw-build`."
  - If no more `planned` entries: "All work units complete."
- Release lock.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/git.md` -- branch, push, PR creation
- `protocols/state.md` -- workflow state updates
- `protocols/evidence.md` -- evidence references for PR body

## Failure Modes

| Condition | Action |
|-----------|--------|
| Gates not passed | STOP: "Run /sw-verify first" |
| No git changes to ship | STOP: "Nothing to ship. No changes detected." |
| PR creation fails | Show error. Don't update state. User can retry. |
| Evidence files missing | WARN in PR body: "Evidence not available for gate X" |
| gh CLI not installed | STOP: "Install gh CLI or configure alternative PR tool" |
| Compaction during ship | Read workflow.json, check if PR was already created |
