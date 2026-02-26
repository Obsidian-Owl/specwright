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
