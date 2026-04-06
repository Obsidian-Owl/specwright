---
name: gate-semantic
description: >-
  Tiered semantic analysis of changed code (rg → ast-grep → OpenGrep).
  Detects error-path bugs structural gates miss. Findings default to
  WARN. Internal — invoked by verify.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
---

# Gate: Semantic Analysis

## Goal

Detect semantic bugs in changed code using symbolic pre-processing when
available. For each candidate finding, apply the localization template
from `protocols/semi-formal-reasoning.md`.

## Inputs

- `config.json` `gates.semantic` — categories, tools, optional `rulesDir`
- `workflow.json` — current work unit
- Changed files via `git diff --name-only $(git merge-base HEAD <baseBranch>)`

## Outputs

- `{currentWork.workDir}/evidence/semantic-report.md`
- Gate status in workflow.json

## Constraints

**Scope (MEDIUM freedom):**
Changed code files only. Skip markdown/JSON/YAML/config. No changed code → PASS.

**Tool tiers (LOW freedom):**
Resolve from `gates.semantic.tools` config, fall back to PATH detection.
Missing tools narrow scope — never FAIL or ERROR. Validate `sg` identity:
`sg --version 2>&1 | grep -iq 'ast-grep'` (`/usr/bin/sg` from shadow-utils
is a false positive).

| Tier | Tool | Adds |
|------|------|------|
| 0 | rg | Text-pattern extraction + LLM |
| 1 | ast-grep (`sg`) | Structural JSON, metavariable capture |
| 2 | OpenGrep | Cross-function taint (rules: config `rulesDir` or `.opengrep/rules/`) |

**Extraction (HIGH freedom):**
Extract structural facts using highest available tier's tool. Feed facts
(not raw files) to LLM. Tier 1: `sg scan <file> --json --rule <rule>` or
`sg run --pattern '...' <file> --json` (avoid `--stdin`). Tier 2:
`opengrep scan --config <rules-dir> --json <file>`.

**Categories (LOW freedom):**

| Category | Tier | Diagnostic question |
|----------|------|-------------------|
| error-path-cleanup | 0+ | Does any error path skip releasing an acquired resource? |
| unchecked-errors | 0+ | Is any error-producing call's return value discarded? |
| fail-open-handling (CWE-636) | 1+ | Does any catch block swallow, broaden, or ignore errors? |
| error-data-leakage (CWE-209) | 1+ | Does any error response expose internals to the caller? |
| resource-lifecycle | 2+ | Is any acquired resource not released on all exit paths? |

Categories requiring an unavailable tier are skipped with an INFO note.
Sole owner of CWE-636 and CWE-209 analysis (transferred from gate-security to avoid duplicate findings).

**Verdict (LOW freedom):**
Per `protocols/gate-verdict.md`. All findings WARN by default.
No findings = PASS. WARN-only = WARN. Any BLOCK = FAIL.

Tier 0 categories: **permanently WARN-only**. Tier 1+ may promote to BLOCK
when: (1) ≥5 shipped units, (2) FP rate <10% per `gate-verdict.md`
calibration, (3) user opt-in via config `{"severity": "block"}`.

**Evidence report:** Tool availability, skipped categories with reason,
each finding with category, file:line, tier/tool, severity, remediation.

## Protocol References

- `protocols/semi-formal-reasoning.md` -- localization template for findings
- `protocols/gate-verdict.md` -- verdict rendering and calibration
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates
- `protocols/context.md` -- config and anchor doc loading

## Failure Modes

| Condition | Action |
|-----------|--------|
| Disabled in config | sw-verify skips silently |
| No changed code files | PASS |
| No symbolic tools | Degrade to Tier 0 |
| Tool missing at runtime | WARN, skip tier |
| No calibration data | All findings WARN |
