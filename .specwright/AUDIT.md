# Codebase Audit

Snapshot: 2026-04-20T03:01:19Z
Scope: full (workflow legibility, approval lineage, runtime-state devex, sync discipline)
Dimensions: architecture, complexity, consistency, debt
Findings: 4 open (2B, 2W), 10 stale, 17 resolved

## Summary

Specwright's core quality posture is improving in the right direction. `sw-verify`
now has a strong FAIL/WARN bias, gate evidence stays first-class, and this audit
should not weaken that behavior. The problems I found are mostly on the operator
surface around the gates, not inside the gates themselves.

The main pattern is a split between rich audit artifacts and poor primary
delivery. Specwright now generates useful closeout surfaces (`stage-report.md`,
`review-packet.md`, approval ledgers), but the terminal and session-recovery
paths still optimize for machine-parseable trailers and hidden runtime files.
That leaves the human reading either the tail of a long transcript or a pointer
to `.git/specwright/...`, while the model keeps acting as if the user saw the
same detail it did. Approval freshness has a similar problem: the explanation
exists in deeper artifacts, but not in the default place the user looks.

The other systemic issue is adapter friction. The shared runtime model defaults
to Git-admin roots under `.git`, which collides directly with Claude Code's
protected-path rules. That produces unnecessary permission churn and makes the
runtime state harder to inspect. Finally, `sw-sync` currently overcorrects on
"discipline": it preserves safety well, but it forbids the exact user-confirmed
cleanup path that squash-merge repositories routinely need. The fix direction
should therefore be: keep the strict FAIL defaults and safety protections, but
improve legibility, publication, and operator override surfaces.

## Findings

### [BLOCKER] F34: Machine-first handoff contract hides the real stage closeout

- **Dimension**: architecture
- **Location**: `core/protocols/decision.md:295-324`, `adapters/claude-code/hooks/session-start.mjs:15-79`, `adapters/opencode/plugin.ts:170-226`, `evals/tests/test_grader.py:1598-1666`
- **Description**: Specwright now has a good stage-report contract, but the primary delivery path still optimizes for a three-line machine footer. `decision.md` explicitly says "Terminal output is the pointer, not the report." The Claude and Opencode session-start surfaces then restore only coarse workflow status, spec/plan paths, and gate summaries; they do not rehydrate the latest `stage-report.md` or `review-packet.md`. The grader enforces exact three-line trailers and fails on an extra human-facing line, which means the system has strong regression coverage for machine parseability but weak pressure toward human legibility at the point where the user actually reads the result.
- **Impact**: This affects every pipeline stage. Users are asked to trust transitions, gate outcomes, and next actions from a terse trailer or from hidden runtime artifacts under `.git/specwright`, while the model behaves as if the user saw the full closeout context. That is a workflow trust problem, not just a formatting nit.
- **Recommendation**: Preserve the exact three-line trailer as the machine footer, but add a short human-facing closeout digest immediately before it and have the adapter recovery surfaces lift the latest `stage-report.md` or `review-packet.md` summary automatically. Add eval coverage for the human-facing digest so optimization pressure is not one-sided.
- **Status**: open

### [WARNING] F35: Approval freshness explanations are buried instead of surfaced

- **Dimension**: consistency
- **Location**: `core/protocols/review-packet.md:44-70`, `core/skills/sw-status/SKILL.md:46-54`, `adapters/claude-code/hooks/session-start.mjs:65-77`, `adapters/opencode/plugin.ts:214-224`
- **Description**: Approval lineage can now be explained well in secondary artifacts. For example, current review packets under `.git/specwright/work/.../review-packet.md` show whether `design` or `unit-spec` is `MISSING`, `STALE`, or `APPROVED`, and in some cases include approved/current hashes for the mismatch. But the default session-start and idle summaries do not surface any approval state, even though `sw-status` explicitly says approval freshness should be part of the attached-work view. In practice, users encounter stale approval findings during verify/ship without a quick explanation in the primary session surface.
- **Impact**: The approval system feels arbitrary even when it is behaving correctly. That erodes trust in one of Specwright's core auditability features and increases the chance that users treat stale approval findings as bureaucracy instead of as lineage signals.
- **Recommendation**: Lift a compact approval lineage summary into the default session/status path and into the verify closeout preamble. At minimum: show `design` and current `unit-spec` status plus the reason class (`missing entry`, `artifact hash changed`, `expired accepted-mutant`, `superseded`). Keep the full hashes in deeper artifacts.
- **Status**: open

### [BLOCKER] F36: Default clone-local runtime placement conflicts with Claude Code protected paths

- **Dimension**: architecture
- **Location**: `adapters/shared/specwright-state-paths.mjs:140-153`, `adapters/shared/specwright-state-paths.mjs:254-279`, `core/protocols/context.md:8-17`, `.specwright/research/non-interactive-skills-20260319.md:17-23`
- **Description**: The shared resolver defaults `repoStateRoot`, `worktreeStateRoot`, and `workArtifactsRoot` to Git-admin paths under `git rev-parse --git-common-dir` / `git rev-parse --git-dir`. That is coherent from a worktree-safety perspective, but it is a poor default for Claude Code because Claude protects `.git` writes even in bypass-style modes. The repo's own research brief already documents that `--dangerously-skip-permissions` still excludes `.git` writes. Specwright therefore chooses a default runtime model that maps routine session, continuation, stage-report, and work-artifact writes onto a path family the primary adapter treats as specially protected.
- **Impact**: This is a systemic Claude Code devex failure. Users get extra permission friction for normal Specwright operation, and the most useful runtime artifacts end up in a hidden location that many users will not inspect organically. The architecture is safe, but it externalizes the safety cost onto every session.
- **Recommendation**: Keep the logical root split and worktree-safety invariants, but add an adapter-aware default or migration path for Claude Code that keeps human-facing work artifacts and closeout digests in a project-visible non-protected root. `sw-init` / `sw-guard` should offer that choice up front rather than requiring users to discover `config.git.workArtifacts` after the fact.
- **Status**: open

