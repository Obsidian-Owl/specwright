# Specwright

**Bring engineering discipline to AI-assisted development**

Specwright is a Claude Code plugin that brings spec-driven development to AI-powered projects. It combines specification-first planning, test-driven development, 5-tier quality gates, evidence capture, learning loops, and compaction recovery into a cohesive workflow that helps AI agents and humans collaborate effectively on large, complex features.

## Overview

Specwright addresses a fundamental challenge in AI-assisted development: **how to maintain engineering discipline while leveraging AI productivity**. It does this by:

- **Specification First**: Write detailed specs before code. AI works from clear, measurable acceptance criteria.
- **Test-Driven Implementation**: Enforce RED-GREEN-REFACTOR discipline. Every feature starts with a failing test.
- **Quality Gates**: 5 configurable gates (build, tests, wiring, security, spec) verify quality before merge.
- **Evidence Capture**: Every gate run produces timestamped evidence artifacts, creating an audit trail of what was tested.
- **Learning System**: Capture patterns from build failures and successes. Promote valuable patterns to reusable templates.
- **Compaction Recovery**: Every stateful skill supports resume-from-crash. No lost progress.
- **Language & Framework Agnostic**: Works with any project. Configuration drives behavior, not assumptions.

Specwright is production-ready and designed for large teams building mission-critical features.

## Quick Start

### Installation

```bash
claude plugin add specwright@ObsidianOwl/specwright
```

### Initialize Your Project

```
/specwright:init
```

The interactive wizard will ask about:
- Your project structure (monorepo, single app, etc.)
- Build and test commands
- Architecture style (layered, hexagonal, etc.)
- Which quality gates to enable
- Development principles (your project constitution)

### Create Your First Epic

```
/specwright:specify payment-integration
```

Specwright will generate:
- `spec.md` — Detailed specification with user stories, acceptance criteria, architecture decisions
- `plan.md` — Ordered implementation plan with complexity scoring
- `tasks.md` — Task breakdown with test requirements and acceptance criteria

### Build the Epic

```
/specwright:build payment-integration
```

Specwright will:
1. Write a failing test for the first task (RED)
2. Implement minimal code to pass it (GREEN)
3. Refactor to improve quality (REFACTOR)
4. Verify all quality gates pass
5. Commit and move to the next task
6. Repeat until epic is complete

### Validate and Ship

```
/specwright:validate
/specwright:ship payment-integration
```

Validate runs all configured quality gates and produces evidence. Ship creates a pull request with full evidence mapping and runs final code review.

## Core Workflow

```
┌─────────────┐
│   /init     │  Configure project, architecture, gates
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│   /specify      │  Write spec, plan, tasks
│  <epic-id>      │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│    /build       │  TDD loop: RED-GREEN-REFACTOR
│   <epic-id>     │  Task by task, commit after each
└──────┬──────────┘
       │
       ▼
┌──────────────────┐
│   /validate      │  Run 5 quality gates
│  [--gate=name]   │  Produce evidence artifacts
└──────┬───────────┘
       │
       ▼
┌──────────────────┐
│    /ship         │  Create PR with evidence
│   <epic-id>      │  Final code review
└──────────────────┘
```

## Skills Reference

Specwright includes 15 skills across 4 categories:

### Core Workflow Skills (5)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/specwright:init` | Start of project | Initialize Specwright in your project. Interactive wizard that configures spec-driven development with quality gates, learning, and compaction recovery. |
| `/specwright:specify` | `<epic-id>` | Epic specification. Produces spec.md, plan.md, and tasks.md for one epic with user stories, architecture decisions, and complexity-scored task breakdown. |
| `/specwright:build` | `[epic-id] [task-id]` | TDD implementation loop. Builds each task from the epic tasks.md with test-first discipline, wiring verification, and progress tracking. |
| `/specwright:validate` | `[--gate=<name>]` | Quality gates orchestrator. Runs enabled gate skills sequentially with evidence management, freshness checks, and pipeline locking. |
| `/specwright:ship` | `<epic-id>` | Evidence-based PR creation. Verifies all gates passed, commits remaining changes, creates PR with evidence mapping, and runs final code review. |

### Planning Skills (2)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/specwright:roadmap` | `<domain>` | Domain-level planning. Analyzes scope, scores complexity per epic, flags oversized epics for splitting, and produces an ordered roadmap. |
| `/specwright:constitution` | `[add\|edit\|remove\|view]` | View and edit project development principles. Add, modify, or remove principles from the constitution with interactive approval. |

### Quality Gate Skills (5)

