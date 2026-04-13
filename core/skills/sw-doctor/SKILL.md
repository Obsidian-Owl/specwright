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

Validate that a Specwright installation is coherent under the shared repo-state
and per-worktree session model, then print actionable repair hints.

## Inputs

- `{repoStateRoot}/config.json`
- `{repoStateRoot}/CONSTITUTION.md` and `{repoStateRoot}/CHARTER.md`
- `{worktreeStateRoot}/session.json` when present
- `{repoStateRoot}/work/*/workflow.json`
- gate skill files, hook config, and configured commands

## Outputs

- PASS/WARN/FAIL health table
- Optional backfill of `prNumber` and `prMergedAt` on the owning work's
  `workflow.json`

## Constraints

**Pre-condition (LOW freedom):**
- If neither the shared layout nor the legacy fallback can be resolved, stop
  immediately and tell the user to run `/sw-init`.

**Checks (LOW freedom — run all 13 in order):**
1. **Anchor docs** — shared Constitution and Charter exist and are non-empty
2. **Config** — shared config parses and contains `gates` and `git`
3. **State** — current session parses when present, and every discovered
   workflow parses with a null or fresh per-work lock
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
    `prNumber=null`

**STATE_DRIFT backfill (MEDIUM freedom):**
- Candidate set: shipped units with `prNumber=null` across all discovered
  workflows.
- Detection order is strict:
  1. `gh` lookup
  2. `git log` / merge confirmation
  3. otherwise leave the fields untouched and warn
- Backfill scope is limited to `prNumber` and `prMergedAt` on the owning work's
  workflow file.

**Output format (MEDIUM freedom):**
- Print the same PASS/WARN/FAIL/INFO table shape as the existing doctor output.
- STATE_DRIFT findings must include the owning work ID and unit ID so the user
  can distinguish repo-wide issues.

**Workflow mutation scope (LOW freedom):**
- The only allowed mutation is STATE_DRIFT backfill.
- When mutating a work's `workflow.json`, follow `protocols/state.md`.

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
