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

- `{projectArtifactsRoot}/config.json` -- `commands.lint`, SAST tool config if available
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- selected work unit
- Changed files (detected via `git diff`)

## Outputs

- Evidence file at `{workDir}/evidence/security-report.md`
- Gate status in the selected work's `workflow.json`
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
- Check that external data is treated as untrusted (per Constitution security practices).
- Check that authentication/authorization patterns aren't weakened (per Constitution auth/authz practices).
- Findings are WARN unless clearly exploitable (then BLOCK).

**Phase 3 — Logical security (HIGH freedom, WARN severity):**
- Missing authentication (CWE-306): mutation-capable handler functions (HTTP routes, gRPC handlers, GraphQL resolvers) performing state-changing operations without any visible auth check. Only flag when auth is completely absent. Skip if no mutation-capable handler patterns detected in changed files.
- For code-level error handling analysis (CWE-636, CWE-209), defer to gate-semantic which owns those categories with tiered tooling.
- All Phase 3 findings are WARN. Never BLOCK.
- Phase 3 focuses on logical control-flow; defer to Phase 2 when a finding is already captured as an injection pattern.

**Verdict (LOW freedom):**
- Follow `protocols/evidence.md#verdict-rendering`.
- Any BLOCK finding = gate FAIL.
- WARN-only findings = gate WARN (passes but flagged).
- Cite relevant Constitution practices where applicable.

## Protocol References

- `protocols/evidence.md#verdict-rendering` -- verdict rendering
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates

## Failure Modes

| Condition | Action |
|-----------|--------|
| No SAST tool configured | Skip tool-based detection, rely on LLM analysis |
| No changed files detected | Scan all project source files |
| SAST tool not installed | WARN finding, suggest installation, continue with LLM |
