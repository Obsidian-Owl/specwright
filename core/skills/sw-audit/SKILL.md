---
name: sw-audit
description: >-
  Periodic codebase health check. Analyzes architecture, complexity,
  consistency, and debt across the full codebase. Produces persistent
  findings in AUDIT.md.
argument-hint: "[path | --full]"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Task
---

# Specwright Audit

## Goal

Find systemic codebase issues that per-change quality gates miss.
Architecture debt, complexity growth, convention drift, and accumulated
workarounds compound silently. Surface them, let the user prioritize,
and persist findings for future design cycles.

## Inputs

- The codebase itself
- `{projectArtifactsRoot}/CONSTITUTION.md` -- practices to check against
- `{projectArtifactsRoot}/AUDIT.md` -- prior findings (if exists, for ID matching)
- `{projectArtifactsRoot}/LANDSCAPE.md` -- module structure (if exists, for triage)
- `{projectArtifactsRoot}/config.json` -- audit config (optional `audit` section)

## Outputs

- `{projectArtifactsRoot}/AUDIT.md` -- findings per `protocols/audit.md` format
- Findings presented to user grouped by dimension before saving

## Constraints

**Scope (LOW freedom):**
- This skill reads and analyzes. It NEVER modifies source code, creates branches, runs builds, or starts work units.
- Does NOT create `currentWork` in workflow.json. Does NOT require a lock. Can run while a work unit is in progress.
- It is not a core workflow stage and never claims top-level work ownership.
- On compaction: re-run from scratch (no state to recover).

**Triage (MEDIUM freedom):**
- Determine audit depth from argument and codebase size:
  - Path argument → **Focused**: analyze specified directory/module only
  - `--full` argument → **Full**: parallel agents, all dimensions
  - No argument → auto-triage: Standard (<50 files) or Full (50+ files)
- If LANDSCAPE.md exists, use module count to inform triage.

**Analysis (HIGH freedom):**
- Four dimensions: architecture, complexity, consistency, debt.
- Delegate per `protocols/delegation.md`:
  - `specwright-architect`: architecture + complexity (structural analysis)
  - `specwright-reviewer`: consistency + debt (convention and quality analysis)
- Standard depth: 2 agent calls (sequential or parallel).
- Full depth: up to 4 parallel calls (one per dimension).
- Include constitution practices as the baseline for consistency checks.

**Synthesis (LOW freedom):**
- Agents return raw findings. The skill itself aggregates results.
- If prior AUDIT.md exists: match findings per `protocols/audit.md` (dimension + location). Reuse matched IDs, assign new IDs for unmatched. Mark unmatched prior findings as stale.
- Purge resolved findings older than 90 days.
- Enforce size cap per protocol. Write AUDIT.md.

**Presentation (MEDIUM freedom):**
- Show findings grouped by dimension. For each: severity, location, description, impact.
- Apply `protocols/decision.md` CURATION for severity and export decisions:
  - Cascading impact → BLOCKER. Auto-export to backlog as BL-{n} with `finding` tag.
  - Isolated impact → WARN. Stays in AUDIT.md only.
  - The finding remains in AUDIT.md regardless; backlog items are for action tracking.
- Maximum 20 findings per run. If more, keep highest-severity.

## Protocol References

- `protocols/audit.md` -- finding format, IDs, matching, lifecycle
- `protocols/delegation.md` -- agent delegation
- `protocols/decision.md` -- autonomous decision framework (CURATION for severity)
- `protocols/context.md` -- config and anchor doc loading
- `protocols/backlog.md` -- backlog item format and write targets

## Failure Modes

| Condition | Action |
|-----------|--------|
| No codebase files found | STOP: "No source files to audit." |
| Agents unavailable | Fall back to inline analysis (less thorough) |
| Prior AUDIT.md parse error | WARN, start fresh (no ID continuity) |
| Compaction during audit | Re-run from scratch |
