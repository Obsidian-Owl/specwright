# Audit Protocol

## Format

`.specwright/AUDIT.md` is a reference document (not an anchor document). Optional. Never blocks workflow.

Required metadata header:
```
Snapshot: {ISO 8601 timestamp}
Scope: {full | focused: {path}}
Dimensions: {list}
Findings: {count} (B:{n} W:{n} I:{n})
```

Required sections: Summary, Findings (per-finding: `[SEVERITY] F{n}: {title}` with Dimension, Location, Description, Impact, Recommendation, Status), Resolved (resolved findings with resolver ID and date).

## Finding IDs

Format: `F{n}`. IDs are never reused. Resolved findings keep their ID in the `## Resolved` section.

**Matching on re-run:** Match existing open findings by dimension + location (file path or module name). Matched: reuse ID, update description. Unmatched new: assign next available ID. Unmatched existing: mark `stale`.

## Lifecycle

- **Open:** active finding, not yet addressed
- **Stale:** open finding not matched on last re-run (may be resolved or moved)
- **Resolved:** moved to `## Resolved` section with resolver work unit ID and date
- **Purged:** resolved findings older than 90 days are removed on re-run

## Size

Target: 1000-2000 words. Hard cap: 3000 words. On overflow: keep highest-severity, truncate INFO findings, note truncation.

## Freshness

Parse `Snapshot:` timestamp. Default staleness threshold: 30 days. Configurable via `config.audit.stalenessThresholdDays` (optional field, default 30).

- Fresh: use as-is
- Stale: consumer may re-run or proceed without
- Missing: no warning, proceed without
