# Inventory: Unit 06 — sw-build Concerns

## Current concerns in `core/skills/sw-build/SKILL.md`

| Concern | Current section | Disposition |
|---|---|---|
| Branch lifecycle | `Branch setup` | KEEP in sw-build |
| Per-task loop orchestration | `Task loop` | KEEP in sw-build, compressed |
| TDD sequence | `TDD cycle` | KEEP in sw-build as RED → GREEN → REFACTOR |
| Repo map generation | `Repo map generation` | RELOCATE out of sw-build body |
| Language-pattern injection | `Context envelope` | RELOCATE to delegation/executor loading |
| Per-task integration delegation | `TDD cycle` | MOVE out of per-task loop into optional after-build phase |
| Per-task regression check | `TDD cycle` | MOVE out of per-task loop into optional after-build phase |
| Build failure recovery | `Build failures` | KEEP in sw-build, compressed |
| Commit discipline | `Commits` | KEEP in sw-build |
| Mid-build quality checks | `Mid-build checks` | KEEP only as brief protocol reference |
| Per-task semantic micro-check | `Per-task micro-check` | DELETE from sw-build body |
| Post-build review | `Post-build review` | KEEP as optional after-build phase |
| End-of-unit integration validation | `Inner-loop validation` | KEEP as optional after-build phase |
| Parallel execution | `Parallel execution` | DEMOTE to config-gated sentence |
| As-built notes | `As-built notes` | KEEP as brief protocol reference |
| State updates | `State updates` | KEEP as brief protocol reference |
| Continuation/status-card mechanics | `Context management` | RELOCATE out of sw-build body |
| Task tracking | `Task tracking` | DEMOTE to one short paragraph |

## Target shape

The flattened skill body should center on four core concerns:

1. Branch setup
2. TDD cycle
3. Commit discipline
4. Gate handoff

Everything else either moves into:
- `protocols/delegation.md`
- `core/agents/specwright-executor.md`
- one optional `After-build` section
- a brief reference paragraph
- or deletion from the sw-build body

## Behavior change to preserve explicitly

The risky shift is moving integration and regression checks out of the
per-task TDD loop and into a single end-of-unit `After-build` phase.
That needs matching test updates so the new order of operations is
enforced rather than implied.
