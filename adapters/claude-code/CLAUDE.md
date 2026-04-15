# Specwright

Spec-driven app development with quality gates. Ensures the user gets what they asked for.

## Workflow

```
/sw-init → /sw-design → /sw-plan → /sw-build → /sw-verify → /sw-ship
```

| Skill | Purpose |
|-------|---------|
| `sw-init` | Project setup. Creates constitution + charter. Configures gates and hooks. |
| `sw-research` | Deep outward-facing research. External docs, APIs, patterns, validation. Produces referenced briefs. |
| `sw-design` | Interactive solution architecture. Research, design, adversarial critic, assumption surfacing. |
| `sw-plan` | Decompose design into work units with testable specs. |
| `sw-build` | TDD implementation of one work unit. |
| `sw-verify` | Interactive quality gates. Shows findings, validates against spec. |
| `sw-ship` | Strategy-aware merge via PR. |
| `sw-debug` | Investigation-first debugging. Scope → investigate → diagnose → fix/log/defer. |
| `sw-pivot` | Mid-build course correction. Revises remaining tasks via architect; append-only. |
| `sw-doctor` | Read-only installation health check. 12 checks, repair hints. |
| `sw-guard` | Detect stack, gap-analyze against 10 quality dimensions, configure guardrails across 4 layers. |
| `sw-status` | Current state and progress. Supports `--cleanup` to remove orphaned work directories. |
| `sw-learn` | Post-ship capture of patterns and learnings. Clears workflow state after persistence. |
| `sw-audit` | Periodic codebase health check. Finds systemic tech debt. |
| `sw-sync` | Git housekeeping. Fetch, prune stale branches, sync with remote. |
| `sw-review` | PR comment review. Fetch all comment types, group by status, respond inline. |

## Anchor Documents

Three persistent documents drive all decisions:

- **`{repoStateRoot}/CONSTITUTION.md`** -- Development practices. How the user wants code written. The AI MUST follow these.
- **`{repoStateRoot}/CHARTER.md`** -- Technology vision. What this repo is, who consumes it, architectural invariants.
- **`{repoStateRoot}/TESTING.md`** -- Testing strategy. How the project should be tested, what boundaries exist, what may be mocked. Optional — created during init if the user opts in.

Constitution and Charter are created during init. TESTING.md is created during init if the user opts in. All are referenced during design and plan, validated during verify. Precedence: Constitution (rules) > Testing Strategy (approach) > patterns.md (reference). Constitution always wins on conflict.

## Architecture

- `skills/` -- SKILL.md files (goal + constraints, not procedures)
- `protocols/` -- Shared protocols for fragile operations (loaded on demand)
- `agents/` -- Agent prompt definitions (7 agents: architect, tester, integration-tester, executor, reviewer, build-fixer, researcher)
- `repoStateRoot` (`git rev-parse --git-common-dir` + `/specwright`) -- shared config, anchor docs, research, and per-work artifacts
- `worktreeStateRoot` (`git rev-parse --git-dir` + `/specwright`) -- current worktree session and continuation state

See `DESIGN.md` for the full architecture document.

## Protocols

Skills reference shared protocols in `protocols/` for fragile operations:
- `stage-boundary.md` -- Stage scope, termination, and handoff enforcement
- `delegation.md` -- Agent delegation (custom subagents + agent teams)
- `state.md` -- Workflow state, work unit queue, and transition validation
- `git.md` -- Strategy-aware git operations (branch lifecycle, commits, PRs)
- `git-freshness.md` -- Shared branch freshness checkpoint contract and result semantics
- `approvals.md` -- Durable human approval scopes, hashing, freshness, and headless constraints
- `review-packet.md` -- Reviewer-facing audit packet structure, synthesis rules, and publication-mode constraints
- `recovery.md` -- Compaction recovery
- `evidence.md` -- Gate evidence format, freshness, and verdict rendering
- `context.md` -- Anchor doc and config loading
- `insights.md` -- External Claude Code insights data access
- `learning-lifecycle.md` -- Compaction triggers and tiered memory
- `landscape.md` -- Codebase reference document format and freshness rules
- `audit.md` -- Codebase health findings format, IDs, and lifecycle
- `research.md` -- External research brief format, confidence scoring, and lifecycle
- `build-quality.md` -- Post-build review and as-built notes
- `build-context.md` -- Continuation snapshots, status cards, and context nudge for sw-build
- `backlog.md` -- Backlog item format, BL-{n} IDs, markdown and GitHub Issues targets
- `spec-review.md` -- Spec quality review dimensions (7), finding levels, resolution flow
- `testing-strategy.md` -- Testing strategy lifecycle: TESTING.md creation, consumption, boundary classifications
- `headless.md` -- Non-interactive execution: detection, default policies, result summary format
- `decision.md` -- Autonomous decision framework: reversibility classification, heuristics, convergence loop, assumption lifecycle, CCR, decision records
- `parallel-build.md` -- Parallel task execution with agent teams (experimental)
- `guardrails-detection.md` -- Three-step stack detection: manifest scan, config file scan, guardrail scan
- `guardrails-patterns.md` -- Ten-dimension coverage model, four-layer enforcement patterns
- `repo-map.md` -- Repo map format, generation method, token budget, and truncation rules for build context

## Key Rules

- **NEVER** implement without a plan/spec loaded
- **NEVER** continue after compaction without reading `protocols/recovery.md`
- **NEVER** use `git add -A` -- stage specific files only
- **NEVER** hardcode language/framework assumptions -- read config
- Quality gates default to FAIL. Evidence must prove PASS.
- Six internal gates: build, tests, security, wiring, semantic, spec.
- Constitution and charter are validated, not just referenced.
