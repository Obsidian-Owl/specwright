---
name: sw-verify
description: >-
  Orchestrates quality gates for the current work unit. Runs enabled gates
  in dependency order, produces an aggregate evidence report with gate handoff.
argument-hint: '[--gate=<name>] [--accept-mutant {id} --reason "{prose}"]'
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
  - Task
---

# Specwright Verify

## Goal

Run quality gates against the work unit. Continue through all gates
regardless of failures and present the report at handoff
per `protocols/decision.md`.

## Inputs

- `{worktreeStateRoot}/session.json` -- selected work
- `{repoStateRoot}/work/{selectedWork.id}/workflow.json` -- work state and gate results
- `{projectArtifactsRoot}/config.json` -- gate configuration
- `{workDir}/spec.md` -- for spec compliance gate
- `{workDir}/implementation-rationale.md` -- curated build rationale when present
- `{workArtifactsRoot}/{selectedWork.id}/integration-criteria.md` -- behavioral IC list when present
- Gate skill files in `skills/gate-*/SKILL.md`

## Outputs

- `{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md` -- verify handoff digest
- Evidence files in `{workDir}/evidence/`, one per gate
- `{workDir}/review-packet.md` -- reviewer synthesis from approvals, rationale, proof, and gate outcomes
- Selected work's `workflow.json` updated with gate results; status `verifying`
- Aggregate report presented at gate handoff

## Constraints

**Stage boundary (LOW freedom):**
Follow `protocols/stage-boundary.md`. Run quality gates and show findings. NEVER fix
code, create PRs, or ship. After gate handoff, STOP.

**Ownership check (LOW freedom):**
Resolve the selected work from the current worktree session. If another live
top-level worktree owns that work, STOP with explicit `/sw-adopt` guidance and
do not rely on generic adopt/takeover behavior.

**Assumption re-validation (LOW freedom) — before gate execution:**
Scan the design assumptions artifact from the design-level directory. Check
ACCEPTED/VERIFIED assumptions against current code. Invalid → WARN in the
aggregate report. Runs silently.

**Approval lineage check (LOW freedom) — before gate execution:**
Use `protocols/approvals.md` and the shared helper to validate the recorded
`design` and current `unit-spec` approval hashes. Missing, `STALE`, or
`SUPERSEDED` lineage becomes a distinct approval finding; headless verify may
report it but never create `APPROVED` entries.

**Accepted-mutant lineage and mutation disclosure (LOW freedom):**
When `/sw-verify --accept-mutant {id} --reason "{prose}"` is present, use
`protocols/approvals.md` plus the shared helper to record or refresh the
accepted-mutant approval entry before gate execution. Persist the config linkage
at `config.gates.tests.mutation.acceptedMutants[]`, require a reason, and set
expiry to 90 days from approval unless a later explicit expiry is being
refreshed. Ordinary verify runs validate and report accepted-mutant lineage;
they never fabricate approval state or silently waive survivors. Mutation
analysis stays inside `gate-tests`, not a seventh gate. When `gate-tests` emits
mutation evidence, surface the tier (`T1`, `T2`, or `T3`), any
accepted-mutant approval lineage, and only the restricted survivor record:
operator, location, before/after, defect category, and action. No test bodies
and no assertion literals. Missing-tool or fallback paths may degrade through
`T2`/`T3`, but never to a silent skip.

**Freshness checkpoint (LOW freedom) — before any gate runs:**
Use `protocols/git-freshness.md` to assess the selected work's verify
checkpoint from the recorded target and policy. For branch-head validation,
branch-head `require` blocks stale, diverged, and blocked freshness results.
Queue-managed mode remains a distinct validation path and does not prescribe a
local rebase before verification. When branch-head validation is blocked and
`rebase` or `merge` reconcile is configured, run `protocols/git-reconcile.md`
in the owning worktree and continue gate execution in that same verify run
after a successful reconcile. `manual` remains an explicit fallback: stop with
manual reconcile guidance, reconcile the current branch against the recorded
target in the owning worktree, or run `/sw-adopt` first if a linked-worktree
ownership conflict exists, then rerun `/sw-verify`. Do not redirect to
`/sw-build` solely to clear freshness, and do not silently rewrite `targetRef`
or freshness metadata. In headless mode, follow `protocols/headless.md`: skip freshness blocking, continue gate execution, and report the freshness result with the gate findings.

**Gate execution order (LOW freedom):**
Determine enabled gates from config. Support both formats:
- **Object format**: `config.gates.{gateName}` exists and `.enabled === true`
- **Array format**: gate name present in `config.gates.enabled` array

All six gates are eligible when enabled in config: build, tests, security,
wiring, semantic, spec.
Execute enabled gates in dependency order: gate-build → gate-tests →
gate-security, gate-wiring → gate-semantic → gate-spec.
If `--gate=<name>` argument, run only that gate.
Load calibration notes per `protocols/evidence.md#verdict-rendering`.

**Gate invocation (MEDIUM freedom):**
Gates are internal skills — load SKILL.md and execute inline. Pass work unit context.

**Gate Re-Run Policy (LOW freedom):**
Always re-run all gates regardless of existing results or age.

**Review packet synthesis (LOW freedom) — after gate execution, before
handoff:** Use `protocols/review-packet.md` to assemble
`{workDir}/review-packet.md` from approval lineage, `implementation-rationale.md`,
gate evidence, and the canonical gate-spec compliance matrix. This is
synthesis, not a second gate engine: do not rerun gates, recreate proof logic,
or backfill rationale from transcripts. In `clone-local` work-artifact mode,
keep the packet reviewer-usable without local-only file links.

**Failure handling (MEDIUM freedom):**
Gate FAIL or ERROR: continue. Run remaining gates and record results.
No fix/skip/abort decisions — the handoff presents everything for human review.
Headless: write `headless-result.json`.

