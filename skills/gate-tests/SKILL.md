---
name: gate-tests
description: >-
  Test quality analysis gate with three tiers: essential checks (block),
  quality signals (warn), and detection rules (info). Language-agnostic.
argument-hint: "[epic-id]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Specwright Gate: Test Quality

Three-tier test quality analysis. Tier 1 blocks the pipeline, Tier 2 warns, Tier 3 is informational.
All analysis is language-agnostic — uses Grep, Glob, and LLM reasoning rather than language-specific tools.

## Step 1: Read Configuration and State

Read `.specwright/config.json` for:
- `project.languages` — to identify test file patterns
- `commands.test` — test execution command
- `gates.tests` — optional custom thresholds

Read `.specwright/state/workflow.json`. Extract `currentEpic.id` and `currentEpic.specDir`.
If no epic active, STOP: "No active epic."

Create evidence directory:
```bash
mkdir -p {specDir}/evidence/
```

## Step 2: Identify Scope

### 2a: Determine test file patterns
Based on `project.languages` from config:
- TypeScript/JavaScript: `*.test.ts`, `*.spec.ts`, `*.test.js`, `*.spec.js`, `__tests__/**`
- Python: `test_*.py`, `*_test.py`, `tests/**`
- Go: `*_test.go`
- Rust: files containing `#[cfg(test)]`, `tests/` directory
- Other: ask LLM to identify test patterns

### 2b: Get changed files
```bash
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10
```
Filter to source files (exclude test files) to identify what needs test coverage.

### 2c: Get test files for changed source files
Map changed source files to their corresponding test files using naming conventions from the language.

## Step 3: Tier 1 — Essential Checks (BLOCK on failure)

Any Tier 1 failure sets gate status to FAIL.

### 3a: Test Coverage
If a coverage command is available in config or can be inferred:
- Run coverage and capture output
- Parse coverage percentage (format varies by language — use LLM to parse)
- Threshold: >= 80% (configurable via `gates.tests.coverageThreshold`)
- If coverage tool unavailable: WARN (not FAIL), log "Coverage tool not configured"

### 3b: Assertion Density
For each test file in scope:
- Use Grep to find test functions/methods (patterns vary by language)
- Use Grep to find assertion calls (assert, expect, should, etc.)
- Calculate: `density = total assertions / total test functions`
- Threshold: >= 2 assertions per test (configurable)
- Note: LLM should recognize assertion patterns for the project's test framework

### 3c: Tautological Tests
Search for tests that always pass regardless of implementation:
- Tests with zero assertions
- Tests that assert a value equals itself
- Tests that only check truthy/falsy without meaningful comparison
- Use Grep + LLM analysis to detect these patterns
- Threshold: Zero tautological tests

### 3d: Changed Code Has Tests
For each changed source file:
- Verify a corresponding test file exists
- Verify the test file has been updated (if source file was modified)
- New source files without tests = FAIL
- Threshold: All changed source files have test coverage

## Step 4: Tier 2 — Quality Signals (WARN on failure)

Tier 2 failures do NOT block but record warnings.

### 4a: Negative Test Ratio
Count test functions matching error/invalid/failure patterns.
- Threshold: >= 25% of tests cover error cases

### 4b: Test-to-Code Ratio
Compare total test lines to total source lines in scope.
- Threshold: >= 0.8:1 (configurable)

### 4c: Flaky Patterns
Search for patterns known to cause flaky tests:
- Sleep/delay calls in tests
- Time-dependent assertions
- Random value generation without seeds
- Threshold: Zero flaky patterns

### 4d: Mock Ratio
If mocking is used, compare mock setup to assertion volume.
- Threshold: More assertions than mock setup lines

### 4e: Test Isolation
Check for tests that depend on external state:
- Database calls without cleanup/fixtures
- Network calls without mocking
- File system operations without temp directories

## Step 5: Tier 3 — Detection Rules (INFO only)

Flag test quality opportunities: weak assertions (not-null instead of specific value checks), over-mocking (>5 dependencies), missing boundary values (zero/negative/large for numeric parameters), and long setup functions (>50 lines). These are informational suggestions for improvement.

## Step 6: Update Gate Status

Determine final status:
- Any Tier 1 failure: FAIL
- All Tier 1 pass, Tier 2 warnings: PASS (with warnings noted)
- All pass: PASS

Update `.specwright/state/workflow.json` `gates.tests`:
```json
{"status": "PASS|FAIL", "lastRun": "<ISO>", "evidence": "{specDir}/evidence/test-quality.md"}
```

## Step 7: Save Evidence

Write `{specDir}/evidence/test-quality.md` with three sections (Tier 1 BLOCK checks, Tier 2 WARN checks, Tier 3 INFO findings). Format: Epic/Date/Status header, Tier 1 table with Coverage, Assertion Density, Tautological Tests, and Changed Code Coverage rows (PASS/FAIL + detail), Tier 2 table with Negative Test Ratio, Test:Code Ratio, Flaky Patterns, Mock Ratio, Test Isolation rows (PASS/WARN + detail), and Tier 3 findings with file:line references.

## Step 8: Output Result
```
TESTS GATE: {PASS|FAIL}
Tier 1 (BLOCK): {pass}/{total} passed
Tier 2 (WARN): {pass}/{total} passed
Tier 3 (INFO): {count} findings
Evidence: {specDir}/evidence/test-quality.md
```
