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
  - mcp__plugin_oh-my-claudecode_omc-tools__ast_grep_search
---

# Specwright Gate: Test Quality

Three-tier test quality analysis. Tier 1 blocks, Tier 2 warns, Tier 3 is informational. Prefer `ast_grep_search` for structural queries (fallback to Grep).

Default verdict is FAIL. Evidence must be cited before any verdict. Absence of evidence is evidence of non-compliance.

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
If `commands.test` is null AND zero test files found: write ERROR status, STOP.

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
- Threshold: >= 2.5 assertions per test (configurable)
- Note: LLM should recognize assertion patterns for the project's test framework

### 3c: Tautological Tests
Tests that always pass:
- Zero assertions, self-equality checks, truthy-only checks
- Assertions passing under trivial mutations (constant return, branch swap, conditional removal). Non-constraining assertions (checking definedness vs expected value) are BLOCK.
- If loose check (optional field) vs weak assertion (computed value definedness) is unclear, invoke AskUserQuestion.
- Detection: Grep + LLM analysis
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
- Threshold: >= 30% of tests cover error cases

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

Flag test quality opportunities: weak assertions (not-null vs specific values), over-mocking (>5 dependencies), missing boundary values (zero/negative/large), long setup (>50 lines).

## Step 6: Baseline Check
If `.specwright/baselines/gate-tests.json` exists: matching entries downgrade BLOCK->WARN, WARN->INFO. Expired entries ignored. Partial match: AskUserQuestion. Log downgrades in evidence.

## Step 7: Update Gate Status

**Self-critique checkpoint:** Before finalizing — did I accept anything without citing proof? Did I give benefit of the doubt? Would a skeptical auditor agree? Gaps are not future work. TODOs are not addressed. Partial implementations do not match intent. If ambiguous, FAIL.

Determine final status:
- Incomplete analysis: ERROR (invoke AskUserQuestion)
- Any Tier 1 failure: FAIL
- All Tier 1 pass, any Tier 2 warning: WARN
- All pass: PASS

Update `.specwright/state/workflow.json` `gates.tests`:
```json
{"status": "PASS|WARN|FAIL|ERROR", "lastRun": "<ISO>", "evidence": "{specDir}/evidence/test-quality.md"}
```

## Step 8: Save Evidence
Write `{specDir}/evidence/test-quality.md`: Tier 1 table (Coverage, Assertion Density, Tautological, Changed Code Coverage with PASS/FAIL + detail), Tier 2 table (Negative Ratio, Test:Code Ratio, Flaky, Mock Ratio, Isolation with PASS/WARN + detail), Tier 3 findings with file:line.

## Step 9: Output Result
```
TESTS GATE: {PASS|WARN|FAIL}
Tier 1 (BLOCK): {pass}/{total} passed
Tier 2 (WARN): {pass}/{total} passed
Tier 3 (INFO): {count} findings
```
