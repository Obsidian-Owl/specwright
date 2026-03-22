---
name: gate-semantic
description: >-
  Tiered semantic analysis of changed code using progressive tool
  enhancement (rg → ast-grep → OpenGrep → Platform LSP). Detects
  error-path resource leaks, unchecked errors, fail-open handling,
  error data leakage, and resource lifecycle issues. Findings start
  as WARN; BLOCK promotion requires calibration. Internal gate —
  invoked by verify when enabled.
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

- `.specwright/config.json` -- `gates.semantic` with schema:
  ```json
  {
    "enabled": true,
    "categories": ["error-path-cleanup", "unchecked-errors", "fail-open-handling",
                    "error-data-leakage", "resource-lifecycle"],
    "tools": {
      "ast-grep": { "command": "sg", "detected": true },
      "opengrep": { "command": "opengrep", "detected": false },
      "lsp": { "source": "none", "detected": false }
    }
  }
  ```
  The `categories` field accepts both string values (default WARN severity) and
  object values (`{"name": "...", "severity": "block"}`) for BLOCK promotion
  opt-in (subject to calibration — see Verdict section).
  The `lsp.source` field accepts one of: `"platform"`, `"cli-lsp-client"`, or `"none"`.
  The `opengrep` tool entry may include an optional `rulesDir` field specifying the
  path to OpenGrep/Semgrep-compatible taint rule files. If absent, the gate looks for
  rules at `.opengrep/rules/` in the project root; if that does not exist, the
  resource-lifecycle category is skipped with an INFO note.
- `.specwright/state/workflow.json` -- current work unit
- Changed files (detected via `git diff`)

## Outputs

- Evidence file at `{currentWork.workDir}/evidence/semantic-report.md`
- Gate status in workflow.json
- Findings shown inline with severity, location, and remediation

## Constraints

**Scope (MEDIUM freedom):**
- Focus on changed files. Use `git diff --name-only $(git merge-base HEAD <baseBranch>)` to list files changed on this branch, where `<baseBranch>` is read from `config.json` `git.defaultBranch` or `git.baseBranch` (fallback: `main`).
- Skip non-code files (markdown, JSON, YAML, config). Return PASS with no findings.
- If no changed files detected, return PASS.

**Tool detection (LOW freedom):**
- Tools are optional — graceful degradation is required (Charter invariant 5).
- Four progressive tiers. Higher tiers add capability; lower tiers always work:

  | Tier | Tool | What it adds | Available when |
  |------|------|-------------|----------------|
  | 0 | rg | Text-pattern extraction + LLM | Always (rg absent → direct LLM review) |
  | 1 | ast-grep | Structural JSON extraction, metavariable capture | `sg` on PATH |
  | 2 | OpenGrep | Cross-function taint, at-exit sinks | `opengrep` on PATH |
  | 3 | Platform LSP | Type info, call hierarchy, diagnostics | Platform provides LSP (out of scope for now) |

- **Detection order**: Read `gates.semantic.tools` from config first. For each tool:
  - If `tools` key exists and tool entry has `"detected": false` → tool unavailable, do not PATH-check.
  - If `tools` key exists and tool entry has `"detected": true` → verify binary on PATH. If missing at runtime, log WARN and skip that tier.
  - If `tools` key exists but a specific tool entry is absent → fall back to PATH detection for that tool only.
  - If `tools` key does not exist (backward compatibility) → fall back to PATH detection for all tools.
- For `sg` (ast-grep): validate identity with `sg --version 2>&1 | grep -iq 'ast-grep'` (plain `which sg` is insufficient — `/usr/bin/sg` from shadow-utils exists on most Linux distros).
- Categories requiring an unavailable tier are silently skipped with an INFO note in the evidence report: "Category {name} skipped: requires {tool} (Tier {n}), not detected."
- The gate never returns FAIL or ERROR due to missing tools — it narrows scope.

**Extraction (HIGH freedom):**
- Extract structural facts from changed files relevant to each category's tier.
- Use the highest available tier's tool for extraction:
  - Tier 0 (rg): text-based extraction of error handlers, callers, resource patterns
  - Tier 1 (ast-grep): `sg scan <file> --json --rule <rule>` for structured extraction
    with metavariable capture. For ad-hoc patterns without a rule file, use
    `sg run --pattern '...' <file> --json` (pass the file path directly — avoid
    `--stdin` as it loses line-number context). If the file doesn't exist on disk yet
    (e.g., PostToolUse with content from stdin), write to `$(mktemp)` first and clean
    up with `rm` after the scan completes.
  - Tier 2 (OpenGrep): `opengrep scan --config <rules-dir> --json <file>` for taint
    analysis. The `<rules-dir>` is resolved from `gates.semantic.tools.opengrep.rulesDir`
    in config, falling back to `.opengrep/rules/` in the project root. If neither exists,
    the resource-lifecycle category is skipped with an INFO note.
