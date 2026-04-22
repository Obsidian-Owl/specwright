---
name: sw-doctor
description: >-
  Specwright health check. Validates shared config, anchor docs, workflow and
  session state, commands, gates, and hooks. May backfill shipped PR metadata
  when it can prove the mapping safely.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# Specwright Doctor

## Goal

Validate that a Specwright installation is coherent across the tracked
project-artifact root, shared repo-state root, and per-worktree session model,
then print actionable repair hints using the same runtime-root and ownership
vocabulary the adapters expose.

## Inputs

- `{projectArtifactsRoot}/config.json`
- `{projectArtifactsRoot}/CONSTITUTION.md` and `{projectArtifactsRoot}/CHARTER.md`
- `{worktreeStateRoot}/session.json` when present
- `{repoStateRoot}/work/*/workflow.json`
- `{workArtifactsRoot}/{workId}/approvals.md` and `{workDir}/review-packet.md`
  when present
- gate skill files, hook config, and configured commands

## Outputs

- PASS/WARN/FAIL health table
- Optional backfill of `prNumber` and `prMergedAt` on the owning work's
  `workflow.json`

## Constraints

**Pre-condition (LOW freedom):**
- If neither the shared layout nor the legacy fallback can be resolved, stop
  immediately and tell the user to run `/sw-init`.
- Always report layout status first: `shared/session`, `legacy fallback`, or
  `missing`.
- When layout resolves, describe the active runtime mode explicitly:
  `project-visible` runtime roots under `.specwright-local/` are the preferred
  interactive default; `git-admin` roots under `.git/specwright/` are
  compatibility mode.

**Checks (LOW freedom — run all 13 in order):**
1. **Anchor docs** — tracked Constitution and Charter exist and are non-empty
2. **Config** — tracked config parses and contains `gates` and `git`
3. **State** — current session parses when present, every discovered workflow
   parses with a null or fresh per-work lock, and layout status is explicit
4. **Gates** — enabled gate skills exist
5. **Build command** — configured build command exists on PATH
6. **Test command** — configured test command exists on PATH
7. **Format/lint** — configured format or lint commands exist on PATH
8. **Hooks** — hook manifest parses and referenced hook files exist
9. **Backlog config** — configured backlog target is usable
10. **ast-grep** — INFO availability only
11. **OpenGrep** — INFO availability only
12. **LSP** — PASS/WARN/INFO based on available platform or standalone LSP
13. **STATE_DRIFT** — enumerate repo-wide workflows and flag shipped units with
    `status=shipped` and `prNumber=null`

Within the State pass, check all of the following and report them by name:
- layout status for the current checkout
- resolved `projectArtifactsRoot`, `workArtifactsRoot`, and the authoritative
  runtime roots (`repoStateRoot` and `worktreeStateRoot`) for the current
  checkout
- session attachment consistency between `session.json` and the owning
  `workflow.json`
- dead sessions where a recorded attachment points at a missing or removed
  worktree
- legacy-write drift where the shared layout exists but checkout-local legacy
  state files are still being treated as writable sources
- approval freshness for the selected unit when approvals exist
- review-packet presence for the selected unit when verify or ship artifacts
  should exist
- live ownership conflicts that should route the operator to `/sw-adopt`
  instead of implying generic takeover

State-pass output must report the authoritative runtime roots clearly so the
user can see which `repoStateRoot` and `worktreeStateRoot` are in force.

Within the Config pass, check all of the following and report them by name:
- queue validation without the required provider-aware configuration surface
- Claude-oriented installs that remain on `git-admin` even though
  `project-visible` runtime roots are the recommended default for that setup
- work-artifact publication mode that points at clone-local runtime roots,
  session state, or symlinked `.git` mirrors instead of an explicit tracked
  artifact path
- `config.git.runtime.projectVisibleRoot` values that point at tracked project
  artifacts or `.git`-mirrored paths instead of a dedicated project-visible
  runtime root

Reject project-visible roots that overlap tracked project artifacts or `.git`-mirrored paths, and name `config.git.runtime.projectVisibleRoot` in the result.

CONFIG_MISMATCH findings must name the offending config key and print the
corrective action.

STATE_DRIFT findings must print the inline remediation command
`sw-status --repair {unitId}` and include the owning work ID.

**STATE_DRIFT backfill (MEDIUM freedom):**
- On the first invocation, attempt a one-time backfill for any shipped unit with
  `status=shipped` and `prNumber=null`.
- Candidate set: shipped units with `prNumber=null` across all discovered
  workflows.
- Detection order is strict: `gh` lookup, then `git log` / merge confirmation,
  then warn and leave the fields untouched.
- Backfill order is `gh`, then `git log`, then warn.
- Backfill scope is limited to `prNumber` and `prMergedAt` on the owning work's
  workflow file.
- Backfill never modifies `status`; it only writes `prNumber` and `prMergedAt`.

**Output format (MEDIUM freedom):**
- Print the same PASS/WARN/FAIL/INFO table shape as the existing doctor output.
- STATE_DRIFT findings must include the owning work ID and unit ID so the user
  can distinguish repo-wide issues.

**Workflow mutation scope (LOW freedom):**
- The only allowed mutation is STATE_DRIFT backfill.
- When mutating a work's `workflow.json`, follow `protocols/state.md`.
- Doctor never modifies `status`; only `prNumber` and `prMergedAt` may change.
- It is not a core workflow stage and never claims top-level work ownership.
- Any repair guidance beyond PR backfill must remain bounded to the documented
  migration surface: tracked docs/config under `{projectArtifactsRoot}`, split
  per-work workflows under `{repoStateRoot}`, and this worktree's
  `{worktreeStateRoot}/session.json`.

## Protocol References

- `protocols/context.md` -- logical-root loading
- `protocols/state.md` -- per-work workflow format and lock handling

## Failure Modes

| Condition | Action |
|---|---|
| shared config missing | fail that check and continue |
| workflow parse error | fail the state check and identify the owning work |
| all checks pass | print the table and say all checks passed |
| hooks absent | INFO: no hooks configured |
