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

- `{worktreeStateRoot}/session.json` -- selected work for this worktree
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- selected work unit, gate results
- `{workDir}/spec.md` -- acceptance criteria for PR body
- `{workDir}/evidence/` -- gate evidence files
- `{repoStateRoot}/config.json` -- git config (PR tool, branch prefix, main branch)

## Outputs

- `{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md` -- shipping handoff digest with attention-at-top
- Pull request created with evidence-mapped body
- Selected work's `workflow.json` status set to `shipped`

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Create PRs and mark shipped. NEVER start new
work, run builds, or begin next unit. After PR: show URL, suggest `/sw-learn`, handoff.

**Pre-flight checks (LOW freedom):**
- Resolve the selected work from the current worktree session. If another live
  top-level worktree owns it, STOP with explicit adopt/takeover guidance.
- Verify the selected work exists and status is `verifying`. Reject `building` with:
  "Run /sw-verify first." Reject all other statuses with the standard transition error.
- All enabled gates in `config.gates` must have a verdict in the selected work's
  `workflow.json`. Gates
  without a verdict → STOP: "Gate {name} has no verdict. Run /sw-verify first."
- No gate verdict may be `FAIL` or `ERROR`. FAIL/ERROR → STOP: "Gate {name} failed.
  Fix and re-run /sw-verify."
- Re-check shipping freshness during pre-flight via `protocols/git-freshness.md`.
  For branch-head validation, branch-head `require` blocks stale, diverged, and blocked freshness results.
  Queue-managed validation remains distinct and must not force a local rebase by default.
- Evidence files must exist at `{workDir}/evidence/{gate-name}-report.md` for each
  gate with a non-SKIP verdict. Missing evidence file → STOP: "Evidence missing for
  gate {name}. Re-run /sw-verify."
- Uncommitted changes: commit only files within the work unit's plan.md file-change-map.
  Report out-of-scope uncommitted files in the gate handoff — do not commit them.

**PR creation (MEDIUM freedom):**
- Follow `protocols/git.md` for push and PR operations.
- Always create PR (both interactive and headless — PRs are the universal review gate).
- PR title follows `config.git.commitFormat` style.
- PR body gate results MUST be sourced from the selected work's `workflow.json` gate verdicts and
  `{workDir}/evidence/` files. For each enabled gate: read the verdict from
  the selected work's `workflow.json`. For non-SKIP gates: read the evidence file. Never infer
  verdicts from build output — only report what is recorded in the selected work's `workflow.json`
  and backed by an evidence file. SKIP gates show "SKIP".
  (Pre-flight has already verified that all non-SKIP gates have evidence files,
  so this reading step is guaranteed to succeed.)
- PR body structure: Summary, Acceptance Criteria (status + evidence per criterion),
  Blast Radius, Gate Results (sourced from evidence), Evidence links.
- Use HEREDOC for PR body.

**State updates (LOW freedom):**
Follow `protocols/state.md`. State lifecycle for shipping:
1. After pre-flight passes: set the selected work's status to `shipping`
   (write workflow.json).
2. Push branch, create PR.
3. After successful PR creation, write `workUnits[{current unit}].prNumber`
   immediately, inside the same rollback envelope. `prMergedAt` remains null until
   merge is confirmed later. If `workUnits` is absent, skip this step.
4. After the `prNumber` write succeeds: set status to `shipped`.
5. If push, `gh pr create`, or the `prNumber` write fails: revert status to
   `verifying` (rollback transition) and `prNumber` remains null on failure.

If `workUnits` exists: update the selected work's entry to `shipped`, advance to
next `planned` unit
(set `building`, reset gates), handoff. If no more units: "All work units complete."

**Gate handoff (LOW freedom):**
On completion, emit the three-line handoff per the `protocols/decision.md`
Gate Handoff section. The one-line outcome names the PR (e.g.,
"PR #142 created"). Write `{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`
before the handoff, and the Artifacts: line points at that file
(`Artifacts: {repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`).
The Next: line ALWAYS contains a `/sw-...` slash command — never prose.
When more units are queued, Next points to `/sw-build`. When the work is
complete, Next points to `/sw-learn` (sw-learn remains optional; the
user may choose not to invoke it, but the handoff emits it so the line
stays machine-parseable). Examples: `Next: /sw-build` or `Next: /sw-learn`.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework
- `protocols/git.md` -- branch, push, PR creation
- `protocols/git-freshness.md` -- shipping freshness pre-flight
- `protocols/state.md` -- workflow state updates
- `protocols/evidence.md` -- evidence references for PR body
- `protocols/headless.md` -- non-interactive execution defaults

## Failure Modes

| Condition | Action |
|-----------|--------|
| Status is `building` | STOP: "Run /sw-verify first." |
| Gates not passed | STOP: "Gate {name} failed. Fix and re-run /sw-verify." |
| Gate has no verdict | STOP: "Gate {name} has no verdict. Run /sw-verify first." |
| No git changes to ship | STOP: "Nothing to ship." |
| Push fails during shipping | Revert status to `verifying`, keep `prNumber` null. Show error. |
| PR creation fails during shipping | Revert status to `verifying`, keep `prNumber` null. Show error. |
| `prNumber` write fails after PR creation | Revert status to `verifying`, keep `prNumber` null, surface rollback failure. |
| Evidence files missing (pre-flight) | STOP: "Evidence missing for gate {name}. Re-run /sw-verify." |
| gh CLI not installed | STOP: "Install gh CLI" |
| Selected work owned elsewhere | STOP with explicit adopt/takeover guidance |
| Stale shipping state on entry | Status is `shipping` from prior failed attempt. Check `gh pr list --head {branch}` — if PR exists: set `shipped`, show URL. If no PR: revert to `verifying`, suggest re-running /sw-ship. |
| Compaction during shipping | Recovery reads `shipping` status. Check `gh pr list --head {branch}` — if PR exists: set `shipped`. If no PR: revert to `verifying`. |
