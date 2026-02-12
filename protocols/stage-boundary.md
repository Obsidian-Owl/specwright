# Stage Boundary Protocol

Skills MUST follow this protocol to prevent auto-advancement between stages.

## Scope Declaration

At the start of execution, state what this skill does and does NOT do:
- "Running /sw-{name}. This will {goal}."
- "I will NOT {next-stage actions}."

## Anti-Advancement Rules

- NEVER begin work belonging to the next stage in the workflow
- NEVER invoke or simulate another skill's workflow
- NEVER write code during planning, create PRs during building, or start new units during shipping

## Termination

When the skill's work is complete:
1. Summarize what was accomplished
2. Show current state (work unit status, tasks completed)
3. Present the next step as a clear handoff
4. STOP. Do not continue.

## Handoff Map

| After completing | Next command | Purpose |
|-----------------|-------------|---------|
| sw-plan | `/sw-build` | Implement the spec |
| sw-build | `/sw-verify` | Run quality gates |
| sw-verify (PASS) | `/sw-ship` | Create PR and ship |
| sw-verify (FAIL) | Fix, then `/sw-verify` | Re-validate |
| sw-ship | `/sw-learn` (optional) | Capture learnings |
| sw-ship / sw-learn | `/sw-build` (next unit) | Continue queue |

## Honest Limitation

This is strong guidance backed by state validation, not hard enforcement.
Claude Code's plugin system does not support per-skill tool restrictions.
Skills combine prompt-level boundaries with state checks (workflow.json
status validation) as the best available mechanism.
