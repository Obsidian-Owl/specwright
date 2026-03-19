# Headless Execution Protocol

How skills behave when running non-interactively (CI/CD, `claude -p`,
`opencode run`, GitHub Actions, or any context where AskUserQuestion
is unavailable).

## Detection

Detect headless context **at skill start** (before any work), not at the
first decision point. The skill probes AskUserQuestion availability once:

- If the tool is **not in the toolset**: the skill is running headlessly.
- If the tool **returns a rejection or error**: the skill is running headlessly.
- If the tool **is available and responds**: the skill is running interactively.

**Cache this detection for the remainder of the session.** Do not re-probe
at subsequent decision points. All remaining decisions use the headless
defaults from the policy table below.

**Clean runs**: Skills that complete without hitting any decision point still
write `headless-result.json` if headless mode was detected at startup. This
ensures CI pipelines always get a machine-readable result file.

Interactive sessions are never affected — this protocol only activates when
AskUserQuestion is genuinely unavailable.

## No Auto-Chaining

Headless skills NEVER auto-chain. Each skill invocation is independent.

- `sw-verify` running headlessly does NOT automatically invoke `sw-ship`.
- `sw-build` completing headlessly does NOT automatically invoke `sw-verify`.
- The calling system (CI pipeline, script, cron job, human) decides what
  runs next based on the results.

This preserves the stage-boundary protocol: each skill owns one stage.

## Default Policies

When running headlessly, use these defaults instead of prompting the user:

| Decision Type | Interactive Behavior | Headless Default | Rationale |
|--------------|---------------------|-----------------|-----------|
| Build failure (2 fix attempts exhausted) | Ask: fix now / skip / abort | **Abort** | Can't fix without human; continuing produces bad output. Partial progress is preserved on the branch. |
| Gate freshness check | Ask: re-run or keep stale results? | **Re-run** | Stale results are worse than redundant runs in CI. |
| Gate failure (FAIL or ERROR) | Ask: fix now / skip / abort | **Continue and report** | Record the FAIL, run remaining gates, write full report. Human reads the aggregate output. |
| Uncommitted changes before ship | Ask: commit them or abort? | **Abort** | Unexpected state; don't auto-commit unknown changes. |
| PR creation decision | Ask: create PR or merge directly? | **Create PR** | PRs are the universal human review checkpoint. |
| Stop/pause response to status card | User may say "stop" or "pause" | **N/A** | No user present; skill runs to completion. |
| Reset confirmation (sw-status --reset) | Ask: confirm destructive reset? | **Abort** | Destructive operation; don't auto-reset headlessly. |
| Cleanup directory selection (sw-status --cleanup) | Ask: which dirs to clean? | **Report-only** | List orphaned directories but do not delete them. |

## Output Requirements

When running headlessly, skills MUST persist all results — not just display them.

**Interactive mode**: skills can show findings and assume the user saw them.
**Headless mode**: there is no interactive display. Everything must be written
to disk so the calling system can read it.

Specifically:
- Gate evidence files → written to `{currentWork.workDir}/evidence/` (already happens)
- Aggregate report → written to evidence directory (already happens)
- Status cards → written to `.specwright/state/continuation.md` (already happens)
- Build task progress → written to `workflow.json` (already happens)

## Result Summary File

After headless completion, the skill writes `headless-result.json` to the
work directory (`{currentWork.workDir}/headless-result.json`):

```json
{
  "skill": "sw-verify",
  "status": "completed",
  "pass_rate": 0.8,
  "error": null,
  "gates": {
    "build": "PASS",
    "tests": "WARN",
    "security": "PASS",
    "wiring": "PASS",
    "spec": "FAIL"
  },
  "timestamp": "2026-03-19T22:00:00.000Z"
}
```

**Status values:**
- `"completed"` — skill ran to completion (gates may have findings)
- `"failed"` — skill encountered an unrecoverable error
- `"aborted"` — skill aborted due to headless policy (e.g., build failure, uncommitted changes)

This file is the machine-readable signal for CI systems:
- `"completed"` = skill finished. Check `pass_rate` if present.
- `"failed"` or `"aborted"` = block the pipeline.
- `pass_rate` threshold is **caller-defined** (not set by the protocol).
  CI pipelines should configure their own acceptance threshold.
  If no `pass_rate` is relevant (e.g., sw-ship, sw-status), the field is `null`.

## Platform Compatibility

This protocol works identically across platforms because it keys off
AskUserQuestion availability, not platform detection:

| Platform | Non-Interactive Mode | AskUserQuestion Signal |
|----------|---------------------|----------------------|
| Claude Code `-p` | Single prompt, exits | Not in toolset → headless |
| Opencode `run` | Single prompt, exits | Auto-rejected → headless |
| GitHub Action (Claude) | Event-triggered | Not in toolset → headless |
| Opencode GitHub | Event-triggered | Auto-rejected → headless |
| Interactive session | Normal TUI | Available → interactive (protocol not activated) |

## Skills That Reference This Protocol

| Skill | Headless Constraint Added |
|-------|--------------------------|
| `sw-build` | Build failure → abort |
| `sw-verify` | Skip freshness, gate failure → continue and report |
| `sw-ship` | Uncommitted → abort, always create PR |
| `sw-status` | Reset → abort, cleanup → report-only |

Gate skills (gate-build, gate-tests, gate-security, gate-wiring, gate-spec)
and all agents are already fully headless — no AskUserQuestion in their
toolset. They do not need to reference this protocol.
