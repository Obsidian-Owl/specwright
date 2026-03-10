# Context: Adversarial Depth (Unit 1)

## Scope

Implements R1 (convergence-tracked critic), R2 (mutation-aware test gate), R3 (universal
post-build review), and R4 (sharpened adversarial agent language).

## Files to Modify

| File | Refinement | Change |
|------|-----------|--------|
| `core/protocols/convergence.md` | R1 | **NEW FILE**: convergence loop procedure, dimensions, scoring rubric, cap (~300 words) |
| `core/skills/sw-design/SKILL.md` | R1 | Add protocol reference line to Critic constraint (~15 words) |
| `core/agents/specwright-architect.md` | R1, R4 | Add convergence scoring to output format + optimistic framing detection + inversion challenge to behavioral discipline (~80 words) |
| `core/skills/gate-tests/SKILL.md` | R2 | Add mutation resistance to analysis dimensions list (~20 words) |
| `core/agents/specwright-tester.md` | R2, R4 | Add structured mutation analysis section + malicious implementation mandate (~90 words) |
| `core/protocols/build-quality.md` | R3 | Replace trigger heuristic with universal depth table + iterative loop cap (~80 words net) |
| `core/agents/specwright-reviewer.md` | R4 | Add letter-vs-spirit + error path swallowing to behavioral discipline (~40 words) |
| `DESIGN.md` | All | Update gate-tests description to mention mutation resistance |

## Key Integration Points

- `sw-design/SKILL.md` line ~74: Critic constraint section — add convergence protocol ref
- `gate-tests/SKILL.md` lines ~44-49: Analysis dimensions list — add 6th dimension
- `build-quality.md` lines ~1-16: Post-Build Review section — replace trigger heuristic
- `specwright-architect.md` lines ~36-38: Behavioral discipline — extend
- `specwright-tester.md` lines ~65-69: Behavioral discipline — extend
- `specwright-reviewer.md` lines ~33-35: Behavioral discipline — extend

## Gotchas

- `build-quality.md` is also modified by Unit 2 (R6 adds Discovered Behaviors section). This unit replaces the trigger section only; Unit 2 adds a new section below As-Built Notes.
- `specwright-architect.md` output format section needs convergence dimensions ONLY when invoked as a scorer (not for all reviews). Use a conditional note.
- The convergence protocol must specify that scoring uses a SEPARATE architect invocation, not self-scoring within the same pass.
- `sw-build/SKILL.md` line ~115 currently references the old trigger heuristic inline. After R3, the protocol handles the trigger logic, so the inline text should be updated to just reference the protocol.
