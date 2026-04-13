---
name: sw-status
description: >-
  Shows current Specwright state for this worktree, the attached work, repo-wide
  active works, gate results, and lock status. Supports --reset, --cleanup, and
  --repair {unitId}.
argument-hint: "[--reset | --cleanup | --repair {unitId}]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - AskUserQuestion
---

# Specwright Status

## Goal

Tell the user what this worktree is attached to, what that work is doing, what
other works are active in the repository, and what the next action should be.

## Inputs

- `{repoStateRoot}/config.json`
- `{worktreeStateRoot}/session.json`
- `{repoStateRoot}/work/*/workflow.json`

## Outputs

- Formatted status display for the current session and selected work
- Repo-wide summary of active works and their owner worktrees
- In `--repair` mode: remediation outcome for the targeted shipped unit

## Constraints

**Display (HIGH freedom):**
- Show the current session first: `worktreeId`, mode, branch, and
  `attachedWorkId`.
- If the session is attached, show that work's status, unit/task progress,
  gates, and per-work lock freshness.
- Enumerate other active works discovered under `repoStateRoot/work/*`, along
  with their recorded owner worktrees.
- If no work is attached in this worktree, say so and suggest `/sw-design`.
- Keep the output concise.

**Non-interactive context (LOW freedom):**
- Follow `protocols/headless.md` when AskUserQuestion is unavailable.
- `--reset`: abort without confirmation and report that reset requires a human.
- `--cleanup`: report-only. List eligible work directories but do not delete
  them.
- `--repair`: report-only. Inspect the selected or uniquely matched work/unit,
  print what interactive repair would do, and never mutate workflow state in
  headless mode.

**Reset mode (LOW freedom):**
- `--reset` applies to the work attached to this worktree session.
- Confirm with the user before mutating anything.
- If confirmed: set the selected work's status to `abandoned`, clear that
  work's lock, clear its gates, and detach this session if it points at that
  work.
- Follow `protocols/state.md` for all mutations.

**Cleanup mode (MEDIUM freedom):**
- Scan `{repoStateRoot}/work/` for work directories.
- Exclude any work currently claimed by a live session from deletion choices.
- Present only non-attached work directories for deletion.
- Canonicalize `{repoStateRoot}/work/` and each selected candidate with
  `realpath` before removing anything.
- Verify each canonical candidate is a direct child of the canonical
  `{repoStateRoot}/work/` directory.
- If canonicalization fails, or a candidate escapes the allowed direct-child
  scope, skip it with a warning.
- Delete only the user-selected, verified paths.

**Repair mode (MEDIUM freedom):**
- `--repair {unitId}` first looks in the selected work, if one is attached.
- If no selected work is attached, or the unit is absent there, search
  repo-wide workflows for a unique matching `unitId`.
- If the match is ambiguous across works, stop and tell the user which work IDs
  conflict.
- Repair applies only to shipped units with `prNumber=null`.
- If `gh` confirms a merged PR, populate the owning work's `prNumber` and `prMergedAt` and report `repaired`.
- If no PR can be proven, offer the same three outcomes as before:
  `revert-to-building`, `mark-abandoned`, `force-shipped-with-note`.
- `force-shipped-with-note` appends the user's assertion to the owning
  `decisions.md`.

## Protocol References

- `protocols/context.md` -- logical roots and session/work resolution
- `protocols/state.md` -- per-work workflow schema and mutation rules

## Failure Modes

| Condition | Action |
|---|---|
| no shared/session state can be resolved | tell the user to run `/sw-init` |
| selected workflow parse error | show the raw error and stop |
| stale per-work lock detected | offer to clear it with a warning |
| `--repair` target ambiguous across works | stop and list matching work IDs |
