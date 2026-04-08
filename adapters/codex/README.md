# Specwright for Codex CLI

Specwright adapter for Codex CLI.

This adapter provides:
- Slash commands for all user-facing `sw-*` skills
- Session lifecycle hooks (resume context, shipping guard, continuation snapshot)
- A plugin manifest for Codex plugin installation

## Repo-Local Setup (Specwright Dogfooding)

1. Ensure Codex can discover repository skills via `.agents/skills`.
2. Ensure plugin marketplace entry exists at `.agents/plugins/marketplace.json`.
3. In Codex, install/enable the `specwright` plugin from the repo marketplace.

## Skills-Only Mode

If you do not want to install the plugin, Codex can still run Specwright skills
directly from `.agents/skills`.

