---
name: sw-research
description: >-
  Deep outward-facing research. Investigates external documentation, APIs,
  industry patterns, and best practices. Produces validated research briefs.
argument-hint: "[topic or question to research]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Task
---

# Specwright Research

## Goal

Produce validated, referenced research briefs as input to the design phase.
Focus is outward — external docs, APIs, SDKs, industry patterns. Output is
facts and evidence, never design opinions. Operates fully autonomously —
briefs are consumed by sw-design (which has its own gate).

## Inputs

- Research topic(s) from argument or conversation context
- `{projectArtifactsRoot}/research/` — existing briefs (for deepening or refresh)
- `{projectArtifactsRoot}/CHARTER.md` — technology vision (for relevance filtering)

## Outputs

- `{projectArtifactsRoot}/research/{topic-id}-{YYYYMMDD}.md` per `protocols/research.md`

## Constraints

**Stage boundary (LOW freedom):**
Reads and researches. NEVER writes code, branches, mutates workflow state,
or produces design artifacts. No `currentWork`, no lock. Can run anytime.

**Triage (MEDIUM freedom):**
- Break request into 1-5 tracks. Derive tracks from the argument + existing gaps.
  Apply `protocols/decision.md` DISAMBIGUATION if topic is ambiguous.
- Assign output shape per track (API contracts, pattern comparison, claim verification,
  domain survey). If no topic provided, infer from recent conversation context.

**Research (HIGH freedom):**
Delegate to `specwright-researcher` per `protocols/delegation.md`. One call per track.
Parallel if Agent Teams available. Cite all sources with URLs. UNFETCHED → noted, not fabricated.

**Synthesis (MEDIUM freedom):**
Merge findings. Score confidence: HIGH (official docs, multiple sources), MEDIUM
(reputable secondary), LOW (single, unverified). Tag LOW/MEDIUM as potential
assumptions. Flag open questions honestly.

**Auto-approval (MEDIUM freedom):**
If all tracks have ≥MEDIUM confidence: auto-approve and persist the brief.
Low-confidence tracks noted in the brief for consumer awareness. Briefs are
consumed by sw-design which validates findings at its own gate.

**Persistence (LOW freedom):**
Write to `{projectArtifactsRoot}/research/{topic-id}-{YYYYMMDD}.md`. Overwrite same topic+date.
Max 10 briefs. If at cap: log warning, list by date, suggest cleanup.
Briefs older than 90 days are STALE — warn when loading.

## Protocol References

- `protocols/decision.md` -- autonomous decision framework (DISAMBIGUATION, auto-approval)
- `protocols/research.md` — brief format, staleness, lifecycle
- `protocols/delegation.md` — agent delegation

## Failure Modes

| Condition | Action |
|-----------|--------|
| No topic | Infer from conversation context. If undetermined, STOP. |
| Researcher returns no findings | Note as "no results" for that track |
| Source cannot be fetched | Mark UNFETCHED; do not fabricate |
| All tracks LOW confidence | Persist with prominent warning. Consumer decides. |
| Research directory at cap | Log warning, list briefs by date |
| Compaction | Re-run from scratch |
