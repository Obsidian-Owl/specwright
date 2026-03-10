# Spec: Feedback Loops

## Acceptance Criteria

### R9: Verify Escalation Heuristics

- [ ] AC-1: `core/protocols/gate-verdict.md` contains an "Escalation Heuristics" section (after the existing Anchor Verification section) that defines five escalation signals: (1) gate-spec: 3+ criteria have FAIL status, (2) gate-wiring: circular dependencies in changed files, (3) gate-tests: mutation resistance BLOCK on 50%+ of test files, (4) gate-security: BLOCK findings in core data flow, (5) multiple gates FAIL simultaneously.

- [ ] AC-2: The escalation signal for gate-tests mutation resistance (signal 3) includes an explicit note that this signal requires the mutation resistance gate dimension from R2. If R2 is not implemented, this signal is excluded from the escalation count and the remaining 4 signals still function.

- [ ] AC-3: `core/protocols/gate-verdict.md` Escalation Heuristics section specifies the trigger rule: any 2 or more escalation signals active triggers the escalation recommendation. The recommendation text contains the substrings "/sw-pivot", "/sw-design", and "root cause". The section explicitly states the recommendation is advisory and the user decides.

- [ ] AC-4: `core/skills/sw-verify/SKILL.md` aggregate report constraint contains a reference to check escalation heuristics per `protocols/gate-verdict.md` after all gates complete. The reference is 1 line. No inline escalation logic.

### R10: Gate Calibration Tracking

- [ ] AC-5: `core/protocols/gate-verdict.md` contains a "Calibration Data" section (after the Escalation Heuristics section) that defines the data format: `gateCalibration: { gateName: { verdict, findingCount, falsePositives: [], falseNegatives: [] } }` stored as a sibling field in the learnings JSON.

- [ ] AC-6: `core/protocols/gate-verdict.md` Calibration Data section specifies recording behavior: (a) sw-learn records gate outcomes (verdict + finding count) for each shipped unit, (b) a dismissed learning produces a false positive signal for the relevant gate+dimension, (c) a user-reported shipped bug produces a false negative signal for the relevant gate.

- [ ] AC-7: `core/protocols/gate-verdict.md` Calibration Data section specifies consumption behavior: (a) sw-verify scans `.specwright/learnings/` for calibration data from the last 5 work units before running gates, (b) 3+ false positive signals from distinct work units for a gate+dimension produces a note in the report ("potentially over-sensitive"), (c) any false negative signal produces a note ("missed issues, consider extra scrutiny"), (d) calibration notes are purely informational — no automatic threshold changes.

- [ ] AC-8: `core/protocols/gate-verdict.md` Calibration Data section specifies silent absence: when fewer than 5 work units have been shipped (insufficient calibration data), no calibration section appears in the verify report. No "Calibration: no data" message.

- [ ] AC-9: `core/skills/sw-learn/SKILL.md` contains a reference to record gate calibration data per `protocols/gate-verdict.md`. The reference is 1 line.

- [ ] AC-10: `core/skills/sw-verify/SKILL.md` contains a reference to load calibration notes per `protocols/gate-verdict.md` before gate execution. The reference is 1 line.

### Boundary Cases

- [ ] AC-11: `core/protocols/gate-verdict.md` Calibration Data section specifies that when a learnings JSON file exists but lacks the `gateCalibration` field, it is silently skipped (no error, no partial data). Corrupt or unparseable learnings files are also silently skipped.

- [ ] AC-12: `core/protocols/gate-verdict.md` Escalation Heuristics section specifies that when exactly 1 escalation signal is active, no escalation recommendation is shown. The trigger requires 2 or more.

### Cross-cutting

- [ ] AC-13: No SKILL.md file modified in this unit grows by more than 35 words net (measured by `wc -w` on added lines). All behavioral detail lives in the gate-verdict protocol, not inlined in skill files.
