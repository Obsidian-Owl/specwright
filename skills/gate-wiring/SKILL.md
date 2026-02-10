---
name: gate-wiring
description: >-
  Detects unused exports, orphaned files, architecture layer violations,
  and circular dependencies across changed files. Delegates to architect
  agent for structural analysis. Internal gate — invoked by verify.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
  - Task
---

# Gate: Wiring

## Goal

Ensure the codebase is properly connected — no dead code, no orphaned
files, no architecture violations. Code that compiles and passes tests
can still be wired incorrectly.

## Inputs

- `.specwright/config.json` -- architecture layers, project structure
- `.specwright/state/workflow.json` -- current work unit
- Changed files (via `git diff`)

## Outputs

- Evidence file at `.specwright/work/{id}/evidence/wiring-report.md`
- Gate status in workflow.json
- Findings with specific file:line references and remediation

## Constraints

**Scope (MEDIUM freedom):**
- Focus on changed files and their immediate dependents.
- Use `git diff --name-only` against main branch.

**Analysis (HIGH freedom):**
- Delegate to `specwright-architect` for structural analysis.
- The architect checks:
  - **Unused exports**: Public functions/types exported but never imported.
  - **Orphaned files**: Files not imported by anything in the dependency graph.
  - **Layer violations**: Imports crossing architecture layer boundaries (e.g., UI importing directly from database layer). Layers from `config.json` `architecture.layers`.
  - **Circular dependencies**: Import cycles that may cause runtime issues.
- Use real tooling when available (e.g., `madge`, `knip`, `ts-prune`).
- Fall back to LLM analysis when tools aren't configured.

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- WARN severity for most findings (wiring issues rarely block functionality).
- BLOCK only for circular dependencies in changed files.
- This gate is advisory — it helps clean up, not block shipping.

## Protocol References

- `protocols/gate-verdict.md` -- verdict rendering
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates
- `protocols/delegation.md` -- architect agent delegation

## Failure Modes

| Condition | Action |
|-----------|--------|
| No changed files detected | Analyze all project source files |
| No architecture layers configured | Skip layer violation check |
| Wiring tool not installed | Fall back to LLM-based analysis |
| Too many files to analyze | Focus on changed files only, note incomplete scope |