| Skill | What It Checks | Output |
|-------|----------------|--------|
| `/specwright:gate-build` | Build and test commands from config | Build output, test results, exit code |
| `/specwright:gate-tests` | Test quality (coverage, assertions, structure) | Test analysis report with tier-1/2/3 findings |
| `/specwright:gate-wiring` | Dead code, unused exports, architecture violations | Wiring analysis with layer violation flags |
| `/specwright:gate-security` | Secrets, injection vulnerabilities, sensitive patterns | Security findings with severity levels |
| `/specwright:gate-spec` | Acceptance criteria coverage and mapping | Spec compliance matrix with evidence references |

All gates produce timestamped evidence in `.specwright/epics/{epic-id}/evidence/`.

### Learning Skills (2)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/specwright:learn-review` | `[--all]` | Review captured learnings from the queue. Groups by category, promotes to patterns.md or CLAUDE.md Memories, or dismisses to archive. |
| `/specwright:learn-consolidate` | `[--dry-run\|--force]` | Consolidate learning queue into reusable patterns. Groups similar entries, scores by frequency and recency, promotes top candidates to patterns.md. |

### Status Skill (1)

| Skill | Trigger | Description |
|-------|---------|-------------|
| `/specwright:status` | No args | Show current Specwright workflow status. Displays active epic, task progress, gate results, and learning queue size. |

## Quality Gates

Specwright enforces 5 configurable quality gates before merge. Each produces evidence artifacts.

| Gate | Severity | When It Runs | What It Verifies | Outcome |
|------|----------|--------------|------------------|---------|
| **Build** | BLOCK | After each task | Build command succeeds, output clean | Blocks merge if build fails |
| **Tests** | BLOCK | After each task | Test command passes, coverage threshold met | Blocks merge if tests fail or coverage too low |
| **Wiring** | WARN | Before validate | No dead code, no unused exports, architecture layers respected | Warns about integration issues; allows merge with warnings |
| **Security** | BLOCK | Before validate | No leaked secrets, no injection patterns, sensitive files protected | Blocks merge if secrets detected; warns on high-risk patterns |
| **Spec** | BLOCK | Before ship | Every acceptance criterion has implementation and test evidence | Blocks PR creation if criteria unmapped |

Gates are composable — enable only the gates you need. Evidence is captured for audit and learning.

## Learning System

Specwright automatically captures insights from every build run:
- Build failures → root cause, fix applied, time to fix
- Test results → passing/failing patterns, coverage changes
- Gate violations → what triggered warnings/blocks
- Architecture decisions → why code was structured a certain way

These learnings flow into a queue that can be reviewed and promoted to patterns:

1. **Review** (`/specwright:learn-review`) — Batch-process captured learnings
2. **Triage** — Categorize as "pattern" (reusable), "warning" (watch for), or "dismiss"
3. **Consolidate** (`/specwright:learn-consolidate`) — Auto-group similar entries, score by frequency
4. **Promote** — High-confidence patterns graduate to `patterns.md` for reuse in future specs

This creates a growing library of project-specific best practices, automatically discovered from real development.

## Configuration

Specwright configuration lives in `.specwright/config.json`. The schema includes:

```json
{
  "project": {
    "name": "my-project",
    "description": "...",
    "languages": ["typescript", "python"],
    "frameworks": ["react", "express"]
  },
  "architecture": {
    "style": "layered|hexagonal|modular",
    "layers": ["api", "service", "domain", "infra"]
  },
  "commands": {
    "build": "npm run build",
    "test": "npm test",
    "lint": "npm run lint"
  },
  "gates": {
    "enabled": ["build", "tests", "wiring", "security", "spec"],
    "build": { "timeout": 300 },
    "tests": { "minCoverage": 80, "minAssertions": 3 },
    "security": { "sastTool": "eslint --plugin security" },
    "spec": { "requireEvidence": true }
  },
  "git": {
    "prTool": "gh|glab|none",
    "commitFormat": "conventional|simple"
  },
  "integration": {
    "omc": true,
    "agents": ["architect", "executor", "code-reviewer"]
  }
}
```

All configuration is project-specific. Specwright never assumes language, framework, or architecture — it reads config and adapts.

## Agents

Specwright delegates specialized work to 5 purpose-built agents. All are optional; the core workflow runs without them.

