---
name: gate-wiring
description: >-
  Detects unused exports, orphaned files, architecture layer violations,
  and circular dependencies across changed files. Delegates to architect
  agent for structural analysis. Internal gate — invoked by verify.
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Write
  - Task
---

# Gate: Wiring

## Goal

Ensure the codebase is properly connected — no dead code, no orphaned
files, no architecture violations. Code that compiles and passes tests
can still be wired incorrectly.

## Inputs

- `.specwright/config.json` -- architecture layers, project structure
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- selected work unit
- Changed files (via `git diff`)

## Outputs

- Evidence file at `{workDir}/evidence/wiring-report.md`
- Gate status in the selected work's `workflow.json`
- Findings with specific file:line references and remediation

## Constraints

**Scope (MEDIUM freedom):**
- Focus on changed files and their immediate dependents.
- Use `git diff --name-only` against main branch.

**Analysis (HIGH freedom):**
- Delegate to `specwright-architect` for structural analysis.
- The architect checks:
  - **Unused exports**: Public functions/types exported but never imported.
  - **Orphaned files**: Files not imported by anything in the dependency graph.
  - **Layer violations**: Imports crossing architecture layer boundaries (e.g., UI importing directly from database layer). Layers from `config.json` `architecture.layers`.
  - **Circular dependencies**: Import cycles that may cause runtime issues.
- Use real tooling when available (e.g., `madge`, `knip`, `ts-prune`).
- Fall back to LLM analysis when tools aren't configured.

**Verdict (LOW freedom):**
- Follow `protocols/evidence.md#verdict-rendering`.
- WARN severity for most findings (wiring issues rarely block functionality).
- BLOCK only for circular dependencies in changed files.
- This gate is advisory — it helps clean up, not block shipping.

**Cross-unit integration (MEDIUM freedom, multi-unit only):**

When verifying the final unit of a multi-unit design, run additional cross-unit
wiring checks against the full feature diff. This catches integration issues
invisible to per-unit analysis: missing cross-unit imports, interface mismatches,
disconnected entry points.

*Activation predicate* — all four conditions must be true:
1. `workUnits` array exists in the selected work's workflow.json (multi-unit work)
2. `selectedWork.baselineCommit` is non-null
3. `git cat-file -t {baselineCommit}` exits 0 (commit is reachable)
4. All `workUnits` entries except the current `unitId` have status `shipped` or
   `abandoned`, AND at least one non-current unit has status `shipped` (if all
   non-current units are `abandoned`, skip with WARN "All prior units abandoned —
   cross-unit integration check skipped")

If condition 1 is false: skip cross-unit check entirely (single-unit — not applicable,
no WARN, no output). If condition 2 is false: skip with WARN "No baseline commit
recorded — cross-unit integration check skipped." If condition 3 is false: skip with
WARN "Baseline commit {sha} unreachable — cross-unit integration check skipped." If
condition 4 is false: skip entirely (not the final unit — no WARN, no output).

*Branch freshness pre-check* — before computing the diff:
Run `git merge-base --is-ancestor origin/{config.git.baseBranch} HEAD` (default
`origin/main`). If non-zero exit: WARN "Feature branch is behind {baseBranch} —
cross-unit diff may be incomplete. Consider rebasing." Continue the check.

*Full-feature diff:*
Compute the merge base to scope the diff to feature-only changes:
```
MERGE_BASE=$(git merge-base {baselineCommit} HEAD)
git diff $MERGE_BASE HEAD --name-only
```
Using the merge base (not `baselineCommit` directly) ensures that after a rebase onto
a newer main, the diff includes only files changed on the feature branch — not unrelated
files merged to main since design start. If the diff returns empty: WARN "Full-feature
diff returned no changed files — cross-unit integration check skipped" and exit without
delegating. Filter the file list to only files that exist on HEAD (remove deleted files).

*Architect delegation for cross-unit analysis:*
Delegate to `specwright-architect` with: (a) the full-feature file list (HEAD-existing
only), (b) the design.md (architect extracts integration-relevant content), (c)
`integration-criteria.md` from the design-level directory if present. Instruct the
architect to check:
- **Cross-unit imports**: For each unit's exports described in the design, verify
  importing code exists in consuming units.
- **Interface compatibility**: Type/interface definitions exported by early units match
  what later units import.
- **Entry point wiring**: The feature's entry point imports and connects all constituent
  pieces.
- **Dead feature exports**: Exports added across all units that no code in the codebase
  imports.
- **Integration criteria**: Verify each IC structurally (grep/glob/type-check, not
  semantic analysis).

*Severity calibration:*
Cross-unit structural findings (missing cross-unit import, interface mismatch,
disconnected entry point) are BLOCK severity. Dead feature exports are WARN severity.
This overrides the per-unit default of WARN. Cross-unit wiring failures represent a
non-functional feature, not an advisory cleanup suggestion.

*Unit attribution:*
Each cross-unit finding must identify which units are involved (e.g., "Interface mismatch
between unit-1 export `PaymentRequest` in `src/types.ts:15` and unit-3 import in
`src/checkout.ts:8`").

*Integration criteria handling:*
If `integration-criteria.md` is absent: WARN "Integration criteria file not found — IC
checks skipped" and continue with structural checks. If the file exists but contains
zero IC entries (no lines matching `- [ ] IC-`): WARN "Integration criteria file contains
no criteria — IC checks skipped" and continue. If an IC cannot be structurally verified
(grep/glob returns no evidence): WARN "IC-{n} could not be structurally verified" — NOT
false PASS.

*Evidence output:*
When cross-unit mode activates, append a `## Cross-Unit Integration` section to
`wiring-report.md` after the per-unit findings. When cross-unit mode is inactive, this
section does NOT appear.

*Hard constraint — no worktree commands:*
This gate MUST NOT use `git worktree` commands, worktree creation, or worktree deletion.
The full-feature diff approach uses only `git diff` and `git cat-file` against the
existing working tree.

## Protocol References

- `protocols/evidence.md#verdict-rendering` -- verdict rendering
- `protocols/evidence.md` -- evidence storage
- `protocols/state.md` -- gate status updates
- `protocols/delegation.md` -- architect agent delegation

## Failure Modes

| Condition | Action |
|-----------|--------|
| No changed files detected | Analyze all project source files |
| No architecture layers configured | Skip layer violation check |
| Wiring tool not installed | Fall back to LLM-based analysis |
| Too many files to analyze | Focus on changed files only, note incomplete scope |
| Single-unit work (no workUnits) | Skip cross-unit check entirely |
| baselineCommit null or unreachable | Skip cross-unit check, WARN |
| Not the final unit | Skip cross-unit check (no WARN) |
| Feature branch behind baseBranch | WARN, continue with potentially incomplete scope |
| Full-feature diff returns empty | WARN, skip cross-unit delegation |
| integration-criteria.md missing | WARN, continue structural checks without ICs |
| IC file exists but has no entries | WARN, continue structural checks without ICs |
| IC not structurally verifiable | WARN per IC (not false PASS) |
| Cross-unit import missing | BLOCK with unit attribution |
| Interface mismatch across units | BLOCK with unit attribution |
| Architect delegation fails (error/timeout) | ERROR for cross-unit section. Cross-unit analysis is not optional once activated. |
| Architect returns no findings | PASS — clean integration confirmed |
| All non-current units abandoned (none shipped) | WARN, skip cross-unit check |
