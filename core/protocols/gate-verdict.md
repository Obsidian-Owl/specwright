# Gate Verdict Protocol

## Default Stance

**Default verdict: FAIL**

Evidence must prove PASS, not the other way around. Absence of evidence is not evidence of absence.

## Self-Critique Checkpoint

Before finalizing verdict, ask:
- Did I accept anything without citing proof?
- Did I give benefit of the doubt?
- Would a skeptical auditor agree?
- If ambiguous → FAIL

## Status Precedence

```
ERROR > FAIL > WARN > PASS
```

If any finding is ERROR, overall status is ERROR.
If any finding is FAIL and none ERROR, overall status is FAIL.
And so on.

## Visibility Requirements

Explain each finding in plain language:
- **What was found:** Specific location, code, pattern
- **Why it matters:** Impact, risk, or spec violation
- **What to do:** Actionable remediation

Not just: "Security: FAIL"

## Guardian Posture

The verify phase exists to catch problems, not to rubber-stamp shipping.

- Present findings as issues to address, not obstacles to dismiss.
- Never recommend shipping when blocking findings exist.
- Warnings are real: explain why each matters and what the user risks by
  shipping with them. Let the user make an informed decision.
- The default tone is "here's what needs attention" not "everything looks
  fine except..."

## Anchor Verification

Check findings against:
- `CONSTITUTION.md` — development practices
- `CHARTER.md` — project vision

Where relevant, cite which principle is violated.

## Escalation Heuristics

When BLOCK findings suggest design-level problems rather than implementation bugs,
sw-verify should recommend upstream action.

**Signals** (evaluated after all gates complete):

1. **gate-spec**: 3+ criteria have FAIL status (systemic, not isolated)
2. **gate-wiring**: circular dependencies in changed files (structural problem)
3. **gate-tests**: mutation resistance BLOCK on 50%+ of test files — Requires the mutation resistance gate dimension (R2). If R2 is not implemented, this signal is excluded from the escalation count and the remaining 4 signals still function.
4. **gate-security**: BLOCK findings in core data flow (not surface-level)
5. **Multiple gates** (2+) return FAIL simultaneously (compound failure)

**Trigger:** 2 or more signals active. When exactly 1 signal is active, no escalation recommendation is shown.

**Recommendation** (advisory — the user decides):
> Design-level concerns detected. Consider `/sw-pivot` to revise the remaining plan,
> or `/sw-design` if the approach needs rethinking. Fixing individual findings may
> not address the root cause.
