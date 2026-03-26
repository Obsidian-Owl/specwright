---
name: sw-learn
description: >-
  Captures patterns and learnings from the current work unit. Reviews
  build failures, gate findings, and architecture decisions. Applies
  objective promotion criteria autonomously — patterns.md is the artifact.
argument-hint: ""
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Specwright Learn

## Goal

Extract reusable knowledge from the current work unit. Build failures,
gate findings, and architecture decisions contain valuable patterns.
Surface them, let the user curate, and promote the best ones so future
work benefits.

## Inputs

- `.specwright/state/workflow.json` -- current work unit (should be shipped)
- `{currentWork.workDir}/evidence/` -- gate evidence files
- `{currentWork.workDir}/plan.md` -- architecture decisions
- `.specwright/CONSTITUTION.md` -- existing practices
- `.specwright/learnings/` -- prior work unit learnings (for retrospective)
- Git log for the work unit's commits

## Outputs

- Learnings presented to user in categories
- User-approved patterns promoted to one of:
  - `.specwright/CONSTITUTION.md` (new practice rule)
  - Auto-memory MEMORY.md (compact pattern entry, loaded every session)
  - `.specwright/patterns.md` (reusable pattern library)
- `.specwright/learnings/{work-id}.json` -- written when any finding is promoted OR when gateCalibration data is available. When only calibration is present (no promoted findings), write with an empty `findings` array.

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
- Check as-built notes for discovered behaviors per `protocols/build-quality.md`.
- If `commands.test:integration` is configured in config.json: check gate-build evidence
  for the integration tier. If it was SKIP or absent, surface as a learning candidate
  ("No integration tests ran"). Skip this check when no integration tier is configured.
- MUST record gateCalibration for every gate that ran, even if all PASS with 0 findings. Populate from evidence files automatically. falsePositives array only populated when user explicitly labels a finding as false positive during presentation (dismissal alone does not count). Format per `protocols/gate-verdict.md`.

**Curation (MEDIUM freedom):**
- Apply `protocols/decision.md` CURATION criteria autonomously:
  - Candidate for patterns.md: recurs across 2+ units OR known failure category
  - Candidate for TESTING.md: boundary classification or test infra discovery
  - Never auto-promote to constitution or auto-memory (Type 1 — irreversible)
  - Track for later: write a BL-{n} item with `pattern` tag per `protocols/backlog.md`
  - Dismiss: project-specific, non-recurring, low-severity
- Maximum 5-7 learnings. Group by category.
- Auto-promote candidates that meet criteria. Record each promotion decision in
  decisions.md. The human reviews promoted patterns when sw-design loads patterns.md.

**Promotion (LOW freedom):**
- Constitution: add practice with ID (e.g., S6, Q5).
- Auto-memory: write compact entry to MEMORY.md per `protocols/learning-lifecycle.md`.
- Patterns: append to `.specwright/patterns.md` (create if missing). Also write a compact one-liner to auto-memory (dual-write rule per protocol).
- Testing strategy: update `.specwright/TESTING.md` (if it exists). The `testing` category maps here. Add new boundary classifications, mock allowances, or test infrastructure notes discovered during build. If TESTING.md does not exist, fall back to patterns.md.
- User approves exact wording before saving.

**Retrospective (MEDIUM freedom):**
- When 2+ prior learning files exist, surface recurring patterns across units.

**Persistence (LOW freedom):**
- Write `.specwright/learnings/{work-id}.json` when any finding is promoted OR when gateCalibration data is available (mandatory per `protocols/gate-verdict.md`). When only calibration is present, write with an empty `findings` array.
- Schema: `{ workId, timestamp, findings: [{ category, source, description, proposedRule, disposition }] }`

**Landscape update (MEDIUM freedom):**
- After persistence, if `.specwright/LANDSCAPE.md` exists: identify affected modules from evidence and plan artifacts, re-scan those modules, merge updates. Show diff, user approves. Update `Snapshot:` timestamp.
- If LANDSCAPE.md doesn't exist: silently skip.

**Audit resolution (MEDIUM freedom):**
- After landscape update, if `.specwright/AUDIT.md` exists: check if work unit's changed files overlap with open finding locations. If finding is addressed, move to `## Resolved` with work unit ID. User approves.
- If AUDIT.md doesn't exist: silently skip.

**Enrichment (MEDIUM freedom):**
- Optional per `protocols/insights.md`. Silently skip if unavailable or stale.

**Auto-memory (MEDIUM freedom):**
- Per `protocols/learning-lifecycle.md`. If auto-memory directory doesn't exist or system prompt doesn't mention auto-memory, silently fall back to patterns.md only.

**State cleanup (LOW freedom):**
- Before clearing, verify `currentWork.status` is `shipped`. If it is anything else (e.g. `building`, `verifying`), STOP with: "State cleanup requires status 'shipped'. Current status: {status}. Complete the current build cycle before running /sw-learn."
- After ALL persistence steps complete successfully (learnings JSON write, LANDSCAPE.md update, AUDIT.md resolution), clear the workflow state:
  - Acquire lock per `protocols/state.md` (set `lock: {skill: "sw-learn", since: "<ISO>"}`) before other mutations.
  - Follow `protocols/state.md` read-modify-write sequence.
  - Set `currentWork` to `null`.
  - Set `gates` to `{}`.
  - Preserve the `workUnits` array (historical reference for future retrospectives).
  - Release lock.
- If ANY persistence step fails (learnings write, landscape update, audit resolution): STOP with error. Do NOT clear `currentWork`. The user must fix the failure and re-run `/sw-learn`.
- This is the `shipped → (none)` transition defined in `protocols/state.md`.

## Protocol References

- `protocols/stage-boundary.md` -- scope, termination, and handoff
- `protocols/decision.md` -- autonomous decision framework (CURATION heuristics)
- `protocols/context.md` -- anchor doc loading
- `protocols/state.md` -- workflow state reading and cleanup transition
- `protocols/insights.md` -- session pattern enrichment
- `protocols/learning-lifecycle.md` -- promotion targets and auto-memory format
- `protocols/landscape.md` -- codebase reference document format
- `protocols/audit.md` -- codebase health findings format
- `protocols/backlog.md` -- backlog item format and write targets
- `protocols/build-quality.md` -- as-built notes and discovered behaviors
- `protocols/gate-verdict.md` -- gate calibration data recording

## Failure Modes

| Condition | Action |
|-----------|--------|
| No completed work unit | "Nothing to learn from. Complete a build cycle first." |
| No evidence files | Skip evidence scanning, focus on git log and plan |
| User dismisses all learnings | Calibration data still written (mandatory). Findings array empty. |
| Insights unavailable/stale | Silently skip enrichment per `protocols/insights.md` |
| Auto-memory unavailable | Silently fall back to patterns.md only |