### [WARNING] F37: `sw-sync` forbids the confirmed cleanup path squash-merge repos need

- **Dimension**: consistency
- **Location**: `core/skills/sw-sync/SKILL.md:62-83`, `core/protocols/git.md:316-325`, `.git/specwright/work/workflow-commands/context.md:77-82`
- **Description**: `sw-sync` correctly uses `[gone]` and `--merged` as stale-branch signals and correctly protects live session and worktree owners. But it hardcodes "Delete with `git branch -d` only. Never use `-D`." That is stricter than the design context it shipped from: the original workflow notes explicitly call out that squash-merged branches often require a user-confirmed `-D` when the remote branch is gone but the local branch is not considered merged. Specwright's own config defaults to `mergeStrategy: squash`, so the skill currently rejects a real workflow that its repository strategy makes normal.
- **Impact**: Users have to drop out of `sw-sync` and do manual Git cleanup for a standard post-squash scenario. The result is discipline that blocks action rather than discipline that guides safe action.
- **Recommendation**: Keep `git branch -d` as the default and preserve the protection-set checks, but add an explicit second confirmation path for `[gone]` branches that are not claimed by any live session or subordinate worktree. The skill should explain why the override is safe and when it still remains forbidden.
- **Status**: open

## Stale

- **F14**: Hook-handler test coverage gap was not revalidated in this workflow-surface audit. Status: `stale`.
- **F19**: `sw-build` procedural leakage remains plausible, but it was not a primary surface in this pass. Status: `stale`.
- **F23**: `sw-build` token-budget finding was not remeasured beyond confirming the file still remains large. Status: `stale`.
- **F24**: `gate-wiring` complexity was not re-audited in detail in this pass. Status: `stale`.
- **F28**: Decision-record validation remains a plausible debt item, but it was not revalidated here. Status: `stale`.
- **F30**: The single-consumer protocol inventory is outdated after later protocol deletions and was not recomputed. Status: `stale`.
- **F11**: The orphaned `.orphaned_at` file was not part of this workflow-surface pass. Status: `stale`.
- **F31**: Lang-building eval coverage was not re-audited here. Status: `stale`.
- **F32**: Workflow-eval seed readiness was not rechecked in this pass. Status: `stale`.
- **F33**: The prior "protocol quality pockets" note referenced protocols that no longer exist and is not a stable current finding. Status: `stale`.

## Resolved

- **F20** (resolved 2026-04-20): `context.md` no longer references the nonexistent `currentWorkUnit` field; session/work resolution now anchors on `session.json.attachedWorkId` and related session fields.
- **F21** (resolved 2026-04-20): `gate-security` now defers CWE-636 and CWE-209 to `gate-semantic`, and `gate-semantic` explicitly claims sole ownership of those categories.
- **F22** (resolved 2026-04-20): `specwright-executor.md` and `specwright-build-fixer.md` now explicitly forbid Git commands.
- **F25** (resolved 2026-04-20): `specwright-reviewer.md` now constrains Bash to verification commands and forbids file mutation via shell.
- **F26** (resolved 2026-04-20): `STRICT` freedom labels were removed from `sw-review` and `sw-sync`; both surfaces now use the standard taxonomy.
- **F27** (resolved 2026-04-20): `sw-plan` no longer carries the sw-design copy-paste failure mode; the current state-update block reflects actual planning behavior.
- **F1** (resolved): Core sw-build platform-specific tools -> platform markers. `audit-remediation/platform-markers`
- **F3** (resolved, partial): Adapter skill divergence -> sw-build override removed, sw-guard remains. `audit-remediation/platform-markers`
- **F5** (resolved): Stale work artifacts -> `sw-status --cleanup` + `sw-learn` clear. `audit-remediation/work-lifecycle`
- **F6** (resolved): Zero Claude Code test coverage -> assertion-heavy test suite + CI. `audit-remediation/claude-code-tests`
- **F9** (resolved): Stale workflow state -> `shipped -> (none)` transition via sw-learn. `audit-remediation/work-lifecycle`
- **F2** (resolved): Undocumented convergence.md -> added to doc indexes before later cleanup. `audit-cleanup`
- **F4** (resolved): Earlier sw-build size ceiling regression addressed in prior cleanup pass. `audit-cleanup`
- **F7** (resolved): Missing opencode adapter docs -> added to DESIGN.md directory structure. `audit-cleanup`
- **F8** (resolved): Config version mismatch -> bumped to 2.0 with version checks. `audit-cleanup`
- **F10** (resolved): Config language list updated to include Python, Shell, and TypeScript.
- **F12/F18** (resolved/superseded): Protocol count tracking consolidated in prior cleanup work.
