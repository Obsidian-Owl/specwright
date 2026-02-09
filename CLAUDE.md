# Specwright: Spec-Driven Development

This project uses Specwright for disciplined, spec-driven development with quality gates.

## Configuration

Read `.specwright/config.json` for all project-specific commands, architecture rules, and conventions. NEVER hardcode language or framework assumptions.

## Core Workflow

```
/specwright:init → /specwright:specify → /specwright:build → /specwright:validate → /specwright:ship
```

### 1. Initialize (`/specwright:init`)
Interactive wizard that configures your project. Run once. Creates `.specwright/` directory with config, templates, constitution, and state.

### 2. Specify (`/specwright:specify <epic-id>`)
Creates spec.md, plan.md, and tasks.md for an epic. Loads constitution and patterns for context. User approves spec before proceeding to build.

### 3. Build (`/specwright:build [epic-id] [task-id]`)
TDD implementation loop. Builds one task at a time: RED (failing test) → GREEN (pass) → REFACTOR. Commits per task. Acquires pipeline lock.

### 4. Validate (`/specwright:validate [--gate=<name>]`)
Runs quality gates sequentially. Gates are configurable in config.json. Each gate produces evidence in `.specwright/epics/{id}/evidence/`.

### 5. Ship (`/specwright:ship`)
Creates PR with evidence mapping. Verifies all gates passed. Runs final code review. Updates workflow state.

## Supporting Skills

| Skill | Purpose | Trigger |
|-------|---------|---------|
| `/specwright:roadmap` | Domain-level planning with complexity scoring | "plan domain", "roadmap" |
| `/specwright:status` | Show current workflow state and progress | "status", "where am I" |
| `/specwright:constitution` | Edit project principles | "edit principles", "constitution" |
| `/specwright:learn-review` | Review captured learnings from build failures | "review learnings" |
| `/specwright:learn-consolidate` | Auto-group and promote patterns | "consolidate learnings" |

## Quality Gates

| Gate | What It Checks | Skill |
|------|---------------|-------|
| Build | Build + test commands pass | `/specwright:gate-build` |
| Tests | Test quality, coverage, assertions | `/specwright:gate-tests` |
| Wiring | Dead code, unused exports, integration | `/specwright:gate-wiring` |
| Security | Secrets, injection, sensitive data | `/specwright:gate-security` |
| Spec | Acceptance criteria coverage | `/specwright:gate-spec` |

## State & Memory

All state lives in `.specwright/`:
- `config.json` — Project configuration (languages, commands, architecture)
- `memory/constitution.md` — Non-negotiable development principles
- `memory/patterns.md` — Cross-epic learnings and established patterns
- `state/workflow.json` — Active epic, gate results, pipeline lock
- `state/learning-queue.jsonl` — Captured build failures for review
- `epics/{id}/` — Epic artifacts (spec.md, plan.md, tasks.md, evidence/)
- `templates/` — Customizable document templates

## Compaction Recovery Protocol

**CRITICAL:** After compaction (context window reset), IMMEDIATELY:

1. Read `.specwright/state/workflow.json` to recover active epic context
2. If `currentEpic` exists and status is not "complete":
   - Read `{specDir}/spec.md` for requirements
   - Read `{specDir}/plan.md` for architecture context
   - Read `{specDir}/tasks.md` for task list and progress
   - Check `tasksCompleted` array to find where you left off
3. Read `.specwright/memory/constitution.md` for project principles
4. Resume from the last checkpoint

**NEVER continue work after compaction without reloading spec artifacts.**

## Pipeline Locking

Build and validate skills acquire a pipeline lock in `workflow.json` to prevent concurrent runs:
- Lock includes skill name and timestamp
- Stale locks (>30 minutes) auto-clear
- Force unlock: `/specwright:validate --unlock`

## Agent Delegation

Specwright uses specialized agents for different tasks:

| Agent | Model | Role |
|-------|-------|------|
| architect | opus | Spec review, architecture decisions, quality verification |
| executor | sonnet | TDD implementation, one task at a time |
| code-reviewer | opus | Spec compliance, code quality review |
| build-fixer | sonnet | Minimal fixes for build/test failures |
| researcher | sonnet | Documentation lookup, technical research |

### OMC Integration
If oh-my-claudecode is installed (detected via `config.json` `integration.omc`):
- Use OMC tiered agents: `Task(subagent_type="oh-my-claudecode:{agent}", ...)`
- Respects OMC execution modes (ultrawork, ecomode)

If OMC is NOT installed:
- Use native Claude Code: `Task(prompt="...", model="{model}")`

## Anti-Patterns

- **NEVER** implement without loading spec artifacts first
- **NEVER** skip the TDD cycle (test must fail before implementation)
- **NEVER** mark a task complete without build + test verification
- **NEVER** assume language/framework — always read config.json
- **NEVER** auto-promote learnings — human approval required
- **NEVER** continue after compaction without rereading state
- **NEVER** use `git add -A` — stage specific files only