**Aggregate report (MEDIUM freedom):**
After all gates, present three tiers. When approval findings exist, prepend an
`Approval Lineage` subsection before tier 1.
1. **Per-finding detail** (first): every BLOCK/WARN grouped by gate with what,
   why, and recommended action.
2. **Summary table** (after): `| Gate | Status | Findings (B/W/I) |`
3. **Actionable Findings** (after summary): only shown when WARN or BLOCK
   findings exist; omit when all gates PASS. Populate from gate evidence and
   include only WARN and BLOCK severity rows, not INFO.

   | # | Gate | Severity | File | Finding | Recommended Fix |
   |---|------|----------|------|---------|-----------------|

   - File column: specific file path from gate evidence, not a vague reference.
   - Recommended Fix column: WARN rows get concrete, actionable fix suggestions;
     BLOCK rows that require human judgment get "manual review".
   - Summary line: state the actionable finding count (`N of M`) and whether any
     require human judgment. Keep it informational — do not imply the skill
     will perform fixes.
   - All-manual case: when every actionable finding requires manual review,
     state that no automated resolution is possible.

SKIP gates prominently marked. Check escalation heuristics per
`protocols/evidence.md#verdict-rendering`. Handoff posture remains three-tiered:
BLOCKs → "Fix and re-run `/sw-verify`." WARN-only results → "Review, then fix or `/sw-ship`." All PASS → "Ready for `/sw-ship`."

**Evidence completeness (LOW freedom):**
Skip when `--gate=<name>` was used. In full mode, check every enabled gate has
a status in the selected work's `workflow.json` `gates.{name}`. No status and
no evidence file → ERROR: "Gate {name} was enabled but produced no evidence —
gate was not executed." A partial run may omit evidence for gates that were not
invoked.

**Deliverable verification (MEDIUM freedom) — inline phase, not a gate:**
Activates on the final work unit of a multi-WU design. Activation conditions:
`workflow.workUnits` has >1 entry, current unit is last in the sequence, all
prior units are `shipped` or `verified`, and all six standard gates completed
with PASS or WARN (not FAIL or ERROR; failed gates skip deliverable verification
because the proof surface is already broken). Runs after the six standard gates.

When activated:
- Load `integration-criteria.md` from the design-level directory
  (`{workArtifactsRoot}/{selectedWork.id}/`). If the file does not exist → SKIP
  with INFO note ("No integration-criteria.md found"). Identify behavioral ICs
  (IC-B{n} entries).
- For each IC-B, search for test evidence: a test file exercising the described
  behavior plus a passing gate-tests or gate-build report confirming the test
  passes. IC-Bs with both test file and passing evidence → PASS. IC-Bs without
  either → BLOCK.
- When no IC-Bs are defined (older plans, single-unit work, structural-only ICs) →
  SKIP with INFO note.
- Run `commands.test:integration` and `commands.test:e2e` from config.json if
  configured. Failing commands → BLOCK. Unconfigured commands → WARN.
- Produce a "## Deliverable Verification" section in the verify evidence report,
  positioned after the standard gate results and labeled as an inline phase,
  not a gate.

Include deliverable verification findings (BLOCKs, WARNs) in the aggregate report
and gate handoff recommendation.

**Gate handoff (LOW freedom):**
On completion, emit the three-line handoff per the `protocols/decision.md`
Gate Handoff section. The one-line outcome reflects the aggregate gate
verdict (e.g., "all gates PASS", "2 WARN, 0 BLOCK", "gate-spec FAIL").
Detail lives in the per-gate evidence files under `{workDir}/evidence/`.
Write `{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`
before the handoff, and point the Artifacts line at
`Artifacts: {repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md`.
The Next: line points to `/sw-build` for ordinary implementation BLOCKs, to
`/sw-verify` after a freshness-only pre-gate stop, or to `/sw-ship` on PASS or
WARN. Example: `Next: /sw-ship`.

**State updates (LOW freedom):**
Follow `protocols/state.md`. Mutate only the selected work's `workflow.json`
and the current worktree session. Set status to `verifying` at start. Update
the selected work's `gates` section after each gate completes. Do NOT set
`shipped`.

## Protocol References

- `protocols/stage-boundary.md` -- stage boundary
- `protocols/decision.md` -- autonomous decision framework and gate handoff
- `protocols/state.md` -- workflow state
- `protocols/git-freshness.md` -- pre-gate freshness checkpoint
- `protocols/git-reconcile.md` -- lifecycle-owned branch reconcile
- `protocols/approvals.md` -- approval lineage validation
- `protocols/review-packet.md` -- packet synthesis
- `protocols/evidence.md` -- evidence storage
- `protocols/evidence.md#verdict-rendering` -- verdict rendering
- `protocols/headless.md` -- headless defaults
- `protocols/context.md` -- config and anchor docs

## Failure Modes

| Condition | Action |
|-----------|--------|
| No active work unit | STOP: "Run /sw-design, /sw-plan, and /sw-build first." |
| Selected work owned by another live top-level worktree | STOP with explicit `/sw-adopt` guidance |
| Verify freshness reconcile under branch-head `require` + `rebase` or `merge` fails | STOP with the reconcile failure and rerun `/sw-verify` after fixing the blocked worktree state. |
| Verify freshness checkpoint is blocked under branch-head `require` + `manual` | STOP with manual reconcile guidance and rerun `/sw-verify`, not `/sw-build`. |
| No gates enabled / all skipped | WARN, proceed to ready-to-ship |
| Gate skill file not found | ERROR for that gate, continue remaining |
| Compaction during verification | Read the selected work's workflow.json, resume from next gate without fresh results |
