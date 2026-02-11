# Specwright

Spec-driven app development with quality gates. Ensures the user gets what they asked for.

## Workflow

```
/sw-init → /sw-plan → /sw-build → /sw-verify → /sw-ship
```

| Skill | Purpose |
|-------|---------|
| `sw-init` | Project setup. Creates constitution + charter. Configures gates and hooks. |
| `sw-plan` | Triage, research, design, critic review, decompose. Produces specs. |
| `sw-build` | TDD implementation of one work unit. |
| `sw-verify` | Interactive quality gates. Shows findings, validates against spec. |
| `sw-ship` | Trunk-based merge to main. |
| `sw-guard` | Detect stack and interactively configure guardrails (hooks, CI, settings). |
| `sw-status` | Current state and progress. |
| `sw-learn` | Post-ship capture of patterns and learnings. |

## Anchor Documents

Two persistent documents drive all decisions:

- **`.specwright/CONSTITUTION.md`** -- Development practices. How the user wants code written. The AI MUST follow these.
- **`.specwright/CHARTER.md`** -- Technology vision. What this repo is, who consumes it, architectural invariants.

Both are created during init, referenced during plan, validated during verify.

## Architecture

- `skills/` -- SKILL.md files (goal + constraints, not procedures)
- `protocols/` -- Shared protocols for fragile operations (loaded on demand)
- `agents/` -- Agent prompt definitions
- `.specwright/` -- Runtime state, config, anchor docs, work artifacts

See `DESIGN.md` for the full architecture document.

## Protocols

Skills reference shared protocols in `protocols/` for fragile operations:
- `delegation.md` -- Agent delegation (custom subagents + agent teams)
- `state.md` -- Workflow state mutations and locking
- `git.md` -- Trunk-based git operations
- `recovery.md` -- Compaction recovery
- `evidence.md` -- Gate evidence format
- `gate-verdict.md` -- Verdict rendering with self-critique
- `context.md` -- Anchor doc and config loading
- `insights.md` -- External Claude Code insights data access

## Key Rules

- **NEVER** implement without a plan/spec loaded
- **NEVER** continue after compaction without reading `protocols/recovery.md`
- **NEVER** use `git add -A` -- stage specific files only
- **NEVER** hardcode language/framework assumptions -- read config
- Quality gates default to FAIL. Evidence must prove PASS.
- Constitution and charter are validated, not just referenced.