- Feed extracted facts (not raw files) to LLM with targeted semantic questions per category.

**Categories (LOW freedom):**
Five categories across three tiers. No overlap with gate-security.

**Tier 0+ (rg or ast-grep extraction + LLM):**

1. **Error-path resource cleanup:** Does any error/exception path in a changed
   function skip releasing/closing an acquired resource (file handle, database
   connection, lock, network socket)? When ast-grep is available (Tier 1+), use
   `sg scan` with error-handler and resource-acquisition patterns for more precise
   extraction; fall back to `rg` patterns if no applicable rule files exist.
2. **Unchecked error-producing calls:** Does any call to a function that returns
   an error or throws get its return value discarded or ignored without explicit
   justification (e.g., cleanup functions where errors are intentionally ignored)?
   When ast-grep is available (Tier 1+), use `sg scan` with call-site and
   return-value patterns; fall back to `rg` patterns if no applicable rule files exist.

**Tier 1+ (requires ast-grep):**

3. **Fail-open handling (CWE-636):** Extract catch/except/rescue blocks from
   changed files using ast-grep. Feed to LLM with: "Does any catch/except block
   silently swallow errors, re-throw a less specific error, or fail to take
   corrective action?" Each finding includes: file path, line range, caught
   exception type (if typed), and a structured verdict: `swallowed`, `broadened`,
   `no-action`, or `acceptable`.
4. **Error data leakage (CWE-209):** Extract error response construction sites
   from changed files using ast-grep (e.g., `new Error(...)`,
   `res.status(4xx).json(...)`, `raise ... from ...`). Feed to LLM with: "Does
   any error response expose internal state, stack traces, database details, or
   file paths to the caller?" Each finding includes: file path, line range, error
   construction pattern, and a structured verdict: `stack-trace`, `internal-state`,
   `db-details`, `file-paths`, or `acceptable`.

**Tier 2+ (requires OpenGrep):**

5. **Resource lifecycle:** Run OpenGrep against changed files with taint rules:
   sources = resource acquisition calls, sinks = function exit points (at-exit),
   sanitizers = resource release calls. Findings represent resources acquired but
   not released on all exit paths. Each finding includes: file path, line range,
   taint path (source → sink), and resource type. When OpenGrep is not available,
   this category is skipped per the Tool detection INFO-note pattern.

**Tier 3 (Platform LSP):** Out of scope — LSP-enhanced analysis deferred to a
future iteration after base tiers are validated.

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- **Default: All findings are WARN.** BLOCK promotion requires calibration (see below).
- No findings = gate PASS. WARN-only findings = gate WARN. Any BLOCK finding = gate FAIL.

**Verdict calibration (LOW freedom):**
- Tier 0 categories (error-path-cleanup, unchecked-errors) are **permanently WARN-only**.
  They use rg + LLM which has insufficient precision for BLOCK verdicts.
- Tier 1+ and Tier 2+ categories may be promoted to BLOCK only when **ALL THREE**
  conditions are met:
  1. At least 5 work units have been shipped with the category enabled (count from
     sw-learn gateCalibration history — each shipped unit increments the count).
  2. The category's cumulative false-positive rate is below 10%. Since the current
     `gateCalibration` schema in `protocols/gate-verdict.md` stores data per gate
     (not per category), use the gate-level FP rate as a conservative proxy:
     `totalFalsePositives / totalFindings` summed across all gateCalibration entries
     for gate-semantic. When `totalFindings` is 0, the FP rate is treated as 0%
     (no findings = no false positives; condition 2 is satisfied, leaving condition 1
     as the binding constraint). A future schema extension may add per-category
     granularity for independent promotion.
  3. The user has opted in via config: `{"name": "<category>", "severity": "block"}`.
- When gateCalibration data does not exist (no units shipped yet), condition 1 is
  not met and findings remain WARN. The gate does not error on missing calibration data.
- When any condition is not met, findings remain WARN regardless of config opt-in.

**Evidence report (LOW freedom):**
- The semantic-report.md evidence file includes:
  - A "## Tool Availability" section listing each tool, its detected status (from
    config or PATH), and the active tier.
  - Each skipped category with the INFO-note reason.
  - Each finding with: category, file path, line range, tier/tool that produced it,
    severity (WARN or BLOCK per calibration), and remediation guidance.

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
| No symbolic tools available | Degrade to pure LLM review (Tier 0). Not an error. |
| Changed files are not code | Return PASS with no findings |
| ast-grep not found | Tier 1+ categories skipped with INFO. Tier 0 categories still run. |
| OpenGrep not found | resource-lifecycle category skipped with INFO. Other categories still run. |
| Tool in config `detected: true` but missing at runtime | Log WARN, skip that tier. Other tiers still run. |
| gateCalibration data missing | All findings remain WARN. No error. |
