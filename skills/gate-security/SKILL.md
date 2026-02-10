---
name: gate-security
description: >-
  Detects leaked secrets, injection patterns, and sensitive data exposure
  across changed files. Uses real tooling when configured, LLM judgment
  for analysis. Internal gate — invoked by verify.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
---

# Gate: Security

## Goal

Ensure the codebase doesn't leak secrets, introduce injection vulnerabilities,
or expose sensitive data. Use real security tooling when available. Use LLM
judgment for analysis that tools can't do.

## Inputs

- `.specwright/config.json` -- `commands.lint`, SAST tool config if available
- `.specwright/state/workflow.json` -- current work unit
- Changed files (detected via `git diff`)

## Outputs

- Evidence file at `.specwright/work/{id}/evidence/security-report.md`
- Gate status in workflow.json
- Findings shown inline with severity, location, and remediation

## Constraints

**Scope (MEDIUM freedom):**
- Focus on changed files. Use `git diff --name-only` against main branch.
- If no changed files detected, check all files in work scope.

**Phase 1 — Detection (LOW freedom, BLOCK severity):**
- Scan for secrets: API keys, tokens, passwords, private keys in source files.
- Scan for .env files, credential files, or key files staged for commit.
- Check .gitignore covers sensitive patterns.
- If a configured SAST tool exists (e.g., `semgrep`, `eslint-plugin-security`), run it.
- Any secret or credential found = BLOCK finding.

**Phase 2 — Analysis (HIGH freedom, WARN severity):**
- Review changed code for injection patterns (SQL, command, XSS, path traversal).
- Check that external data is treated as untrusted (per Constitution X3).
- Check that authentication/authorization patterns aren't weakened (per X2).
- Findings are WARN unless clearly exploitable (then BLOCK).

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- Any BLOCK finding = gate FAIL.
- WARN-only findings = gate WARN (passes but flagged).
- Cite Constitution X1-X4 where relevant.

## Protocol References

- `protocols/gate-verdict.md` -- verdict rendering
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates

## Failure Modes

| Condition | Action |
|-----------|--------|
| No SAST tool configured | Skip tool-based detection, rely on LLM analysis |
| No changed files detected | Scan all project source files |
| SAST tool not installed | WARN finding, suggest installation, continue with LLM |
