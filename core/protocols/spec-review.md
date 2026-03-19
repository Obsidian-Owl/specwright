# Spec Review Protocol

Pre-build spec quality review. Catches untestable criteria, vague language, and
missing edge cases before build time is spent on a bad spec.

## When to Invoke

After each spec is drafted in sw-plan — for both single-unit specs and each
per-unit spec in multi-unit work — before presenting to the user for approval.

## How to Invoke

Delegate to `specwright-architect` with:
- The full spec (all acceptance criteria)
- The design.md for grounding context
- This protocol (the six dimensions and finding levels below)
- Instruction: "Review these acceptance criteria for quality. Return findings
  grouped by dimension. Do not suggest implementation — only assess spec quality."

## Quality Dimensions

### 1. Testability
Each criterion must describe an observable, verifiable outcome. A tester must
be able to write a concrete test (automated or manual check) without guessing.

**Flag phrases:** "works correctly", "handles edge cases", "performs well",
"is user-friendly", "behaves as expected", "functions properly"

**Example (bad):** "The API handles errors correctly."
**Example (good):** "If the API receives a request with a missing required field,
it returns HTTP 400 with a JSON body containing an `errors` array."

### 2. Measurability
Prefer numeric or behavioral thresholds over subjective adjectives. The pass/fail
boundary must be unambiguous.

**Flag phrases:** "fast enough", "reasonable", "appropriate", "good performance",
"acceptable", "sufficient", "minimal overhead"

**Example (bad):** "The search response is fast enough for users."
**Example (good):** "Search results are returned within 500ms for queries up to
100 characters on a dataset of 10,000 records."

### 3. Completeness
At least one error or boundary case per functional area. Happy-path-only specs
miss the behaviors that matter most.

**Look for:** criteria sets that only describe the success case with no
corresponding error case, input validation, or limit behavior.

### 4. Ambiguity
Acceptance criteria must state what will be verified, not what should happen.
Hedge words leave it to the implementer to decide what "enough" means.

**Flag phrases:** "should", "might", "can", "may", "ideally", "where possible",
"at minimum", "generally"

**Example (bad):** "The form should validate required fields."
**Example (good):** "Submitting the form with an empty required field displays
an inline error message below that field and prevents form submission."

### 5. Grounding
Each criterion must be traceable to a design decision, requirement, or
explicitly stated constraint. Criteria that appear from nowhere may reflect
scope creep or misunderstanding.

**Look for:** criteria that introduce behavior not mentioned in the design.md,
context.md, or the user's stated requirements.

### 6. Testability Proof
The architect's review output must include a concrete test description for each
AC — not a restatement of the criterion, but a specific test: inputs, action,
and expected observable result.

**Example:** "AC-1 can be tested by: calling `add(2, 3)` and asserting the
result equals `5`."

**Rule:** If the architect cannot write a concrete test description for an AC,
that AC is a BLOCK finding. Inability to describe a concrete test is evidence
the criterion is not testable as written.

## Finding Levels

| Level | Meaning | Action required |
|-------|---------|-----------------|
| **BLOCK** | Criterion cannot be tested as written | Must be revised or explicitly overridden by user before spec is finalized |
| **WARN** | Vague language or missing boundary case | User may revise or accept as-is |
| **INFO** | Style suggestion or minor improvement | Never blocking; shown for awareness only |

## Resolution Flow

1. Architect returns findings grouped by dimension (BLOCK first, then WARN, INFO).
2. **BLOCKs:** Present each to the user with the finding and a suggested revision.
   User options: (a) revise the criterion, (b) override with stated reason.
3. **WARNs:** Present alongside the spec at the user approval checkpoint.
   User options: (a) revise, (b) accept as-is.
4. **INFOs:** Show as a summary line. No action required.
5. If any criteria were revised: re-delegate to architect for another pass.
   Maximum 2 re-delegate iterations. After 2 passes, treat remaining WARNs as
   accepted and proceed.
6. Overridden BLOCKs are noted with the user's reason. They do not block approval.

## Failure Mode

If architect returns no findings: spec passes review. Note "Spec review: no issues
found." and proceed to user approval checkpoint.
