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

- `.specwright/work/{id}/spec.md` -- acceptance criteria
- `.specwright/state/workflow.json` -- current work unit
- The codebase (implementation and tests)

## Outputs

- Evidence file at `.specwright/work/{id}/evidence/spec-compliance.md`
- Compliance matrix: each criterion → implementation ref + test ref + status
- Gate status in workflow.json

## Constraints

**Criteria extraction (LOW freedom):**
- Parse spec.md for all acceptance criteria (lines matching `- [ ] AC-*`).
- Number them. Every single one must be mapped. No skipping.

**Evidence mapping (HIGH freedom):**
- For each criterion, search the codebase for implementation evidence.
- For each criterion, search test files for test evidence.
- Delegate to `specwright-reviewer` for thorough analysis if needed.
- Evidence must be specific: file path and line number, not "somewhere in src/".

**Verdict (LOW freedom):**
- Follow `protocols/gate-verdict.md`.
- Criterion with both implementation AND test evidence = PASS.
- Criterion with implementation but no test = WARN.
- Criterion with neither = FAIL.
- Overall: if ANY criterion is FAIL, gate is FAIL.
- Self-critique: would a skeptical auditor agree with each mapping?

**Compliance matrix format:**
```
| # | Criterion | Implementation | Test | Status |
|---|-----------|---------------|------|--------|
| AC-1 | Description | file:line | test_name at file:line | PASS |
```

## Protocol References

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
