# Context: Feedback Loops (Unit 3)

## Scope

Implements R9 (verify escalation heuristics) and R10 (gate calibration tracking).

## Dependencies

Depends on Unit 1 (Adversarial Depth):
- R9 escalation signals include "gate-tests: mutation resistance BLOCK on 50%+ of
  test files." This signal depends on R2 (mutation resistance dimension) from Unit 1.
  Without R2, this signal is absent and the remaining 4 escalation signals still
  function. The protocol must note this dependency.

Depends on Unit 2 (Assumption Continuity):
- R10 calibration data in sw-learn records outcomes that may include discovered
  behaviors (R6 from Unit 2). This is a weak dependency — R10 works without R6,
  it just has less data to calibrate against.

## Files to Modify

| File | Refinement | Change |
|------|-----------|--------|
| `core/protocols/gate-verdict.md` | R9, R10 | Add escalation signals section (~100 words) + calibration data format (~80 words) |
| `core/skills/sw-verify/SKILL.md` | R9, R10 | Add 2 protocol reference lines (~30 words) |
| `core/skills/sw-learn/SKILL.md` | R10 | Add 1 protocol reference line (~15 words) |

## Key Integration Points

- `gate-verdict.md`: Currently has Self-Critique Checkpoint, Status Precedence, Visibility
  Requirements, Guardian Posture, and Anchor Verification sections. New escalation and
  calibration sections go after Anchor Verification.
- `sw-verify/SKILL.md`: Aggregate report constraint section — add escalation check ref.
  Gate execution order section — add calibration note loading ref.
- `sw-learn/SKILL.md`: Discovery section — add calibration recording ref.

## Gotchas

- R10 has a cold-start problem: projects with <5 shipped work units won't generate
  enough calibration data. The protocol must specify silent absence when data is
  insufficient (no empty "Calibration: no data" noise in reports).
- R9 escalation signals require counting across gates. The verify skill already has
  access to all gate results at the aggregate report stage.
- The mutation resistance signal in R9 explicitly depends on R2. The protocol must
  note this: "This signal requires the mutation resistance gate dimension. If absent,
  this signal is excluded from the count."
- Calibration data format must fit in the existing learnings JSON schema
  (`{ workId, timestamp, findings }`) — add `gateCalibration` as a sibling field.
