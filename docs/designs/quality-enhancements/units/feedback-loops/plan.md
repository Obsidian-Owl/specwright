# Plan: Feedback Loops (Unit 3)

## Task Breakdown

### Task 1: Add escalation heuristics to gate-verdict protocol (R9)

**Files:**
- Edit `core/protocols/gate-verdict.md`

**Change:** Add after the Anchor Verification section:
```markdown
## Escalation Heuristics

When BLOCK findings suggest design-level problems rather than implementation bugs,
sw-verify should recommend upstream action.

**Signals** (evaluated after all gates complete):

1. gate-spec: 3+ criteria have FAIL status (systemic, not isolated)
2. gate-wiring: circular dependencies in changed files (structural problem)
3. gate-tests: mutation resistance BLOCK on 50%+ of test files
   — Requires the mutation resistance gate dimension (R2). If absent, exclude
   this signal from the count.
4. gate-security: BLOCK findings in core data flow (not surface-level)
5. Multiple gates (2+) return FAIL simultaneously (compound failure)

**Trigger:** 2 or more signals active.

**Recommendation** (advisory — user decides):
> Design-level concerns detected. Consider `/sw-pivot` to revise remaining plan,
> or `/sw-design <changes>` if the approach needs rethinking. Fixing individual
> findings may not address the root cause.
```

### Task 2: Add calibration data format and rules to gate-verdict protocol (R10)

**Files:**
- Edit `core/protocols/gate-verdict.md`

**Change:** Add after the Escalation Heuristics section:
```markdown
## Calibration Data

Lightweight gate outcome tracking. Designed for projects with 5+ shipped work
units. Silently absent when data is insufficient.

**Data format** (stored as sibling of `findings` in learnings JSON):
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

**Recording (sw-learn):**
- After shipping, record gate outcomes (verdict + finding count) per gate.
- If user dismisses a learning as irrelevant → append to falsePositives for the
  gate+dimension.
- If user reports a shipped bug should have been caught → append to falseNegatives
  for the relevant gate.

**Consumption (sw-verify):**
- Before running gates, scan `.specwright/learnings/` for calibration data from the
  last 5 work units.
- 3+ false positives for a gate+dimension → note: "This dimension has been flagged
  as potentially over-sensitive in recent work units."
- Any false negative → note: "This gate missed issues in a recent unit. Consider
  extra scrutiny."
- Purely informational. No automatic threshold changes.

**Silent absence:** When fewer than 5 work units have been shipped, no calibration
section appears in the verify report.
```

### Task 3: Add protocol references to sw-verify and sw-learn (R9, R10)

**Files:**
- Edit `core/skills/sw-verify/SKILL.md`
- Edit `core/skills/sw-learn/SKILL.md`

**sw-verify changes:**
1. Aggregate report constraint — add:
```
- After all gates, check escalation heuristics per `protocols/gate-verdict.md`.
```
2. Gate execution order — add:
```
- Before running gates, load calibration notes per `protocols/gate-verdict.md`.
```

**sw-learn change:** Add to discovery section:
```
- Record gate calibration data per `protocols/gate-verdict.md`.
```

## File Change Map

| File | Tasks | Action |
|------|-------|--------|
| `core/protocols/gate-verdict.md` | T1, T2 | Edit (add ~180 words) |
| `core/skills/sw-verify/SKILL.md` | T3 | Edit (2 lines) |
| `core/skills/sw-learn/SKILL.md` | T3 | Edit (1 line) |
