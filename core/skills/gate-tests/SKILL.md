---
name: gate-tests
description: >-
  Audits test quality — assertion strength, boundary coverage, mock
  discipline, error path testing. Delegates to the tester agent for
  adversarial analysis. Internal gate — invoked by verify.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
  - Task
---

# Gate: Test Quality

## Goal

Ensure tests are actually worth having. Passing tests that don't catch bugs
are worse than no tests — they create false confidence. This gate audits
test quality, not just pass/fail.

## Inputs

- `.specwright/config.json` -- test commands, project language
- `.specwright/TESTING.md` -- testing strategy with boundary classifications (optional)
- `.specwright/state/workflow.json` -- current work unit
- Test files in the codebase

## Outputs

- Evidence file at `{currentWork.workDir}/evidence/test-quality.md`
- Gate status in workflow.json
- Findings organized by category with specific file:line references

## Constraints

**Scope (MEDIUM freedom):**
- Focus on test files related to the current work unit.
- Identify test files via convention (test/, __tests__/, *.test.*, *.spec.*).

**Analysis (HIGH freedom):**
- Delegate to `specwright-tester` agent for adversarial test quality review.
- The tester evaluates against these quality dimensions:
  - **Assertion strength**: Are assertions specific? (`toBe(42)` vs `toBeDefined()`)
  - **Boundary coverage**: Are edge cases tested? (empty, null, max, negative)
  - **Mock discipline**: Are mocks justified? Are integration boundaries real?
  - **Error paths**: Are failure scenarios tested? (network down, invalid input)
  - **Behavior focus**: Do tests verify behavior or implementation details?
  - **Mutation resistance**: Could a trivially wrong implementation pass? Test against three bypass classes: hardcoded returns, partial implementations, boundary skips.
  - **Boundary test approach**: Validate mock-vs-integration decisions against TESTING.md boundary classifications per `protocols/testing-strategy.md`. WARN if internal boundary is mocked. INFO if TESTING.md absent.
  - **Tier distribution**: For each AC tagged with `[tier: integration]`, `[tier: contract]`, or `[tier: e2e]`, check whether corresponding tests exist at that tier. Use heuristics: integration tests touch multiple modules and use real infrastructure (Testcontainers, real DB, httptest with real handler); contract tests validate schema or shape at a boundary; E2E tests exercise a full flow. Verdicts: non-unit ACs with matching tier tests that pass → PASS. Non-unit ACs with tier-appropriate tests that fail → BLOCK (forces user decision at gate). Non-unit ACs with only unit-tier tests → BLOCK. Zero non-unit ACs in spec → PASS (nothing to check). When no tier-tagged ACs exist and TESTING.md is absent → INFO (no data to validate, no false positives).
- Each weakness is a finding with severity and file:line reference.

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- BLOCK findings: tests that verify nothing (e.g., `expect(result).toBeDefined()` only).
- WARN findings: missing edge cases, over-mocking, weak assertions.
- INFO findings: style suggestions, naming improvements.

## Protocol References

- `protocols/gate-verdict.md` -- verdict rendering
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates
- `protocols/delegation.md` -- tester agent delegation
- `protocols/testing-strategy.md` -- boundary classifications for mock-vs-integration validation

## Failure Modes

| Condition | Action |
|-----------|--------|
| No test files found | Gate FAIL: "No tests found for this work unit" |
| Tester agent unavailable | Fall back to inline analysis (less thorough) |
| Project has no test framework | Gate SKIP with note |
