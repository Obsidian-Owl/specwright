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

## Baseline Checking

If `.specwright/baselines/{gate}.json` exists:
- Matching findings may be downgraded: FAIL→WARN, WARN→INFO
- Expired baselines are ignored
- Log all downgrades with justification

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

## Anchor Verification

Check findings against:
- `CONSTITUTION.md` — development practices
- `CHARTER.md` — project vision

Where relevant, cite which principle is violated.
