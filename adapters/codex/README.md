# Specwright for Codex CLI

This directory is the Codex adapter source.

End users should install the packaged Codex bundle from GitHub Releases, not
point Codex directly at `adapters/codex`. The distributable bundle is built to
`dist/codex` and includes:
- transformed `skills/`
- packaged `protocols/` and `agents/`
- `commands/`, `hooks/`, `hooks.json`
- `.codex-plugin/plugin.json`

## User Install

```sh
curl -fsSL https://raw.githubusercontent.com/Obsidian-Owl/specwright/main/scripts/install-codex.sh | bash -s -- --user
```

Requires `curl`, `tar`, and `python3`.

## Repo Install

Run from the target repository root:

```sh
curl -fsSL https://raw.githubusercontent.com/Obsidian-Owl/specwright/main/scripts/install-codex.sh | bash -s -- --repo
```

Then open Codex and enable `specwright` from:

```text
/plugins
```

## Local Development

If you are working on Specwright itself:
1. Build the distributable with `./build/build.sh codex`.
2. Install the resulting `dist/codex` bundle into a user or repo marketplace.
3. Use `.agents/skills` directly if you only need skills-only mode.
