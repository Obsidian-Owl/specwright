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
---

# Specwright Ship

## Goal

Merge the current work unit to main via a pull request. The PR body maps
evidence to acceptance criteria so reviewers can verify. The PR itself is the
human gate — reviewers verify before merge.

## Inputs

- `.specwright/state/workflow.json` -- current work unit, gate results
- `{currentWork.workDir}/spec.md` -- acceptance criteria for PR body
- `{currentWork.workDir}/evidence/` -- gate evidence files
- `.specwright/config.json` -- git config (PR tool, branch prefix, main branch)

## Outputs

- Pull request created with evidence-mapped body
- `workflow.json` currentWork status set to `shipped`

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Create PRs and mark shipped. NEVER start new
work, run builds, or begin next unit. After PR: show URL, suggest `/sw-learn`, handoff.

**Pre-flight checks (LOW freedom):**
- Verify `currentWork` exists and status is `verifying` or `building`.
- All enabled gates must have status PASS, WARN, or SKIP. FAIL → STOP.
- Evidence freshness: results >30 minutes → warning (logged, not blocking).
- Uncommitted changes: commit only files within the work unit's plan.md file-change-map.
  Report out-of-scope uncommitted files in the gate handoff — do not commit them.
  The PR diff is the review surface.

**PR creation (MEDIUM freedom):**
- Follow `protocols/git.md` for push and PR operations.
- Always create PR (both interactive and headless — PRs are the universal review gate).
- PR title follows `config.git.commitFormat` style.
- PR body structure: Summary, Acceptance Criteria (status + evidence per criterion),
  Blast Radius, Gate Results (with SKIP gates marked), Evidence links.
- Use HEREDOC for PR body.

**State updates (LOW freedom):**
Follow `protocols/state.md`. Set `shipped` after PR creation. If `workUnits` exists:
update entry to `shipped`, advance to next `planned` unit (set `building`, reset gates),
handoff. If no more units: "All work units complete."

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework
- `protocols/git.md` -- branch, push, PR creation
- `protocols/state.md` -- workflow state updates
- `protocols/evidence.md` -- evidence references for PR body
- `protocols/headless.md` -- non-interactive execution defaults

## Failure Modes

| Condition | Action |
|-----------|--------|
| Gates not passed | STOP: "Run /sw-verify first" |
| No git changes to ship | STOP: "Nothing to ship." |
| PR creation fails | Show error. Don't update state. |
| Evidence files missing | WARN in PR body: "Evidence not available for gate X" |
| gh CLI not installed | STOP: "Install gh CLI" |
| Compaction during ship | Read workflow.json, check if PR already created |
