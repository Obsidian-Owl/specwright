# Stage Boundary Protocol

Skills MUST follow this protocol to prevent auto-advancement between stages.

## Scope Declaration

At the start of execution, state what this skill does and does NOT do:
- "Running /sw-{name}. This will {goal}."
- "I will NOT {next-stage actions}."

## Anti-Advancement Rules

- NEVER begin work belonging to the next stage in the workflow
- NEVER invoke or simulate another skill's workflow
- NEVER write specs during designing, write code during planning, create PRs during building, or start new units during shipping

## Termination

When the skill's work is complete:
1. Summarize what was accomplished
2. Show current state (work unit status, tasks completed)
3. Present the next step as a clear handoff
4. STOP. Do not continue.

## Handoff Map

| After completing | Next command | Purpose |
|-----------------|-------------|---------|
| sw-design | `/sw-plan` | Break design into work units with specs |
| sw-plan | `/sw-build` | Implement the spec |
| sw-build | `/sw-verify` | Run quality gates |
| sw-verify (PASS) | `/sw-ship` | Create PR and ship |
| sw-verify (FAIL) | Fix, then `/sw-verify` | Re-validate |
| sw-ship | `/sw-build` (next unit) or `/sw-design` (new work) | Continue queue or start fresh |
| sw-ship | `/sw-learn` (optional side path) | Capture learnings before moving on. Never required. |

## Blocked Operations by State

| State | Blocked Operations | Why |
|-------|--------------------|-----|
| `building` | `gh pr create`, `gh api .*/pulls` (POST), `curl.*api.github.com.*/pulls` | PRs are only created during shipping |
| `verifying` | `gh pr create`, `gh api .*/pulls` (POST), `curl.*api.github.com.*/pulls` | Ship after gates pass, not during verification |

On Claude Code, these are enforced by a PreToolUse hook on Bash (`pre-ship-guard.mjs`).
On all platforms, `protocols/state.md` enforces that only the `shipping` state
permits PR creation via the transition table.

## Honest Limitation

Enforcement is layered: state validation (both platforms) + PreToolUse hook
(Claude Code only). Claude Code has deterministic hook-level enforcement that
blocks PR creation commands when workflow status is not `shipping`. Opencode
has protocol-level enforcement only — no pre-tool hooks are available.
Skills combine prompt-level boundaries with state checks (workflow.json
status validation) as the best available mechanism.
