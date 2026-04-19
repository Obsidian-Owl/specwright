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

- `{projectArtifactsRoot}/config.json` -- test commands, project language
- `{projectArtifactsRoot}/TESTING.md` -- testing strategy with boundary classifications (optional)
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- selected work unit
- Test files in the codebase

## Outputs

- Evidence file at `{workDir}/evidence/test-quality.md`
- Gate status in the selected work's `workflow.json`
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
  - **Mutation resistance**: Tiered analysis (T1/T2/T3) stays inside this gate; missing tools route to T2/T3, never a skip.
    - **T1**: configured tool-backed mutation run. Report concrete file:line evidence plus mutation score or restricted survivor details when available: operator, location, before/after, defect category, and action.
    - **T2**: LLM-generated mutation check when zero applicable mutants make T1 uninformative or when the configured LLM fallback is the active path. Report concrete file:line evidence plus the same restricted survivor details: operator, location, before/after, defect category, and action.
    - **T3**: qualitative floor when T1 errors, T2 errors, or fallback unavailable would otherwise leave the gate blind. Audit the three bypass classes: hardcoded returns, partial implementations, boundary skips.
    - Honor accepted-mutant lineage through the shared approval record and config contract instead of silently waiving survivors.
  - **Boundary test approach**: Validate mock-vs-integration decisions against TESTING.md boundary classifications per `protocols/testing-strategy.md`. WARN if internal boundary is mocked. INFO if TESTING.md absent.
  - **Tier distribution**: For each AC tagged with `[tier: integration]`, `[tier: contract]`, or `[tier: e2e]`, check whether corresponding tests exist at that tier. Use heuristics: integration tests touch multiple modules and use real infrastructure (Testcontainers, real DB, httptest with real handler); contract tests validate schema or shape at a boundary; E2E tests exercise a full flow. Verdicts: non-unit ACs with matching tier tests that pass → PASS. Non-unit ACs with tier-appropriate tests that fail → BLOCK (forces user decision at gate). Non-unit ACs with only unit-tier tests → BLOCK. Zero non-unit ACs in spec → PASS (nothing to check). When no tier-tagged ACs exist and TESTING.md is absent → INFO (no data to validate, no false positives).
- Each weakness is a finding with severity and file:line reference.

**Verdict (LOW freedom):**
- Follow `protocols/evidence.md#verdict-rendering`.
- BLOCK findings: tests that verify nothing (e.g., `expect(result).toBeDefined()` only).
- WARN findings: missing edge cases, over-mocking, weak assertions.
- INFO findings: style suggestions, naming improvements.

## Protocol References

- `protocols/evidence.md#verdict-rendering` -- verdict rendering
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
