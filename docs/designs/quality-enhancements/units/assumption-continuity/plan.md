# Plan: Assumption Continuity (Unit 2)

## Task Breakdown

### Task 1: Extend assumptions protocol with late discovery lifecycle (R5)

**Files:**
- Edit `core/protocols/assumptions.md`

**Changes:**
1. Add `LATE-FLAGGED` to the Statuses table:
```markdown
| `LATE-FLAGGED` | Discovered after design phase | No |
```

2. Add new section after "Downstream Usage":
```markdown
## Late Discovery Lifecycle

Assumptions can surface after design approval — during planning or building.

### Identification

- **In sw-plan:** While writing specs, if the planner encounters an unverified
  dependency or behavioral assumption not in assumptions.md, append it with status
  `LATE-FLAGGED` and the discovery phase (`planning`).
- **In sw-build (pre-build):** Before starting the first task, scan spec.md and
  context.md for assumptions that may have become stale since planning. Quick pass.
- **In sw-build (post-task):** After each task commit, check: did the tester or
  executor encounter something that contradicts the spec?

### Format

Late assumptions use the same format as design-phase assumptions, with additions:
- **Status**: `LATE-FLAGGED`
- **Discovered**: `{phase}` (planning | building)
- **Trigger**: {what was encountered that surfaced this assumption}

### Presentation

- In sw-plan: present late assumptions at the spec approval checkpoint alongside
  the spec. User resolves: VERIFY, ACCEPT, or DEFER. Does not block by default.
- In sw-build: non-critical assumptions captured in as-built notes `## Late
  Assumptions` section. No pause.

### Criticality Rule

An assumption is critical if and only if it **directly contradicts an existing
acceptance criterion**. This is the sole trigger for pausing the build.

- Critical: pause and present to user with two options:
  (a) accept and continue, (b) invoke `/sw-pivot`
- Non-critical: capture in as-built notes. No pause.

### Gate Interaction

`LATE-FLAGGED` does NOT participate in the design approval gate. The gate checks
only `UNVERIFIED` status. Late assumptions bypass the design gate because they are
discovered after design approval.
```

### Task 2: Add late assumption references to sw-plan and sw-build (R5)

**Files:**
- Edit `core/skills/sw-plan/SKILL.md`
- Edit `core/skills/sw-build/SKILL.md`

**sw-plan change:** Add to the Spec constraint section (after the line about patterns.md):
```
- Follow `protocols/assumptions.md` late discovery lifecycle for assumptions encountered during spec writing.
```

**sw-build change:** Add after the as-built notes constraint:
```
- Follow `protocols/assumptions.md` late discovery lifecycle at build start and after each task commit.
```

### Task 3: Add discovered behaviors section to build-quality protocol (R6)

**Files:**
- Edit `core/protocols/build-quality.md`

**Change:** Add new section after As-Built Notes:
```markdown
## Discovered Behaviors

**Trigger:** After each task, if the tester wrote tests for edge cases not in the
spec, or the executor handled errors not in acceptance criteria, capture an annotation.

**Format:** `- DB-{n}: {behavior description} (discovered in task {id})`

**Cap:** Maximum 10 discovered behaviors per unit.

**Nature:** Informational only. No spec modification. No pivots.

**Downstream consumers:**
- **sw-learn**: Scan discovered behaviors when extracting patterns. If a behavior
  appears across 2+ work units, propose it as a spec template pattern.
- **gate-spec**: Reference discovered behaviors as "additional coverage beyond spec"
  at INFO level. Does not change the PASS/FAIL verdict.
```

### Task 4: Add discovered behaviors references to downstream skills (R6)

**Files:**
- Edit `core/skills/sw-build/SKILL.md`
- Edit `core/skills/sw-learn/SKILL.md`
- Edit `core/skills/gate-spec/SKILL.md`

**sw-build change:** Add after the late assumption reference (from Task 2):
```
- Follow `protocols/build-quality.md` for discovered behaviors capture after each task.
```

**sw-learn change:** Add to the discovery section:
```
- Check as-built notes for discovered behaviors per `protocols/build-quality.md`.
```

**gate-spec change:** Add to the evidence mapping section:
```
- Reference discovered behaviors at INFO level per `protocols/build-quality.md`. Does not alter PASS/WARN/FAIL verdict.
```

## File Change Map

| File | Tasks | Action |
|------|-------|--------|
| `core/protocols/assumptions.md` | T1 | Edit (add ~120 words) |
| `core/skills/sw-plan/SKILL.md` | T2 | Edit (1 line) |
| `core/skills/sw-build/SKILL.md` | T2, T4 | Edit (2 lines) |
| `core/protocols/build-quality.md` | T3 | Edit (add ~80 words) |
| `core/skills/sw-learn/SKILL.md` | T4 | Edit (1 line) |
| `core/skills/gate-spec/SKILL.md` | T4 | Edit (1 line) |
