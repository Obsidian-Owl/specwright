# Build Quality Protocol

Post-build quality steps run after all tasks in a unit are committed,
before the handoff to `/sw-verify`.

## Post-Build Review

**Trigger:** All units receive post-build review. No units skip.

**Depth calibration:**

| Unit size | Depth | Reviewer scope |
|-----------|-------|---------------|
| 1-3 tasks AND <5 files | Light | Spec compliance check only. Single pass. BLOCK findings only. |
| 4+ tasks OR 5+ files | Standard | Full review. BLOCK → user, WARN → awareness. |
| Security-tagged criteria | Standard | Full review + security focus. Regardless of size. |

**Delegation:** `specwright-reviewer` (not architect). Include in prompt:
- spec.md (acceptance criteria)
- List of changed files (from git diff)
- plan.md (architecture decisions)
- Depth level (Light or Standard) so the reviewer knows its scope

The reviewer reads files directly. Do NOT pass full diffs in the prompt.

**Findings triage (Standard depth):**
- BLOCK → present to user immediately. User decides: fix now, fix later, or dismiss.
- WARN → list for awareness. No action required.
- INFO → skip (don't surface to user).

**Findings triage (Light depth):**
- BLOCK → present to user immediately.
- WARN and INFO → skip (not surfaced at Light depth).

**Iterative loop (max 2 cycles):** If the reviewer finds BLOCK findings, present to
user. If user fixes, the reviewer gets ONE re-review pass. No further review cycles
after that — proceed to handoff regardless.

## Build-Time Mutation Signal

Build-time mutation signal is advisory only when mutation analysis runs during
RED-to-GREEN.

- build-time mutation findings do not carry verify-time verdict weight
- tool-backed mutation errors cannot block RED-to-GREEN completion
- survivors, low mutation scores, and tool-backed mutation errors must be
  recorded as build-time notes or as-built notes
- `/sw-verify` reruns the authoritative, verdict-bearing mutation pass later

## As-Built Notes

**Trigger:** After all tasks committed (and after post-build review).

**Location:** Append `## As-Built Notes` section to `{currentWork.workDir}/plan.md`.

**Content scope:**
- Plan deviations: what changed from the original plan and why
- Implementation decisions: choices made during build not covered by plan
- Actual file paths: if different from what plan.md predicted
- Build-time mutation notes when mutation analysis ran during the task loop
  (survivors, advisory thresholds, or tool errors)

Only document what differed from plan. Don't restate what went as planned.

**Boundaries:**
- spec.md stays untouched. Spec deviations are gate-spec failures, not as-built notes.
- gate-spec does NOT consume as-built notes. spec.md remains the sole source of truth for verification.
- Primary consumer: sw-learn (captures patterns from build experience).

## Discovered Behaviors

**Trigger:** After each task, if the tester wrote tests for edge cases not in the
spec, or the executor handled errors not in acceptance criteria, capture an annotation.

**Format:** `- DB-{n}: {behavior description} (discovered in task {id})`

**Location:** Append a `## Discovered Behaviors` subsection to `{currentWork.workDir}/plan.md`
(alongside As-Built Notes).

**Cap:** Maximum 10 discovered behaviors per unit. When the cap is reached, additional
discoveries are silently dropped. This is a hard limit.

**Nature:** Informational only. No spec modification. No pivots.

**Downstream consumers:**
- **sw-learn**: Scan discovered behaviors when extracting patterns. If a behavior
  appears across 2+ work units, propose it as a spec template pattern.
- **gate-spec**: Reference discovered behaviors as "additional coverage beyond spec"
  at INFO level. Does not change the PASS/FAIL verdict.
