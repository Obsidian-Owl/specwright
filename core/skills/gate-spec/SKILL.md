---
name: gate-spec
description: >-
  Maps every acceptance criterion from the spec to implementation evidence
  and test evidence. Criteria without evidence fail. The ultimate quality
  gate. Internal — invoked by verify.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
  - Task
---

# Gate: Spec Compliance

## Goal

Prove that the implementation actually does what was asked for. Every
acceptance criterion in the spec must map to implementation evidence
(file:line) and test evidence (test name at file:line). This is the gate
that closes the loop.

## Inputs

- `{currentWork.workDir}/spec.md` -- acceptance criteria
- `.specwright/state/workflow.json` -- current work unit
- The codebase (implementation and tests)

## Outputs

- Evidence file at `{currentWork.workDir}/evidence/spec-compliance.md`
- Compliance matrix: each criterion → implementation ref + test ref + status
- Gate status in workflow.json

## Constraints

**Criteria extraction (LOW freedom):**
- Parse spec.md for all acceptance criteria (lines matching `- [ ] AC-*`).
- Number them. Every single one must be mapped. No skipping.
- On the final work unit of a multi-WU design: also parse behavioral integration
  criteria (IC-B{n} entries) from `integration-criteria.md` in the design-level
  directory. IC-B entries are added to the compliance matrix alongside ACs. When
  not on the final work unit, or when `integration-criteria.md` has no IC-B entries,
  gate-spec operates exactly as before — no behavioral IC mapping.

**Evidence mapping (HIGH freedom):**
- For each criterion, search the codebase for implementation evidence.
- For each criterion, search test files for test evidence.
- Delegate to `specwright-reviewer` for thorough analysis if needed.
- For behavioral criteria (execution-path claims, not structural checks), use
  the verification template from `protocols/semi-formal-reasoning.md`.
- Evidence must be specific: file path and line number, not "somewhere in src/".

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- Criterion with both implementation AND test evidence = PASS.
- Criterion with implementation but no test = WARN.
- Criterion with neither = FAIL.
- Overall: if ANY criterion is FAIL, gate is FAIL.
- IC-B entries (when present): IC-B with both implementation and test evidence = PASS.
  IC-B without test evidence = FAIL (gate-spec's standard verdict vocabulary). Note:
  gate-spec FAIL for IC-Bs and deliverable verification BLOCK for IC-Bs are
  complementary — gate-spec reports the finding within its standard framework,
  deliverable verification enforces the action. gate-spec runs first (as part of the
  6 standard gates); deliverable verification runs after all gates.
- Reference discovered behaviors at INFO level per `protocols/build-quality.md`. Does not alter PASS/WARN/FAIL verdict.

**Compliance matrix format:**
```
| # | Criterion | Implementation | Test | Status |
|---|-----------|---------------|------|--------|
| AC-1 | Description | file:line | test_name at file:line | PASS |
```

## Protocol References

- `protocols/semi-formal-reasoning.md` -- verification template for behavioral criteria
- `protocols/gate-verdict.md` -- verdict rendering and self-critique
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates
- `protocols/delegation.md` -- reviewer agent delegation

## Failure Modes

| Condition | Action |
|-----------|--------|
| No spec.md found | Gate ERROR: "No spec found for this work unit" |
| No acceptance criteria in spec | Gate ERROR: "Spec has no acceptance criteria" |
| Implementation exists but tests don't | WARN per criterion, gate WARN overall |
| Can't determine mapping with confidence | FAIL the criterion. Don't guess. |
