---
name: sw-doctor
description: >-
  Read-only Specwright health check. Validates that configuration, anchor docs,
  commands, gates, and hooks are correctly set up. Produces a PASS/WARN/FAIL table.
argument-hint: ""
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
---

# Specwright Doctor

## Goal

Validate that a Specwright installation is correctly configured. Produces a
health table with ✓/⚠/✗ per check and repair hints for any issues found.
Makes NO state mutations.

## Inputs

- `.specwright/config.json` -- gates, git, commands, backlog config
- `.specwright/CONSTITUTION.md` and `.specwright/CHARTER.md`
- `.specwright/state/workflow.json`
- Plugin root `skills/gate-*/SKILL.md` files
- Plugin root `hooks/hooks.json` and referenced `.mjs` files
- `which {cmd}` for each configured command

## Outputs

- Health table printed to conversation (no file written)
- No state mutations

## Constraints

**Pre-condition (LOW freedom):**
- If `.specwright/` directory does not exist: STOP immediately.
  "Specwright not initialized. Run /sw-init first."

**Checks (LOW freedom — run all 12 in order):**
1. **Anchor docs** — `.specwright/CONSTITUTION.md` and `.specwright/CHARTER.md` exist and are non-empty
2. **Config** — `.specwright/config.json` is valid JSON with `gates` and `git` fields present
3. **State** — `.specwright/state/workflow.json` is valid JSON; `lock` is null or held < 1 hour
4. **Gates** — for each key `{gate}` in `config.gates` where `config.gates[{gate}].enabled` is `true`, verify `skills/gate-{gate}/SKILL.md` exists
5. **Build command** — if `config.commands.build` is set, `which {cmd}` exits 0; WARN if not found
6. **Test command** — if `config.commands.test` is set, `which {cmd}` exits 0; WARN if not found
7. **Format/lint** — if `config.commands.format` or `config.commands.lint` is set, `which {cmd}` for each; WARN if not found
8. **Hooks** — if `hooks/hooks.json` exists: must be parseable JSON; each `.mjs` file it references must exist; WARN if missing
9. **Backlog config** — if `config.backlog.type` is set:
   - `markdown`: `.specwright/` directory is accessible (PASS)
   - `github-issues`: run `gh auth status`; WARN if exits non-zero
10. **ast-grep** — `sg --version 2>&1 | grep -iq ast-grep` succeeds: INFO `ℹ ast-grep available (enables semantic analysis)`; not found or wrong binary: INFO `ℹ ast-grep not installed (optional — enables semantic analysis)`
11. **OpenGrep** — `which opengrep` exits 0: INFO `ℹ OpenGrep available (enables taint analysis)`; not found: INFO `ℹ OpenGrep not installed (optional — enables taint analysis)`
12. **LSP** — detect platform LSP (Claude Code: behavioral detection via agent capabilities; Opencode: `.opencode/` config with `lsp` section):
    - Platform LSP detected: PASS
    - Only `cli-lsp-client` on PATH: INFO `ℹ Standalone LSP daemon available`
    - `cli-lsp-client` + platform LSP both detected: WARN `⚠ cli-lsp-client may conflict with platform LSP — duplicate servers cause resource doubling`
    - Neither: INFO `ℹ No LSP available (optional — enables type-aware analysis)`

**Output format (MEDIUM freedom):**
```
Specwright Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Anchor docs       PASS
✓ Config            PASS
✓ State             PASS
✓ Gates             PASS
⚠ Build command     WARN — 'pnpm build' not found on PATH
✓ Test command      PASS
✓ Format/lint       PASS
✗ Hooks             FAIL — hooks/session-start.mjs missing
✓ Backlog config    PASS
ℹ ast-grep          INFO — not installed (optional)
ℹ OpenGrep          INFO — not installed (optional)
ℹ LSP               INFO — no LSP available (optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
7 passed · 1 warning · 1 failure · 3 info
→ Run /sw-guard to reconfigure hooks.
```
- PASS: ✓ prefix, no detail needed
- INFO: ℹ prefix + brief status description (used for optional tool availability checks)
- WARN: ⚠ prefix + specific issue description (which file, which command)
- FAIL: ✗ prefix + specific issue + one repair hint pointing to a command
- Repair hints: use `→ Run /sw-guard` for hooks/guardrail issues; `→ Run /sw-init` for config/anchor issues; `→ Run gh auth login` for GitHub auth issues
- If all checks pass: add "All checks passed." after the summary line

**No mutations (LOW freedom):**
- Read only. Do not write or edit any file. Do not update workflow.json. Do not
  acquire or release the state lock.

## Protocol References

- `protocols/context.md` -- config loading
- `protocols/state.md` -- workflow.json format reference

## Failure Modes

| Condition | Action |
|-----------|--------|
| `.specwright/` missing | STOP: "Specwright not initialized. Run /sw-init first." |
| `config.json` missing but `.specwright/` exists | FAIL that check, continue remaining checks |
| All checks PASS | Print table, add "All checks passed." |
| `hooks/hooks.json` absent | SKIP hooks check with INFO note: "No hooks configured." |
