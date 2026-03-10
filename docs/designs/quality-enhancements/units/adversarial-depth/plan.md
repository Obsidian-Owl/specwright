# Plan: Adversarial Depth (Unit 1)

## Task Breakdown

### Task 1: Create convergence protocol (R1)

**Files:**
- Create `core/protocols/convergence.md`

**Structure:**
```markdown
# Convergence Protocol

## Purpose
## Dimensions
  - Completeness (1-5)
  - Coherence (1-5)
  - Feasibility (1-5)
  - Risk Coverage (1-5)
## Scoring Rubric
  - 1-2: significant gaps
  - 3: adequate but notable weaknesses
  - 4: strong with minor issues
  - 5: comprehensive
## Procedure
  1. First iteration = existing critic pass
  2. Separate invocation scores dimensions
  3. If all 4+: converge. Else: targeted follow-up on <4 dims
  4. Max 3 iterations total
## Integration
  - Scores appear in design.md "Design Quality" section
```

Target: ~300 words.

### Task 2: Add convergence reference to sw-design and architect (R1)

**Files:**
- Edit `core/skills/sw-design/SKILL.md` — Critic constraint section
- Edit `core/agents/specwright-architect.md` — Output format section

**sw-design change:** Add after line ~74 (critic constraint):
```
- Follow `protocols/convergence.md` for iterative critic loop with convergence scoring.
```

**architect change:** Add to output format section, after Verdict:
```
- **Convergence scores** (when invoked as convergence scorer only):
  Completeness: N/5, Coherence: N/5, Feasibility: N/5, Risk Coverage: N/5
```

### Task 3: Add mutation resistance to gate-tests and tester agent (R2)

**Files:**
- Edit `core/skills/gate-tests/SKILL.md` — Analysis dimensions
- Edit `core/agents/specwright-tester.md` — Add structured mutation section

**gate-tests change:** Add 6th bullet to analysis dimensions list:
```
  - **Mutation resistance**: Could a trivially wrong implementation pass? Test against
    three bypass classes: hardcoded returns, partial implementations, boundary skips.
```

**tester change:** Add new section after "The lazy implementation test":
```
## Structured mutation analysis (for test audits)

When auditing existing tests (not writing new ones), evaluate each bypass class:

1. **Hardcoded returns**: Could a lookup table pass these tests?
2. **Partial implementations**: Could implementing half the requirements pass?
3. **Off-by-one / boundary skips**: Could happy-path-only code pass?

Per class, report:
- PASS: cite specific tests that catch this bypass (file:line)
- WARN: gap exists but in low-risk code
- BLOCK: construct a concrete bypassing implementation; no test catches it
```

### Task 4: Universal post-build review in protocol (R3)

**Files:**
- Edit `core/protocols/build-quality.md` — Replace trigger section
- Edit `core/skills/sw-build/SKILL.md` — Update inline trigger reference

**build-quality.md change:** Replace lines 7-10 (trigger heuristic) with:
```markdown
**Trigger:** All units receive post-build review. No units skip.

**Depth calibration:**

| Unit size | Depth | Reviewer scope |
|-----------|-------|---------------|
| 1-3 tasks AND <5 files | Light | Spec compliance check only. Single pass. BLOCK findings only. |
| 4+ tasks OR 5+ files | Standard | Full review. BLOCK → user, WARN → awareness. |
| Security-tagged criteria | Standard | Full review + security focus. Regardless of size. |

**Iterative loop (max 2 cycles):** If the reviewer finds BLOCK findings, present to
user. If user fixes, the reviewer gets ONE re-review pass. No further review cycles.
```

**sw-build.md change:** Replace line ~115 inline trigger with protocol-only reference.

### Task 5: Sharpen adversarial language in agent prompts (R4)

**Files:**
- Edit `core/agents/specwright-architect.md` — Behavioral discipline
- Edit `core/agents/specwright-tester.md` — Behavioral discipline
- Edit `core/agents/specwright-reviewer.md` — Behavioral discipline

**architect additions** (append to behavioral discipline bullets):
```
- Detect optimistic framing: when a design says "this should work" or "straightforward integration," treat it as a red flag. Demand evidence or flag as an assumption.
- Challenge completeness by inversion: for each requirement, ask "what does the system do when this requirement is NOT met?" If the design is silent, flag it.
```

**tester addition** (append to behavioral discipline bullets):
```
- Before finalizing any test suite, explicitly construct a mental model of a "malicious implementation" — one that technically passes all tests but violates the spec's intent. If you can construct one, your tests have a hole. Patch it.
```

**reviewer additions** (append to behavioral discipline bullets):
```
- Check for "letter vs. spirit" compliance: an implementation that technically satisfies acceptance criteria wording but misses the underlying intent is a WARN finding. Cite the spec criterion and explain the gap.
- Verify error paths aren't swallowed: look for empty catch blocks, generic error returns, and silenced failures. These pass tests but break production.
```

### Task 6: Update DESIGN.md and verify token budget (cross-cutting)

**Files:**
- Edit `DESIGN.md` — Gate-tests table entry

**DESIGN.md change:** Update gate-tests row in Internal Gate Skills table:
```
| `gate-tests` | Test quality: assertions, boundaries, mocks, mutation resistance | BLOCK/WARN |
```

**Verification:** After all edits, confirm no modified SKILL.md grew by more than 30 words.

## File Change Map

| File | Tasks | Action |
|------|-------|--------|
| `core/protocols/convergence.md` | T1 | Create |
| `core/skills/sw-design/SKILL.md` | T2 | Edit (1 line) |
| `core/agents/specwright-architect.md` | T2, T5 | Edit (~4 lines) |
| `core/skills/gate-tests/SKILL.md` | T3 | Edit (2 lines) |
| `core/agents/specwright-tester.md` | T3, T5 | Edit (~12 lines) |
| `core/protocols/build-quality.md` | T4 | Edit (replace section) |
| `core/skills/sw-build/SKILL.md` | T4 | Edit (1-2 lines) |
| `core/agents/specwright-reviewer.md` | T5 | Edit (~3 lines) |
| `DESIGN.md` | T6 | Edit (1 line) |
