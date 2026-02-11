# Specwright

**Craft quality software with AI discipline**

Specwright is a Claude Code plugin for spec-driven app development. It ensures you get what you asked for by combining specification planning, test-driven development, quality gates, and evidence capture into a cohesive workflow.

AI agents optimise for done. Specwright optimises for works.

## Why Specwright?

Most AI development frameworks focus on the specification phase. Specwright closes the entire loop:

| Feature | Specwright | Competitors |
|---------|-----------|-------------|
| Full workflow loop | plan → build → verify → ship → learn | plan only |
| Anchor documents | Constitution + Charter persist context | session-based only |
| Adversarial critique | Every plan challenged by critic agent | rarely included |
| Spec compliance gate | Maps every requirement to code + tests | not verified |
| Adversarial testing | Tester writes hard-to-pass tests | standard mocks |
| Learning system | Patterns promoted from real development | manual documentation |

## Installation

In Claude Code, add the marketplace and install the plugin:
```
/plugin marketplace add Obsidian-Owl/specwright
/plugin install specwright@specwright
```

## Quick Start

Initialize your project:
```
/sw-init
```

Create a specification:
```
/sw-plan payment-integration
```

Build with test-first discipline:
```
/sw-build payment-integration
```

Verify quality and ship:
```
/sw-verify
/sw-ship payment-integration
```

## Workflow

```
   /init          /plan         /build      /verify       /ship      /learn
    |              |              |            |             |          |
    v              v              v            v             v          v
 CONFIG  ->   SPECIFICATION  ->  TDD  ->  QUALITY GATES  ->  PR  ->  PATTERNS
  Auto        Deep research    RED-GREEN  5 gate suite    Evidence   Promote to
 Configure    Critic review    REFACTOR   findings       mapping    Constitution
  Gates       Decompose       Per-task   Spec compli-
             User checkpoints  commits    ance proof
```

## Skills

**User-Facing** (7 core skills):
- `/sw-init` — Project configuration and setup
- `/sw-plan` — Specification with triage, research, design, critic, decompose
- `/sw-build` — TDD implementation with test-first discipline
- `/sw-verify` — Interactive quality gates with findings
- `/sw-ship` — Trunk-based PR with evidence mapping
- `/sw-status` — Workflow progress and state
- `/sw-learn` — Pattern capture and promotion

**Quality Gates** (5 gates, configurable):
- `gate-build` — Compilation, test pass (BLOCK)
- `gate-tests` — Coverage, assertions, structure (BLOCK/WARN)
- `gate-security` — Secrets, injection, sensitive data (BLOCK)
- `gate-wiring` — Dead code, unused exports, layer violations (WARN)
- `gate-spec` — Every acceptance criterion has evidence (BLOCK)

## Key Features

**Anchor Documents** — Two persistent documents drive all decisions:
- `CONSTITUTION.md` — Development practices the AI must follow
- `CHARTER.md` — Technology vision and architectural invariants

**Evidence Trail** — Every gate run produces timestamped artifacts for audit and learning.

**Compaction Recovery** — All stateful skills support resume-from-crash. Partial progress is preserved.

**Agents** — Six specialized agents handle creative work:
- architect (opus) — Strategic design advisor
- tester (opus) — Adversarial test engineer. Writes tests that are genuinely hard to pass.
- executor (sonnet) — TDD implementation
- reviewer (opus) — Spec compliance verification
- build-fixer (sonnet) — Auto-fix build failures
- researcher (sonnet) — Documentation lookup

## Configuration

Specwright reads project configuration from `.specwright/config.json`:

```json
{
  "project": { "name": "...", "languages": [...] },
  "architecture": { "style": "layered|hexagonal|modular" },
  "commands": { "build": "...", "test": "...", "lint": "..." },
  "gates": { "enabled": ["build", "tests", "wiring", "security", "spec"] }
}
```

All configuration is project-specific. Specwright never assumes language, framework, or architecture.

## Architecture

See `DESIGN.md` for the complete architecture document.

```
specwright/
├── skills/       # 12 SKILL.md files (7 user + 5 gates)
├── protocols/    # Shared protocols (loaded on demand)
├── agents/       # Custom subagent definitions
├── hooks/        # Session lifecycle hooks
├── DESIGN.md     # Full architecture
└── README.md
```

## Contributing

Specwright is open source and community-driven.

To contribute:
1. Fork the repository at github.com/Obsidian-Owl/specwright
2. Create a feature branch
3. Make your changes
4. Ensure tests pass
5. Submit a pull request

See `CLAUDE.md` for development guidelines.

## License

MIT License. Copyright (c) 2026 ObsidianOwl.

---

**Version**: 0.2.0
**Author**: ObsidianOwl
**Repository**: https://github.com/Obsidian-Owl/specwright
