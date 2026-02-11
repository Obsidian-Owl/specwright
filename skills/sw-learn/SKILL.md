---
name: sw-learn
description: >-
  Captures patterns and learnings from the current work unit. Reviews
  build failures, gate findings, and architecture decisions. Promotes
  user-approved patterns to constitution or patterns file.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# Specwright Learn

## Goal

Extract reusable knowledge from the current work unit. Build failures,
gate findings, and architecture decisions contain valuable patterns.
Surface them, let the user curate, and promote the best ones so future
work benefits.

## Inputs

- `.specwright/state/workflow.json` -- current work unit (should be shipped)
- `.specwright/work/{id}/evidence/` -- gate evidence files
- `.specwright/work/{id}/plan.md` -- architecture decisions
- `.specwright/CONSTITUTION.md` -- existing practices
- `.specwright/learnings/` -- prior work unit learnings (for retrospective)
- Git log for the work unit's commits

## Outputs

- Learnings presented to user in categories
- User-approved patterns promoted to one of:
  - `.specwright/CONSTITUTION.md` (new practice rule)
  - `.specwright/patterns.md` (reusable pattern library)
- `.specwright/learnings/{work-id}.json` -- only written when at least one finding is promoted (not all dismissed)
- `.specwright/learnings/INDEX.md` -- compacted themes index (when compaction runs)
- `.specwright/learnings/themes/` -- theme files (when compaction runs)

## Constraints

**Discovery (HIGH freedom):**
- Scan evidence files, git log, and plan.md for patterns worth remembering.
- Look for: things that broke, things surprisingly hard, things that worked well.

**Presentation (MEDIUM freedom):**
- Group by category (build, security, testing, architecture). Show: what happened, why it matters, proposed rule.
- Use AskUserQuestion for curation: promote to constitution, promote to patterns, or dismiss.
- Maximum 5-7 learnings per session.

**Promotion (LOW freedom):**
- If promoting to constitution: add a new practice with ID (e.g., S6, Q5) and clear wording.
- If promoting to patterns: append to `.specwright/patterns.md` (create if doesn't exist).
- User must approve exact wording before saving.

**Retrospective (MEDIUM freedom):**
- When `.specwright/learnings/` has 2+ prior files, surface recurring patterns across units citing work IDs.
- If directory empty, missing, or <2 files: silently skip.

**Persistence (LOW freedom):**
- Write `.specwright/learnings/{work-id}.json` only when at least one finding is promoted. No file on all-dismissed.
- Schema: `{ workId, timestamp (ISO 8601), findings: [{ category, source, description, proposedRule, disposition }] }`
- Categories: `build | security | testing | architecture | friction`. Sources: `gate-evidence | git-log | plan | insights`. Dispositions: `promoted-constitution | promoted-patterns | dismissed`.

**Enrichment (MEDIUM freedom):**
- Optional phase governed by `protocols/insights.md` for session pattern enrichment.
- Reference the protocol for facets, privacy, staleness, and fallback behavior.
- Silently skip if insights unavailable or stale per protocol rules.

**Compaction (MEDIUM freedom):**
- Runs after persistence when triggers met, governed by `protocols/learning-lifecycle.md`.
- Groups raw learnings into themed summaries with INDEX.md. Reference protocol for thresholds and formats.
- Silently skip if threshold not met per protocol rules.

## Protocol References

- `protocols/context.md` -- anchor doc loading
- `protocols/state.md` -- workflow state reading
- `protocols/insights.md` -- session pattern enrichment
- `protocols/learning-lifecycle.md` -- compaction triggers and lifecycle

## Failure Modes

| Condition | Action |
|-----------|--------|
| No completed work unit | "Nothing to learn from. Complete a build cycle first." |
| No evidence files | Skip evidence scanning, focus on git log and plan |
| User dismisses all learnings | No persistence file written. No archive clutter. |
| Insights unavailable/stale | Silently skip enrichment per `protocols/insights.md` |
| Compaction threshold not met | Silently skip per protocol |