| Agent | Model | Purpose | Key Constraint |
|-------|-------|---------|-----------------|
| **architect** | Opus | Strategic architecture advisor. Reviews specs, verifies design decisions, analyzes quality. | READ-ONLY. No code changes. |
| **executor** | Sonnet | Focused task executor. Builds exactly one task at a time using TDD. | No subagents. Pure implementation. |
| **code-reviewer** | Opus | Spec compliance reviewer. Verifies implementation matches spec and project standards. | READ-ONLY. Review findings only. |
| **build-fixer** | Sonnet | Auto-fix build and test failures with minimal changes. Get green builds back quickly. | Minimal fixes only. No refactoring. |
| **researcher** | Sonnet | Documentation and reference researcher. Fetches official docs and verifies technical info. | READ-ONLY. Research only. |

Agents integrate with oh-my-claudecode for delegation. Each agent has a specialized role and cannot be misused.

## Hooks

Specwright includes 3 hook scripts that run automatically during sessions:

| Hook | Event | Purpose |
|------|-------|---------|
| **session-start.mjs** | SessionStart | Initialize session state, check config validity, prepare workflow state |
| **safety-guard.mjs** | PreToolUse (Bash, Edit, Write) | Verify pipeline lock status, detect uncommitted changes, prevent concurrent runs |
| **capture-learning.mjs** | PostToolUse (Bash) | Auto-capture learnings from command output: build failures, test results, error patterns |

Hooks run with 3-10 second timeouts and degrade gracefully if unavailable.

## OMC Integration

Specwright is compatible with oh-my-claudecode (OMC) in two modes:

1. **Standalone Mode** — Use Specwright alone without OMC. Skills work directly, agents are unavailable.
2. **OMC Integration Mode** — Specwright delegates to OMC agents (architect, executor, etc.) for specialized work. Set `integration.omc: true` in config.

In OMC mode, `/specwright:build` automatically delegates task execution to the executor agent, `/specwright:validate` uses the architect for design verification, and `/specwright:ship` runs code review through the code-reviewer agent.

## Templates

Specwright includes 6 templates that are populated during initialization:

- **constitution-template.md** — Project development principles
- **spec-template.md** — Epic specification format
- **plan-template.md** — Implementation plan format
- **tasks-template.md** — Task breakdown format
- **context-template.md** — Agent context envelope
- **pr-template.md** — Pull request template with evidence sections

Templates are customizable per project. Specwright reads them during spec generation and populates with epic-specific details.

## Directory Structure

After initialization, your project includes:

```
.specwright/
├── config.json                 # Project configuration
├── memory/
│   ├── constitution.md         # Project principles
│   └── patterns.md             # Discovered patterns
├── epics/
│   ├── payment-integration/
│   │   ├── spec.md
│   │   ├── plan.md
│   │   ├── tasks.md
│   │   └── evidence/           # Gate results
│   └── ...
└── state/
    ├── workflow.json           # Current epic, task progress
    ├── learning-queue.jsonl    # Captured learnings
    └── pipeline.lock           # Prevents concurrent runs
```

## Advanced Features

### Compaction Recovery

Every stateful skill supports resume-from-crash. If a skill terminates unexpectedly, run it again and it will:
1. Detect previous partial progress
2. Skip completed work
3. Resume from the last checkpoint
4. Verify integrity of skipped work

This allows safe recovery without data loss or re-running expensive operations.

### Pipeline Locking

Specwright prevents concurrent runs with pipeline locking. The first skill to run acquires a lock; other sessions wait or fail fast. Locks auto-expire after 30 minutes to prevent stale locks.

Use `--unlock` to force-clear a stuck lock:
```
/specwright:validate --unlock
```

### Evidence Trails

Every gate run produces timestamped evidence artifacts in `.specwright/epics/{id}/evidence/`:
- `build-output-{timestamp}.log` — Build command output
- `test-results-{timestamp}.json` — Parsed test results
- `spec-coverage-{timestamp}.md` — Acceptance criteria coverage matrix
- `security-findings-{timestamp}.md` — Security gate findings

These create a complete audit trail for compliance, debugging, and learning.

## Contributing

Specwright is open source and community-driven.

To contribute:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Ensure all tests pass
5. Submit a pull request

For major features or architectural changes, please open an issue first to discuss approach.

See `CLAUDE.md` for development guidelines.

## License

MIT License. Copyright (c) 2026 ObsidianOwl. See LICENSE file for details.

## Support

- **Documentation**: See [Specwright Architecture](./docs) for deep dives
- **Issues**: Report bugs and request features on GitHub
- **Discussions**: Ask questions in the discussions forum

---

**Version**: 0.1.0
**Author**: ObsidianOwl
**Repository**: https://github.com/ObsidianOwl/specwright
