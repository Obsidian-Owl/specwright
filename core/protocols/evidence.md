# Evidence Protocol

## Evidence Storage

**Directory structure:**
```
{currentWork.workDir}/evidence/
```

**File naming:**
```
{gate-name}-report.md
```

Examples:
- `security-report.md`
- `spec-compliance.md`
- `test-quality.md`

## Gate State Updates

After each gate, update `workflow.json`:

```json
{
  "gates": {
    "security": {
      "status": "PASS",
      "lastRun": "2026-02-10T12:34:56Z",
      "evidence": "{currentWork.workDir}/evidence/security-report.md"
    }
  }
}
```

**Status values:** `PASS`, `WARN`, `FAIL`, `ERROR`, `SKIP`

`SKIP` — gate was skipped; no evidence file produced.

## Freshness

Evidence older than 30 minutes is stale. Re-run the gate.

## Visibility

**Surface key findings inline in gate output.** Users should not need to read evidence files to understand results.

Evidence files are for:
- Detailed audit trail
- Future reference
- External review

Not for:
- Primary communication
- User decision-making
