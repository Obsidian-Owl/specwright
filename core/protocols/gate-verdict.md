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

## Calibration Data

Lightweight gate outcome tracking. Designed for projects with 5+ shipped work
units. Silently absent when data is insufficient.

**Data format** (stored as a sibling field in the learnings JSON):
```json
{
  "gateCalibration": {
    "{gateName}": {
      "verdict": "PASS|WARN|FAIL",
      "findingCount": 0,
      "falsePositives": ["dimension description"],
      "falseNegatives": ["bug description"]
    }
  }
}
```

**Recording (sw-learn) — mandatory:**
- Recording is mandatory. Every shipped work unit produces calibration data for all gates that ran.
- After shipping, record gate outcomes (verdict + finding count) per gate, even if all PASS with 0 findings.
- If user explicitly labels a gate finding as "false positive" → append to `falsePositives` for the gate+dimension. Dismissing a learning without labeling it FP does NOT add to the array.
- If user reports a shipped bug should have been caught → append to `falseNegatives`
  for the relevant gate.

**Consumption (sw-verify):**
- Before running gates, scan `.specwright/learnings/` for calibration data from the
  last 5 work units.
- 3+ false positives from distinct work units for a gate+dimension → note:
  "This dimension has been flagged as potentially over-sensitive in recent work units."
- Any false negative → note: "This gate missed issues in a recent unit. Consider
  extra scrutiny."
- Purely informational. No automatic threshold changes.

**Silent absence:** When fewer than 5 work units have been shipped, no calibration
section appears in the verify report. No "Calibration: no data" message.

**Resilience:** When a learnings JSON file exists but lacks the `gateCalibration`
field, it is silently skipped. Corrupt or unparseable learnings files are also
silently skipped.
