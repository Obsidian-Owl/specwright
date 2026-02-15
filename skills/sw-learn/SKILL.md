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
  - Bash
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

**Stage boundary (LOW freedom):**
- Follow `protocols/stage-boundary.md`.
- You capture learnings and promote patterns. You NEVER start new work units, run builds, or create PRs.
- After learnings are captured, STOP and present the handoff:
  - If more work units pending: "Run `/sw-build` to start the next unit."
  - If no more units: "All work units complete. Learnings captured."

**Discovery (HIGH freedom):**
- Scan evidence files, git log, and plan.md for patterns worth remembering.
- Look for: what broke, what was hard, what worked well.

**Presentation (MEDIUM freedom):**
- Group by category (build, security, testing, architecture). Show: what happened, why it matters, proposed rule.
- Use AskUserQuestion for curation: promote to constitution, patterns, or dismiss. Maximum 5-7 learnings.

**Promotion (LOW freedom):**
- Constitution: add practice with ID (e.g., S6, Q5). Patterns: append to `.specwright/patterns.md` (create if missing).
- User approves exact wording before saving.

**Retrospective (MEDIUM freedom):**
- When 2+ prior learning files exist, surface recurring patterns across units.

**Persistence (LOW freedom):**
- Write `.specwright/learnings/{work-id}.json` when any finding is promoted.
- Schema: `{ workId, timestamp, findings: [{ category, source, description, proposedRule, disposition }] }`

**Landscape update (MEDIUM freedom):**
- After persistence, if `.specwright/LANDSCAPE.md` exists: identify affected modules from evidence and plan artifacts, re-scan those modules, merge updates. Show diff, user approves. Update `Snapshot:` timestamp.
- If LANDSCAPE.md doesn't exist: silently skip.

**Audit resolution (MEDIUM freedom):**
- After landscape update, if `.specwright/AUDIT.md` exists: check if work unit's changed files overlap with open finding locations. If finding is addressed, move to `## Resolved` with work unit ID. User approves.
- If AUDIT.md doesn't exist: silently skip.

**Enrichment (MEDIUM freedom):**
- Optional per `protocols/insights.md`. Silently skip if unavailable or stale.

**Compaction (MEDIUM freedom):**
- Per `protocols/learning-lifecycle.md`. Silently skip if threshold not met.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/context.md` -- anchor doc loading
- `protocols/state.md` -- workflow state reading
- `protocols/insights.md` -- session pattern enrichment
- `protocols/learning-lifecycle.md` -- compaction triggers and lifecycle
- `protocols/landscape.md` -- codebase reference document format
- `protocols/audit.md` -- codebase health findings format

## Failure Modes

| Condition | Action |
|-----------|--------|
| No completed work unit | "Nothing to learn from. Complete a build cycle first." |
| No evidence files | Skip evidence scanning, focus on git log and plan |
| User dismisses all learnings | No persistence file written. No archive clutter. |
| Insights unavailable/stale | Silently skip enrichment per `protocols/insights.md` |
| Compaction threshold not met | Silently skip per protocol |
