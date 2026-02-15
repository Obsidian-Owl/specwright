# Landscape Protocol

## Format

`.specwright/LANDSCAPE.md` is a reference document (not an anchor document). Optional. Never blocks workflow.

Required metadata header:
```
Snapshot: {ISO 8601 timestamp}
Files: {count} | Modules: {count}
```

Required sections: Architecture, Modules (per-module: purpose, key files, public API, dependencies), Conventions, Integration Points, Gotchas.

## Size

- Small projects: 500-1000 words
- Large projects: 1500-2500 words
- Hard cap: 3000 words

## Freshness

Parse `Snapshot:` timestamp. Default staleness threshold: 7 days. Configurable via `config.landscape.stalenessThresholdDays` (optional field, default 7).

- Fresh: use as-is
- Stale: consumer warns user, may refresh inline
- Missing: no warning, proceed without

## Updates

- **Full rewrite**: initial generation and refresh (replace entire document)
- **Incremental merge**: post-ship updates (re-scan affected modules only, preserve unchanged sections, update timestamp)
- Module granularity: one section per logical module, package, or top-level directory
