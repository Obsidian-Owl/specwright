---
name: gate-build
description: >-
  Runs configured build and test commands in tiered order. Captures output as
  evidence per tier. Returns PASS, FAIL, WARN, or SKIP based on per-tier
  verdicts. Internal gate — invoked by verify, not directly by users.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Write
---

# Gate: Build

## Goal

Confirm the codebase compiles and tests pass across all configured tiers. This
is the most basic gate — if the code doesn't build or tests don't pass, nothing
else matters.

## Inputs

- `{projectArtifactsRoot}/config.json` -- `commands.build`, `commands.test`,
  `commands.test:integration`, `commands.test:smoke`
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- selected work unit for evidence path

## Outputs

- Evidence file at `{workDir}/evidence/build-report.md`
- Gate status update in the selected work's `workflow.json`: PASS, FAIL, WARN, or SKIP
- Console output showing results inline (users see findings, not just badges)

## Constraints

**Tiered Execution (LOW freedom):**

Run tiers in execution order: `commands.build` → `commands.test` →
`commands.test:integration` → `commands.test:smoke`. Each tier runs only if the
previous tier passes (any tier failure stops further execution).

- If a tier's command is null or not configured, that tier produces SKIP. Emit
  an INFO note for each unconfigured tier — visibility rule: display the
  unconfigured tier name so users know what was skipped.
- If all tier commands are null/unconfigured, gate status is SKIP.
- Timeout: 5 minutes per command. If exceeded, status is ERROR.

**Per-Tier Verdicts (LOW freedom):**

| Tier | Failure verdict |
|------|----------------|
| `commands.build` | FAIL |
| `commands.test` | FAIL (test failure = FAIL) |
| `commands.test:integration` | FAIL (integration failure = FAIL) |
| `commands.test:smoke` | WARN (smoke produces WARN on failure — charter exception: quality gates default to FAIL: smoke tests validate optional end-to-end paths; degraded smoke is advisory, not blocking) |

Unconfigured tier = SKIP.

**Evidence (LOW freedom):**

Follow `protocols/evidence.md`. Evidence starts with a tier layout header
summarizing configured tiers and their run order. Each tier produces its own
evidence section containing: command executed (capture command run), exit code,
stdout/stderr output, and duration (elapsed wall time). Per-tier sections are
written regardless of tier outcome.

- Follow `protocols/evidence.md#verdict-rendering` for verdict rendering.
- Update the selected work's `workflow.json` gates section per `protocols/state.md`.

## Protocol References

- `protocols/evidence.md#verdict-rendering` -- default-FAIL, self-critique, visibility
- `protocols/evidence.md` -- evidence storage and freshness
- `protocols/state.md` -- gate status updates

## Failure Modes

| Condition | Action |
|-----------|--------|
| Build command not configured | SKIP build check, continue to test check |
| Test command not configured | SKIP test check |
| test:integration command not configured | SKIP integration tier, emit INFO note |
| test:smoke command not configured | SKIP smoke tier, emit INFO note |
| All tier commands null | Gate status = SKIP |
| Command times out (>5min) | Gate status = ERROR with timeout message |
| test:integration failure | FAIL verdict (integration failures block ship) |
| test:smoke failure | WARN verdict (smoke is advisory; see charter exception: quality gates default to FAIL) |
