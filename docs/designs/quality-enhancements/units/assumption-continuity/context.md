# Context: Assumption Continuity (Unit 2)

## Scope

Implements R5 (late assumption capture in plan + build) and R6 (spec discovery
annotations during build).

## Dependencies

Depends on Unit 1 (Adversarial Depth):
- `core/protocols/build-quality.md` was modified by Unit 1 (R3 replaced the trigger
  section). This unit adds a NEW section (Discovered Behaviors) below the existing
  As-Built Notes section — no conflict with Unit 1's changes.

## Files to Modify

| File | Refinement | Change |
|------|-----------|--------|
| `core/protocols/assumptions.md` | R5 | Add `LATE-FLAGGED` status, late discovery lifecycle, bright-line criticality rule, pre-build + post-task timing (~120 words) |
| `core/skills/sw-plan/SKILL.md` | R5 | Add 1 protocol reference line (~15 words) |
| `core/skills/sw-build/SKILL.md` | R5, R6 | Add 2 protocol reference lines (~40 words total) |
| `core/protocols/build-quality.md` | R6 | Add Discovered Behaviors section after As-Built Notes (~80 words) |
| `core/skills/sw-learn/SKILL.md` | R6 | Add 1 protocol reference line (~15 words) |
| `core/skills/gate-spec/SKILL.md` | R6 | Add 1 protocol reference line (~15 words) |

## Key Integration Points

- `assumptions.md`: Currently has 3 statuses (UNVERIFIED, ACCEPTED, VERIFIED). Add `LATE-FLAGGED` as a 4th status that transitions to VERIFIED/ACCEPTED/DEFERRED.
- `sw-plan/SKILL.md`: Spec constraint section — add late assumption monitoring ref.
- `sw-build/SKILL.md`: After post-build review constraint — add late assumption + discovered behaviors refs.
- `build-quality.md`: After As-Built Notes section (which Unit 1 did not modify) — add new Discovered Behaviors section.
- `sw-learn/SKILL.md`: Discovery section — add discovered behaviors consumption ref.
- `gate-spec/SKILL.md`: Evidence mapping section — add discovered behaviors INFO ref.

## Gotchas

- `build-quality.md` was modified by Unit 1 (R3). This unit adds content AFTER the As-Built Notes section, so there's no conflict. But the builder should read the file fresh — don't assume the old content from before Unit 1.
- The `LATE-FLAGGED` status must NOT block design approval (it's a different lifecycle from UNVERIFIED). The assumptions protocol currently gates on UNVERIFIED. The new status must explicitly state it does not participate in the design gate.
- Late assumptions in build use pre-build + post-task checkpoints (verified assumption A2). The pre-build checkpoint is a quick scan, not a full critic cycle.
- Criticality is narrow: only "directly contradicts an acceptance criterion" triggers a pause (verified assumption A3).
- Discovered behaviors cap at 10 per unit. Use DB-{n} IDs. These are informational only.
