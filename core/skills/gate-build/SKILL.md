---
name: gate-build
description: >-
  Runs configured build and test commands. Captures output as evidence.
  Returns PASS if commands exit 0, FAIL otherwise. Internal gate — invoked
  by verify, not directly by users.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Write
---

# Gate: Build

## Goal

Confirm the codebase compiles and tests pass. This is the most basic gate —
if the code doesn't build or tests don't pass, nothing else matters.

## Inputs

- `.specwright/config.json` -- `commands.build` and `commands.test`
- `.specwright/state/workflow.json` -- current work unit for evidence path

## Outputs

- Evidence file at `{currentWork.workDir}/evidence/build-report.md`
- Gate status update in workflow.json: PASS, FAIL, or ERROR
- Console output showing results inline (users see findings, not just badges)

## Constraints

**Execution (LOW freedom):**
- Read build command from `config.json` `commands.build`. Run it. Capture output.
- Read test command from `config.json` `commands.test`. Run it. Capture output.
- If a command is null/missing, SKIP that check (not FAIL).
- If both commands are null, gate status is SKIP.
- Timeout: 5 minutes per command. If exceeded, status is ERROR.

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md` for verdict rendering.
- Build exit code 0 + test exit code 0 = PASS.
- Any non-zero exit code = FAIL.
- Show failing output inline so the user sees what broke.

**Evidence (LOW freedom):**
- Follow `protocols/evidence.md` for file format and storage.
- Write evidence file with: command run, exit code, stdout/stderr, timestamp.
- Update `workflow.json` gates section per `protocols/state.md`.

## Protocol References

- `protocols/gate-verdict.md` -- default-FAIL, self-critique, visibility
- `protocols/evidence.md` -- evidence storage and freshness
- `protocols/state.md` -- gate status updates

## Failure Modes

| Condition | Action |
|-----------|--------|
| Build command not configured | SKIP build check, continue to test check |
| Test command not configured | SKIP test check |
| Both commands null | Gate status = SKIP |
| Command times out (>5min) | Gate status = ERROR with timeout message |
