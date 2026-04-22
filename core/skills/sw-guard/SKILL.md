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
- `{projectArtifactsRoot}/config.json` -- project configuration (optional -- not required)
- `{projectArtifactsRoot}/CONSTITUTION.md` -- practices to follow (if present)
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
- `{projectArtifactsRoot}/config.json` -- updated with detected tool commands (if present)

Note: CONSTITUTION.md is NOT modified. Constitutional updates are the responsibility of sw-learn.

## Constraints

**Detection (MEDIUM freedom):**
- Follow `protocols/guardrails-detection.md` for the three-step detection algorithm
  (manifest scan, config file scan, existing guardrail scan).
- Detection scope includes traditional tools (linters, formatters, test runners) and
  semantic analysis tools: ast-grep (`sg`), OpenGrep (`opengrep`), and platform LSP
  (Claude Code `.lsp.json`, Opencode built-in, `cli-lsp-client` standalone).
- If `{projectArtifactsRoot}/config.json` exists, read `commands.*` fields as authoritative;
  supplement with detection for unconfigured dimensions.
- If `{projectArtifactsRoot}/config.json` does not exist, rely entirely on detection.
  Validate detected tools by running them (e.g., `--version` check). Present
  standalone recommendations with explicit "detected via heuristics" labeling.
- When Git workflow config is present or inferred, seed or migrate `git.targets` and `git.freshness` from the detected Git workflow strategy without requiring users to define a custom branch DSL.
- Detect or confirm target-role defaults, freshness checkpoints, runtime mode as an explicit Git policy choice, and any optional work-artifact publication mode as one explicit Git policy surface.
- Recommend `project-visible` for Claude-oriented installs unless the user explicitly wants `git-admin` runtime roots.
- When describing runtime policy, use the same operator vocabulary as the
  adapters and status surfaces: `project-visible` roots under `.specwright-local/`
  for interactive installs, `git-admin` roots under `.git/specwright/` for
  compatibility, `/sw-status` for the current runtime view, and `/sw-adopt` for
  explicit same-work adoption.
- Recommend a tracked work-artifact root under `.specwright/works` for new interactive installs unless the user explicitly prefers clone-local-only auditable work artifacts.
- Keep runtime mode separately from tracked work-artifact publication and separately from clone-local runtime state.
- Treat `.specwright/config.json` and the anchor docs as a shared project-level
  policy surface across developers and agent sessions, not as clone-local
  runtime state.
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
- Update `{projectArtifactsRoot}/config.json` with detected tool commands when the tracked
  project-artifact root exists.
- When present, update `git.runtime.mode` / `git.runtime.projectVisibleRoot` in config separately from tracked work-artifact publication.
- When present, update the approved work-artifact publication choice in config separately from clone-local runtime state and separately from tracked work-artifact publication.
  Follow `protocols/context.md` for config updates.
- Preserve the root split: tracked project policy stays under `{projectArtifactsRoot}`,
  while Git-admin session state remains local-only under the runtime roots.
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
