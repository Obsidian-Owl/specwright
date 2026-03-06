---
name: sw-research
description: >-
  Deep outward-facing research. Investigates external documentation, APIs,
  industry patterns, and best practices. Produces validated, referenced
  research briefs for the design phase.
argument-hint: "[topic or question to research]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Task
  - AskUserQuestion
---

# Specwright Research

## Goal

Produce validated, referenced research context optimized as input to the design
phase. Focus is outward — external documentation, APIs, SDKs, industry patterns,
best practices, anti-patterns. The output is facts and evidence, never design
opinions or recommendations.

## Inputs

- Research topic(s) from user (argument or conversation)
- `.specwright/research/` — existing briefs (for deepening or refresh)
- `.specwright/CHARTER.md` — technology vision (optional, for relevance filtering)

## Outputs

- `.specwright/research/{topic-id}-{YYYYMMDD}.md` per `protocols/research.md` format
- Findings presented to user for review before persisting

## Constraints

**Stage boundary (LOW freedom):**
- This skill reads and researches. It NEVER writes code, creates branches,
  mutates workflow state, modifies source files, or produces design artifacts.
- Does NOT create `currentWork` in workflow.json. Does NOT require a lock.
  Can run while a work unit is in progress.
- Does NOT require sw-init. Useful even before project setup.
- On compaction: re-run from scratch (no state to recover).

**Triage (MEDIUM freedom):**
- Break the user's request into 1-5 research tracks. Each track is a focused
  question or area with a clear deliverable.
- Heuristics: single API/SDK → 1-2 tracks. Multi-dependency comparison → 2-3
  tracks. Greenfield domain exploration → 3-5 tracks.
- Assign each track an output shape based on what's being researched:
  - API/SDK docs → structured contracts (endpoints, params, types, errors, auth)
  - Patterns/practices → comparison with trade-offs and anti-patterns
  - Claim verification → evidence mapping (CONFIRMED / REFUTED / MIXED)
  - Domain survey → structured overview with depth pointers
- Present planned tracks to user via AskUserQuestion. Confirm before executing.

**Research (HIGH freedom):**
- Delegate to `specwright-researcher` per `protocols/delegation.md`.
  One agent call per track with a detailed prompt specifying the output shape.
- Default: sequential execution. If Agent Teams available, run tracks in parallel.
- Each delegation prompt must include: the specific question, the expected output
  format, and the instruction to cite all sources with URLs and version/date.
- If a source cannot be fetched, note it as UNFETCHED — do not fabricate content.

**Synthesis (MEDIUM freedom):**
- Merge findings across tracks. Identify where sources agree, disagree, or
  qualify each other.
- Score confidence per finding: HIGH (official docs, multiple corroborating
  sources), MEDIUM (reputable secondary source), LOW (single source, unverified).
- Tag LOW/MEDIUM confidence findings as "potential assumptions" for downstream
  design to pick up.
- Flag open questions honestly — what couldn't be verified.

**Presentation (MEDIUM freedom):**
- Show synthesized brief to user. Highlight conflicts, open questions, and
  low-confidence findings.
- User may: approve, request deepening on specific areas, or dismiss findings.
- Deepening: read the existing brief, add new tracks, re-execute, and
  re-synthesize all findings (old + new) into a single updated brief.

**Persistence (LOW freedom):**
- Write approved brief to `.specwright/research/{topic-id}-{YYYYMMDD}.md`
  per `protocols/research.md` format.
- If brief with same topic-id and date exists, overwrite (intentional refresh).
- Maximum 10 briefs in the research directory. If at cap, warn user and suggest
  removing stale briefs.

**Lifecycle (LOW freedom):**
- Briefs older than 90 days are STALE. The skill warns when loading stale briefs.
- No automatic purging — user decides.

## Protocol References

- `protocols/research.md` — brief format, staleness, lifecycle
- `protocols/delegation.md` — agent delegation
- `protocols/context.md` — anchor doc loading (skip if `.specwright/config.json` does not exist)

## Failure Modes

| Condition | Action |
|-----------|--------|
| No topic provided | Ask via AskUserQuestion before researching |
| Researcher agent returns no findings | Note as "no results found" for that track; suggest alternative search terms |
| Source cannot be fetched | Mark as UNFETCHED in brief; do not fabricate |
| All tracks return low confidence | Present honestly; suggest the user provide specific doc URLs |
| Research directory at cap (10 briefs) | Warn user; list briefs by date; suggest cleanup |
| Compaction during research | Re-run from scratch |
