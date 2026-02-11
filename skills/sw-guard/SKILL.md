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
- Scan the codebase to detect: language(s), framework(s), package manager, test runner, linter, formatter, type checker.
- Read actual dependency manifests (package.json, go.mod, requirements.txt, Cargo.toml, etc.).
- Check for existing git hooks (.git/hooks/, .husky/, .pre-commit-config.yaml, lefthook.yml).
- Check for existing Claude Code hooks and settings (.claude/settings.json, .claude/settings.local.json).
- Check for existing CI/CD workflows (.github/workflows/).
- Don't guess what you can detect. Ground detection in reading actual files.
- Detect existing guardrails before recommending new ones. Support idempotent re-runs by showing delta.

**User alignment (HIGH freedom):**
- Use the Guardrail Spectrum (Guardian/Balanced/Agile) as initial orientation for default recommendations.
- After spectrum selection, gather per-domain preferences: security, consistency, test coverage, AI behavior.
- Each domain allows fine-tuning beyond the initial spectrum orientation.
- Show the user what was detected (stack, existing guardrails) before making recommendations.
- Use AskUserQuestion with concrete options based on detected stack.

**Recommendation (HIGH freedom):**
- Organize recommendations by check level: session (Claude Code settings/hooks), commit (pre-commit hooks), push (pre-push hooks), CI/CD (GitHub Actions).
- Each check level is independently approvable. User can accept some layers and reject others.
- For each recommended tool, explain WHY it fits their stack and preferences.
- Delegate to specwright-researcher for stack-specific tool documentation when the detected stack is unfamiliar.
- If tools conflict with each other (e.g., ruff vs black+flake8), explain trade-offs and let user decide.

**Configuration (LOW freedom):**
- External file writes (anything outside .specwright/) use diff-show-approve: show what will change, get approval, then write.
- Installation commands are shown to the user before execution and require explicit approval.
- Update .specwright/config.json with detected and configured tool commands (linter, formatter, test runner, type checker) so other Specwright skills can use them.
- Follow protocols/context.md for config.json updates.
- Never modify CONSTITUTION.md. That is sw-learn's responsibility.

## Protocol References

- `protocols/context.md` -- config.json format and loading
- `protocols/state.md` -- workflow state mutations if tracking guard setup progress
- `protocols/delegation.md` -- agent delegation for researcher

## Failure Modes

| Condition | Action |
|-----------|--------|
| .specwright/ not initialized | Instruct user to run sw-init first |
| No dependency manifest found | Ask user about language/framework directly |
| Install command fails | Show error, let user retry with custom command or skip |
| Detected tools conflict | Present trade-offs, let user choose which to keep |
| CI platform is not GitHub Actions | Warn that CI/CD layer is unsupported, skip that layer |
| Compaction during configuration | Read config.json and external files to determine what was already written, resume next missing configuration |
