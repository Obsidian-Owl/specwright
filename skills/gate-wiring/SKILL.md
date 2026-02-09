---
name: gate-wiring
description: >-
  Integration and wiring verification. Detects dead code, unused exports,
  architecture layer violations, and circular dependencies using LLM analysis.
argument-hint: "[epic-id]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - mcp__plugin_oh-my-claudecode_omc-tools__ast_grep_search
---

# Specwright Gate: Wiring and Integration

Verifies that all code is properly wired: exports used, imports follow architecture rules,
no dead code, and no circular dependencies. All analysis is LLM-driven using Grep/Glob.

Prefer `ast_grep_search` for structural queries. Fallback to Grep if unavailable.

Default verdict is FAIL. Evidence must be cited before any verdict. Absence of evidence is evidence of non-compliance.

## Step 1: Read Configuration and State

Read `.specwright/config.json` for:
- `project.languages` — file extensions and import patterns
- `architecture.style` and `architecture.layers` — layer rules
- `gates.wiring` — wiring-specific config (checkImports, checkEndpoints, checkEvents)

Read `.specwright/state/workflow.json` for epic context.
If no epic active, STOP.

Create evidence directory:
```bash
mkdir -p {specDir}/evidence/
```

## Step 2: Determine Scope

Get changed files in this epic:
```bash
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10
```
Filter to source files (exclude tests, configs, docs).
Identify which modules/directories were modified.

## Step 3: Phase 1 — Dead Code Detection

### 3a: Unused Exports
For each new or modified source file:
- Use Grep to find all exported symbols (functions, classes, types, constants)
  - The pattern depends on language (e.g., `export` in TS, capitalized names in Go, `pub` in Rust, `def` in Python)
- For each exported symbol, search the entire codebase for imports/usage
- Symbol with zero external references = WARN
- Symbol in changed files with zero external references = BLOCK (new dead code)

### 3b: Orphaned Files
Check if any new files are not imported/referenced by any other file:
- New file with zero inbound references = WARN

## Step 4: Phase 2 — Integration Path Verification

### 4a: Architecture Layer Compliance
If `architecture.layers` is configured (e.g., ["handler", "service", "repository"]):
- Verify imports follow the layer hierarchy (top layers can import lower layers, not vice versa)
- Use Grep to check import statements in each file
- Layer violation (e.g., repository importing handler) = BLOCK

If architecture is "none" or not configured, skip this check.

### 4b: Module Boundary Enforcement
If project structure is "multi-service" or "monorepo":
- Check that modules don't import each other's internal packages
- Shared code should be in designated shared directories
- Cross-module internal import = BLOCK

### 4c: New Public Interfaces
For each new public API, endpoint, or interface:
- Verify it is documented (if documentation conventions exist)
- Verify it is referenced/consumed by at least one caller
- New interface with zero consumers = WARN

## Step 5: Phase 3 — Event/Integration Verification (if configured)

Only run if `gates.wiring.checkEvents` is true in config.

### 5a: Event Publishers and Subscribers
Search for event publishing patterns and verify matching subscribers exist.
- Publisher without subscriber = WARN
- Subscriber without matching publisher = BLOCK

### 5b: API Contract Consistency
If the project has API definitions (OpenAPI, GraphQL schema, protobuf):
- Verify implementation matches contract
- Mismatches = BLOCK

## Step 6: Phase 4 — Dependency Analysis

### 6a: Circular Dependencies
Analyze import statements across modules to detect circular dependency chains.
- Use Grep to extract imports from each file
- Build a mental dependency graph
- Any circular chain = BLOCK

### 6b: New Dependencies
Document any new inter-module dependencies added by this epic.
- List new dependency relationships as INFO

## Step 7: Compile and Score

| Severity | Meaning | Gate Effect |
|----------|---------|-------------|
| BLOCK | Must fix before merge | FAIL gate |
| WARN | Should fix, non-blocking | PASS with warnings |
| INFO | Informational | PASS |

## Step 8: Update Gate Status

**Self-critique checkpoint:** Before finalizing — did I accept anything without citing proof? Did I give benefit of the doubt? Would a skeptical auditor agree? Gaps are not future work. TODOs are not addressed. Partial implementations do not match intent. If ambiguous, FAIL.

Update `.specwright/state/workflow.json` `gates.wiring`:
```json
{"status": "PASS|FAIL", "lastRun": "<ISO>", "evidence": "{specDir}/evidence/wiring-report.md"}
```

## Step 9: Save Evidence

Write `{specDir}/evidence/wiring-report.md`:
```markdown
# Wiring Gate Report
Epic: {epicId}
Date: {timestamp}
Status: PASS/FAIL

## Phase 1: Dead Code Detection
{findings with file:line}

## Phase 2: Integration Paths
### Layer Compliance: PASS/FAIL
{findings}
### Module Boundaries: PASS/FAIL
{findings}
### Public Interfaces: PASS/WARN
{findings}

## Phase 3: Event/Integration (if applicable)
{findings or "Skipped — not configured"}

## Phase 4: Dependencies
### Circular Dependencies: PASS/FAIL
{findings}
### New Dependencies
{list}

## Summary
BLOCK: N findings
WARN: N findings
INFO: N findings
```

## Step 10: Output Result
```
WIRING GATE: PASS/FAIL
Phase 1 (Dead Code): X findings
Phase 2 (Integration): X findings
Phase 3 (Events): X findings or "skipped"
Phase 4 (Dependencies): X findings
Evidence: {specDir}/evidence/wiring-report.md
```
