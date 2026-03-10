# Spec: Assumption Continuity

## Acceptance Criteria

### R5: Late Assumption Capture in Plan and Build

- [ ] AC-1: `core/protocols/assumptions.md` contains a new status `LATE-FLAGGED` in the Statuses table with meaning "Discovered after design phase" and "Blocks design approval?" = No. The status has a clear lifecycle: LATE-FLAGGED transitions to VERIFIED (with evidence), ACCEPTED (user acknowledges risk), or DEFERRED (backlog item created).

- [ ] AC-2: `core/protocols/assumptions.md` contains a "Late Discovery Lifecycle" section specifying: (a) assumptions are discovered during planning or building (two phases supported), (b) each late assumption records the discovery phase (planning or building) and the trigger (what was encountered), (c) in sw-plan, late assumptions are presented at the spec approval checkpoint alongside the spec, and (d) in sw-build, a pre-build checkpoint scans spec.md and context.md for stale assumptions before the first task, and a post-task checkpoint runs after each task commit.

- [ ] AC-3: `core/protocols/assumptions.md` contains a "Criticality Rule" subsection within the Late Discovery Lifecycle that states the bright-line rule: an assumption is critical if and only if it directly contradicts an existing acceptance criterion. Critical assumptions pause the build and present the user with two options: (a) accept and continue, or (b) invoke `/sw-pivot`. Non-critical assumptions are captured in the as-built notes `## Late Assumptions` section without pausing.

- [ ] AC-4: `core/skills/sw-plan/SKILL.md` contains a protocol reference to `protocols/assumptions.md` for late assumption capture during spec writing. The reference is 1-2 lines. No behavioral detail is inlined.

- [ ] AC-5: `core/skills/sw-build/SKILL.md` contains a protocol reference to `protocols/assumptions.md` specifying both checkpoints: at build start and after each task commit. The reference is 1-2 lines. No behavioral detail is inlined.

- [ ] AC-6: The `LATE-FLAGGED` status does NOT appear in the existing design gate check in `assumptions.md` (the "Gate" row in the Lifecycle section that says "Design cannot be approved while BLOCK-category assumptions remain UNVERIFIED"). Late-flagged assumptions bypass the design gate because they are discovered after design approval.

### R6: Spec Discovery Annotations During Build

- [ ] AC-7: `core/protocols/build-quality.md` contains a new "Discovered Behaviors" section (after the existing As-Built Notes section) that specifies: the annotation format (`- DB-{n}: {behavior description} (discovered in task {id})`), a maximum of 10 discovered behaviors per unit, that behaviors are informational only (no spec modification, no pivots), and the trigger (tester writes tests for edge cases not in the spec, or executor handles errors not in acceptance criteria).

- [ ] AC-8: `core/protocols/build-quality.md` Discovered Behaviors section specifies two downstream consumers: (a) the section states that sw-learn scans discovered behaviors when extracting patterns and proposes spec template patterns when a behavior appears across 2+ work units, and (b) the section states that gate-spec references discovered behaviors as "additional coverage beyond spec" at INFO level without changing the PASS/FAIL verdict.

- [ ] AC-9: `core/skills/sw-build/SKILL.md` contains a protocol reference to `protocols/build-quality.md` for discovered behaviors capture. The reference is 1 line. No behavioral detail is inlined.

- [ ] AC-10: `core/skills/sw-learn/SKILL.md` discovery section contains a reference to check as-built notes for discovered behaviors per `protocols/build-quality.md`. The reference is 1 line.

- [ ] AC-11: `core/skills/gate-spec/SKILL.md` contains a reference to surface discovered behaviors at INFO level per `protocols/build-quality.md`. The reference is 1 line and does not alter the existing PASS/WARN/FAIL verdict logic.

### Boundary Cases

- [ ] AC-12: `core/protocols/assumptions.md` Late Discovery Lifecycle specifies that unresolved `LATE-FLAGGED` assumptions are surfaced again at the next stage boundary (verify handoff) so they do not silently persist. The protocol states the re-surfacing behavior explicitly.

- [ ] AC-13: `core/protocols/build-quality.md` Discovered Behaviors section specifies that when the 10-behavior cap is reached, additional discoveries are silently dropped (not captured). The cap is stated as a hard limit.

### Cross-cutting

- [ ] AC-14: No SKILL.md file modified in this unit grows by more than 35 words net (measured by `wc -w` on added lines). All behavioral detail lives in protocols, not inlined in skill files.
