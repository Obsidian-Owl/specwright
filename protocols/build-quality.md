# Build Quality Protocol

Post-build quality steps run after all tasks in a unit are committed,
before the handoff to `/sw-verify`.

## Post-Build Review

**Trigger (heuristic):** Run if the unit has 4+ tasks, OR 5+ files changed,
OR any acceptance criterion is tagged with security concerns. Units that
don't qualify skip directly to handoff.

**Delegation:** `specwright-reviewer` (not architect). Include in prompt:
- spec.md (acceptance criteria)
- List of changed files (from git diff)
- plan.md (architecture decisions)

The reviewer reads files directly. Do NOT pass full diffs in the prompt.

**Findings triage:**
- BLOCK → present to user immediately. User decides: fix now, fix later, or dismiss.
- WARN → list for awareness. No action required.
- INFO → skip (don't surface to user).

## As-Built Notes

**Trigger:** After all tasks committed (and after optional post-build review).

**Location:** Append `## As-Built Notes` section to `{currentWork.workDir}/plan.md`.

**Content scope:**
- Plan deviations: what changed from the original plan and why
- Implementation decisions: choices made during build not covered by plan
- Actual file paths: if different from what plan.md predicted

Only document what differed from plan. Don't restate what went as planned.

**Boundaries:**
- spec.md stays untouched. Spec deviations are gate-spec failures, not as-built notes.
- gate-spec does NOT consume as-built notes. spec.md remains the sole source of truth for verification.
- Primary consumer: sw-learn (captures patterns from build experience).
