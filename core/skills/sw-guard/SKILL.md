---
name: sw-guard
description: >-
  Detects project stack and existing guardrails, then interactively configures
  deterministic quality checks across session, commit, push, and CI/CD layers.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - WebSearch
  - AskUserQuestion
  - Task
---

# Specwright Guard

## Goal

Detect the project's stack and interactively configure deterministic guardrails
across four enforcement layers (session, commit, push, CI/CD). Each layer is
independently approvable. Existing guardrails are preserved during re-runs.

## Inputs

- The codebase (dependency manifests, config files, existing hooks)
- `.specwright/config.json` -- project configuration (optional -- not required)
- `.specwright/CONSTITUTION.md` -- practices to follow (if present)
- Existing agent hooks, git hooks, CI workflows

## Outputs

When complete, user-approved guardrails are configured. Artifacts may include:

<!-- platform:claude-code -->
- `.claude/settings.json` or `.claude/settings.local.json` -- session-level hooks.
  User chooses destination (shareable vs gitignored).
<!-- /platform -->

<!-- platform:opencode -->
- `.opencode/plugins/*.ts` -- session-level plugin hooks.
<!-- /platform -->

- Pre-commit hook configurations (framework chosen by user)
- Pre-push hook configurations (test runner, coverage thresholds)
- CI/CD workflow files (backstop checks, integration tests, security scanning)
- `.specwright/config.json` -- updated with detected tool commands (if present)

Note: CONSTITUTION.md is NOT modified. Constitutional updates are the responsibility of sw-learn.

## Constraints

**Detection (MEDIUM freedom):**
- Follow `protocols/guardrails-detection.md` for the three-step detection algorithm
  (manifest scan, config file scan, existing guardrail scan).
- Detection scope includes traditional tools (linters, formatters, test runners) and
  semantic analysis tools: ast-grep (`sg`), OpenGrep (`opengrep`), and platform LSP
  (Claude Code `.lsp.json`, Opencode built-in, `cli-lsp-client` standalone).
- If `.specwright/config.json` exists, read `commands.*` fields as authoritative;
  supplement with detection for unconfigured dimensions.
- If `.specwright/config.json` does not exist, rely entirely on detection.
  Validate detected tools by running them (e.g., `--version` check). Present
  standalone recommendations with explicit "detected via heuristics" labeling.
- When Git workflow config is present or inferred, seed or migrate `git.targets` and `git.freshness` from the detected Git workflow strategy without requiring users to define a custom branch DSL.
- For unfamiliar stacks or niche tools, use WebSearch to identify tooling conventions.
- Detect existing guardrails before recommending. Show delta on re-runs.

**Gap analysis (MEDIUM freedom):**
- Load the coverage model from `protocols/guardrails-patterns.md`.
- Map detected tools against the ten enforcement dimensions. Detected tool for
  a dimension → covered. No tool → gap. Gaps become recommendations.
- Present the gap analysis summary to the user before recommending.

**Recommendation (HIGH freedom):**
- Organize recommendations by enforcement layer. Load hook patterns from
  `protocols/guardrails-patterns.md`.
- Each layer is independently approvable. User chooses which layers to configure.
- For commit hooks: present applicable frameworks with trade-offs.
  User always chooses — never auto-select.
- Read existing hooks first, show diff, merge (don't overwrite), detect duplicates.
- Delegate to `specwright-researcher` for unfamiliar stacks. If tools conflict,
  present trade-offs.

**Configuration (LOW freedom):**
- External file writes: diff-show-approve. Installation commands require explicit approval.
- Update config.json with detected tool commands if `.specwright/` exists.
  Follow `protocols/context.md` for config updates.
- Never modify CONSTITUTION.md (sw-learn's responsibility).

**Headless (LOW freedom):**
- Follow `protocols/headless.md` for non-interactive detection and default policies.
- When headless: apply all layers using detected tools with conservative defaults.
- Write headless result file on ALL exit paths including abort.

## Protocol References

- `protocols/guardrails-detection.md` -- three-step stack and guardrail detection
- `protocols/guardrails-patterns.md` -- coverage model, enforcement patterns, framework options
- `protocols/context.md` -- config.json format and loading
- `protocols/headless.md` -- non-interactive execution detection and defaults
- `protocols/delegation.md` -- agent delegation for researcher

## Failure Modes

| Condition | Action |
|-----------|--------|
| No dependency manifest found | Ask user about language/framework directly |
| Detected tool fails `--version` check | Warn user, skip that tool, ask for correct command |
| Install command fails | Show error, let user retry or skip |
| Detected tools conflict | Present trade-offs, let user choose |
| Unsupported CI platform | Warn, skip CI/CD layer |
| Compaction during config | Read config.json and external files, resume next missing item |
