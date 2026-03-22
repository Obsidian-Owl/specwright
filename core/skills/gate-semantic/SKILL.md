---
name: gate-semantic
description: >-
  LLM-assisted semantic analysis of changed code with optional symbolic
  pre-processing. Detects error-path resource leaks and unchecked error
  returns. Experimental — all findings are WARN. Internal gate — invoked
  by verify when enabled.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
---

# Gate: Semantic Analysis

## Goal

Detect semantic bugs in changed code that structural gates miss. Use symbolic
pre-processing (when available) to focus LLM reasoning on precise fragments.

## Inputs

- `.specwright/config.json` -- `gates.semantic` with schema: `{enabled: bool, categories: ["error-path-cleanup", "unchecked-errors"]}`
- `.specwright/state/workflow.json` -- current work unit
- Changed files (detected via `git diff`)

## Outputs

- Evidence file at `{currentWork.workDir}/evidence/semantic-report.md`
- Gate status in workflow.json
- Findings shown inline with severity, location, and remediation

## Constraints

**Scope (MEDIUM freedom):**
- Focus on changed files. Use `git diff --name-only $(git merge-base HEAD main)` to list files changed on this branch.
- Skip non-code files (markdown, JSON, YAML, config). Return PASS with no findings.
- If no changed files detected, return PASS.

**Tool detection (LOW freedom):**
- Detect available symbolic tools on PATH: `rg` (ripgrep), `ast-grep` (`sg`), `semgrep`.
- Tools are optional — graceful degradation is required (Charter invariant 5).
- Use the best available tool for extraction. Graceful degradation:
  - `ast-grep` or `semgrep` available: use for syntax-aware pattern extraction (JSON output)
  - `rg` available (default): use for text-based extraction of error handlers, callers, resource patterns
  - Nothing available: fall back to direct LLM review of changed file content

**Extraction (HIGH freedom):**
- Extract structural facts from changed files relevant to the two categories.
- Feed extracted facts (not raw files) to LLM with targeted semantic questions.

**Categories (LOW freedom):**
Two categories only. No overlap with gate-security Phase 3.

1. **Error-path resource cleanup:** Does any error/exception path in a changed
   function skip releasing/closing an acquired resource (file handle, database
   connection, lock, network socket)?
2. **Unchecked error-producing calls:** Does any call to a function that returns
   an error or throws get its return value discarded or ignored without explicit
   justification (e.g., cleanup functions where errors are intentionally ignored)?

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- All findings are WARN. Never BLOCK. This gate is experimental.
- WARN-only findings = gate WARN. No findings = gate PASS.

## Protocol References

- `protocols/gate-verdict.md` -- verdict rendering
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates
- `protocols/context.md` -- config and anchor doc loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| Gate disabled in config | sw-verify skips silently — no evidence, no error |
| No changed files | Return PASS with no findings |
| No symbolic tools available | Degrade to pure LLM review. Not an error — clean code still returns PASS. |
| Changed files are not code | Return PASS with no findings |
| ast-grep/semgrep not found | Degrade to rg-based extraction. Not an error. |
