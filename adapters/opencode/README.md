# Specwright for Opencode

Specwright adapter for [Opencode](https://opencode.ai). Brings spec-driven development with quality gates to the Opencode environment.

## Installation

Add to your `opencode.json`:

```json
{
  "plugin": ["opencode-specwright@latest"]
}
```

Opencode installs the package automatically on next startup.

## Usage

Once installed, the Specwright workflow commands are available:

- `sw-init` — Project setup: constitution, charter, gates
- `sw-design` — Interactive solution architecture
- `sw-plan` — Decompose design into testable work units
- `sw-build` — TDD implementation of one work unit
- `sw-verify` — Quality gates validation
- `sw-ship` — Strategy-aware merge via PR

Run `sw-init` first to configure Specwright for your project, then follow the design → plan → build → verify → ship workflow.

## More Information

See the [Specwright repository](https://github.com/Obsidian-Owl/specwright) for full documentation.
