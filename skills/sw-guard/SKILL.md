---
name: sw-guard
description: >-
  Detects project stack and existing guardrails, then interactively helps implement
  automated quality checks across session, commit, push, and CI/CD layers.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
  - Task
---

# Specwright Guard

## Goal

Review the project's codebase and development tools, then interactively help the
user implement automated guardrails tailored to their stack and preferences. Each
layer (session, commit, push, CI/CD) is independently approvable. Existing guardrails
are detected and preserved during re-runs.

## Inputs

- The codebase (dependency manifests, config files, test runners, existing hooks)
- `.specwright/config.json` -- project configuration
- `.specwright/CONSTITUTION.md` -- practices to follow
- Existing Claude Code settings.json, git hooks, CI workflows
- The user's guardrail preferences

## Outputs

When complete, user-approved guardrails are configured. Artifacts may include:

- `.claude/settings.json` -- Claude Code session-level permissions and hooks
- Pre-commit hook configurations (via husky, pre-commit, or lefthook)
- Pre-push hook configurations (test runner, coverage thresholds)
- `.github/workflows/*.yml` -- CI/CD quality checks
- `.specwright/config.json` -- updated with tool commands (linter, formatter, test runner)

Note: CONSTITUTION.md is NOT modified. Constitutional updates are the responsibility of sw-learn.

## Constraints

**Detection (MEDIUM freedom):**
- Scan codebase: language(s), framework(s), package manager, test runner, linter, formatter, type checker.
- Read dependency manifests, git hooks, Claude Code settings, CI/CD workflows. Don't guess — read files.
- Detect existing guardrails before recommending. Support idempotent re-runs by showing delta.

**User alignment (HIGH freedom):**
- Use Guardrail Spectrum (Guardian/Balanced/Agile) for default orientation, then gather per-domain preferences.
- Show detected stack and existing guardrails before recommending. Use AskUserQuestion with concrete options.

**Recommendation (HIGH freedom):**
- Organize by layer: session (Claude Code hooks), commit (pre-commit), push (pre-push), CI/CD (GitHub Actions). Each independently approvable.
- Session layer: recommend PostToolUse hooks using detected tools. Generate inline shell commands from config.json — never hardcode tool names. User chooses destination: `.claude/settings.local.json` (gitignored) or `.claude/settings.json` (shareable). Read existing hooks first, show diff, merge (don't overwrite), detect duplicates.
- Explain why each tool fits. Delegate to `specwright-researcher` for unfamiliar stacks. If tools conflict, present trade-offs.

**Configuration (LOW freedom):**
- External file writes: diff-show-approve. Installation commands require explicit approval.
- Update config.json with detected tool commands. Follow `protocols/context.md` for config updates.
- Never modify CONSTITUTION.md (sw-learn's responsibility).

## Protocol References

- `protocols/context.md` -- config.json format and loading
- `protocols/state.md` -- workflow state mutations if tracking guard setup progress
- `protocols/delegation.md` -- agent delegation for researcher

## Failure Modes

| Condition | Action |
|-----------|--------|
| .specwright/ not initialized | "Run /sw-init first" |
| No dependency manifest | Ask user about language/framework directly |
| Install command fails | Show error, let user retry or skip |
| Detected tools conflict | Present trade-offs, let user choose |
| Unsupported CI platform | Warn, skip CI/CD layer |
| Compaction during config | Read config.json and external files, resume next missing item |
