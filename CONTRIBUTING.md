# Contributing to Specwright

Thanks for your interest in contributing! Specwright is an open-source Claude Code plugin and we welcome bug reports, feature suggestions, and pull requests.

## Reporting Bugs

Open a [bug report issue](https://github.com/Obsidian-Owl/specwright/issues/new?template=bug_report.md) with:

- Your Claude Code version (`claude --version`)
- Specwright version (check `skills/sw-init/SKILL.md` frontmatter or the latest release)
- Steps to reproduce the problem
- What you expected vs what happened
- Any error output or screenshots

## Suggesting Features

Open a [feature request issue](https://github.com/Obsidian-Owl/specwright/issues/new?template=feature_request.md) describing:

- The use case or problem you're solving
- Your proposed solution
- Alternatives you've considered

## Submitting Pull Requests

1. Fork the repo and create a feature branch from `main`
2. Make your changes (see Architecture below for orientation)
3. Test your changes by running the affected skills in a real project
4. Submit a PR with a clear description of what changed and why

### Commit Conventions

Use [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` new functionality
- `fix:` bug fixes
- `docs:` documentation changes
- `refactor:` code restructuring without behaviour change
- `chore:` maintenance tasks

## Architecture Overview

```
specwright/
├── skills/       # 15 SKILL.md files (10 user-facing + 5 internal gates)
├── protocols/    # 12 shared protocols (loaded on demand by skills)
├── agents/       # 6 custom subagent definitions
├── hooks/        # Session lifecycle hooks
├── CLAUDE.md     # Project instructions for Claude Code
├── DESIGN.md     # Full architecture document
└── README.md
```

**Skills** define *what* to achieve (goals + constraints), not step-by-step procedures. Each stays under 600 tokens.

**Protocols** extract fragile operations (git, state, recovery) into shared documents loaded on demand. Skills reference them but don't inline their content.

**Agents** are custom subagent definitions with specific roles (architect, tester, executor, reviewer, build-fixer, researcher).

For the full architecture, see [`DESIGN.md`](DESIGN.md). For development guidelines and key rules, see [`CLAUDE.md`](CLAUDE.md).

## Development Setup

Specwright is a Claude Code plugin — it's a collection of skill, protocol, and agent definitions (Markdown files), not a compiled application. To develop:

1. Clone the repo
2. Install the plugin locally: `/plugin install /path/to/specwright`
3. Test skills by running them in a real or test project
4. Check that modified skills stay under the 600-token target

## Code of Conduct

Be respectful and constructive. We're all here to build better tools.
