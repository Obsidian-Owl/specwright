# Guardrails Patterns Protocol

Coverage model and enforcement patterns for sw-guard.

## Coverage Model

Nine dimensions of quality enforcement. Detected tool for a dimension → covered.
No tool → gap. Gaps become recommendations.

| Dimension | What it covers |
|-----------|---------------|
| Formatting | Code style consistency (indentation, line length, spacing) |
| Linting | Code smells, anti-patterns, best-practice violations |
| Type checking | Static type correctness for typed languages |
| Testing | Functional correctness via automated test suites |
| Test coverage | Coverage thresholds on new or changed code |
| Security scanning | Dependency vulnerabilities, SAST, known CVEs |
| Secret detection | Leaked credentials, API keys, tokens in source |
| Commit enforcement | Hook-level quality gate before commits are created |
| CI gate | Branch-level enforcement in clean reproducible environment |

## Four-Layer Enforcement

### Layer 1: Agent Session Hooks

Enforcement at generation time — before or immediately after tool calls.

**PreToolUse (blocking):**
- Bash: block dangerous git ops (`git add -A`, `--force`, `reset --hard`, `clean -f`)
- Bash: block commits when tests fail (run detected test command first)
- Edit: protect critical files (`.env*`, lock files, CI configs)

**PostToolUse (feedback, non-blocking):**
- Edit|Write: run detected formatter (auto-fix)
- Edit|Write: run detected linter (feedback to agent)

Performance: keep PostToolUse hooks under 300ms per invocation. Slow tools
degrade the session and lead to hook disablement.

**Platform-specific generation:**

Claude Code: generate JSON hook entries for `.claude/settings.json` or
`.claude/settings.local.json`. Use command-type hooks for external tooling.
Use prompt-type hooks for semantic checks (prompt hooks avoid exit-code-2 bugs
per pattern P9). User chooses destination (shareable vs gitignored).

Opencode: generate TypeScript plugin stubs for `.opencode/plugins/` using
`tool.execute.before` (blocking) and `tool.execute.after` (feedback).

### Layer 2: Pre-Commit Hooks

Run on staged files at `git commit` time. Deterministic — cannot be
"reasoned around" by the agent.

- Lint staged files (detected linter, check mode)
- Format check (detected formatter, check mode)
- Type check (if typed language detected)
- Secret scan (gitleaks or detect-secrets)
- Conventional commits validation (commit-msg hook, if applicable)

### Layer 3: Pre-Push Hooks

Run before `git push`. For checks too slow per-commit but too important
to defer to CI.

- Full test suite pass (detected test runner)
- Coverage threshold (detected coverage tool, if configured)

### Layer 4: CI Workflows

Clean-room enforcement. Catches `--no-verify` bypasses.

- Backstop: re-run all pre-commit checks
- Full integration tests
- Security scanning (dependency audit, history-level secret scan)
- Coverage reporting and threshold enforcement

## Pre-Commit Framework Options

Present all applicable frameworks with trade-offs. User always chooses.

| Framework | Runtime req | Best for | Key trait |
|-----------|------------|----------|-----------|
| Lefthook | None (Go binary) | Multi-language, no-dependency teams | Parallel execution, glob filtering |
| Husky | Node.js | JS/TS-only projects | Native npm integration, lint-staged pairing |
| pre-commit | Python | Polyglot repos, large hook ecosystems | Isolated per-hook environments, largest community registry |
