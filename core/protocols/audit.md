# Audit Protocol

## Format

`.specwright/AUDIT.md` — optional reference document. Never blocks workflow.

Header: `Snapshot:` (ISO 8601), `Scope:` (full | focused: {path}), `Dimensions:` (list), `Findings:` (count, B/W/I).

Sections: Summary, Findings (`[SEVERITY] F{n}: {title}` — Dimension, Location, Description, Impact, Recommendation, Status), Resolved (resolver ID + date).

## Finding IDs

Format: `F{n}`, never reused. On re-run: match by dimension + location. Matched → reuse ID. Unmatched new → next ID. Unmatched existing → `stale`.

## Lifecycle

Open → Stale (unmatched on re-run) → Resolved (`## Resolved`, with work unit ID + date) → Purged (resolved >90 days, removed on re-run).

## Size

Target 1000-2000 words, cap 3000. Overflow: keep highest-severity, truncate INFO.

## Freshness

`Snapshot:` timestamp. Stale after 30 days (configurable: `config.audit.stalenessThresholdDays`). Missing: proceed without.
