# Spec: Adversarial Depth

## Acceptance Criteria

### R1: Convergence-Tracked Critic Iterations

- [ ] AC-1: A new file `core/protocols/convergence.md` exists containing: four named convergence dimensions (Completeness, Coherence, Feasibility, Risk Coverage), a 1-5 scoring rubric per dimension, a convergence rule (stop when all dimensions score 4+ OR after max 3 iterations), a requirement that scoring uses a separate architect invocation (not self-scoring), guidance that each follow-up iteration focuses only on dimensions scoring below 4, and exit behavior when the cap is reached without convergence (loop exits, accumulated findings are preserved, design proceeds with the scores as-is).

- [ ] AC-2: `core/skills/sw-design/SKILL.md` Critic constraint section contains a reference to `protocols/convergence.md` for the critic loop. The addition is 1-2 lines (protocol reference, not inline behavior). The skill file does NOT inline the convergence procedure.

- [ ] AC-3: `core/agents/specwright-architect.md` output format section includes a convergence scoring block with four dimensions (1-5 each), introduced by a condition statement indicating it is present only when the architect is invoked as a convergence scorer (e.g., "When invoked for convergence scoring, also include:").

### R2: Mutation-Aware Test Quality Gate

- [ ] AC-4: `core/skills/gate-tests/SKILL.md` analysis dimensions list includes a 6th dimension named "Mutation resistance" alongside the existing 5 dimensions (assertion strength, boundary coverage, mock discipline, error paths, behavior focus). The dimension description specifies the three bypass classes: hardcoded returns, partial implementations, and off-by-one/boundary skips.

- [ ] AC-5: `core/agents/specwright-tester.md` contains a structured mutation analysis section (after the existing "lazy implementation test" section) that defines: the three bypass classes with descriptions, verdict criteria per class (PASS = specific catching tests identified with file:line, WARN = gap in low-risk code, BLOCK = concrete bypass constructed with no catching test), and a rollup rule specifying that the overall mutation resistance verdict is the worst of the three per-class verdicts.

- [ ] AC-6: The structured mutation analysis in the tester agent is distinct from the existing "lazy implementation test" section. The lazy implementation test remains unchanged. The new section has a separate heading and explicitly notes that its structured per-class output format is what differentiates it from the informal self-check.

### R3: Universal Post-Build Review with Calibrated Depth

- [ ] AC-7: `core/protocols/build-quality.md` Post-Build Review section no longer contains the text "4+ tasks, OR 5+ files changed, OR security-tagged criteria" as a trigger heuristic. Instead it contains: a universal trigger (all units receive review), a depth calibration table with three rows (Light: 1-3 tasks AND <5 files; Standard: 4+ tasks OR 5+ files; Standard: security-tagged criteria regardless of size), and an iterative loop cap (max 2 review cycles: if BLOCKs found and user fixes, one re-review pass, no further cycles).

- [ ] AC-8: `core/skills/sw-build/SKILL.md` post-build review constraint (the paragraph beginning with "After all tasks committed, if unit qualifies") no longer contains the inline trigger heuristic "4+ tasks OR 5+ files OR security-tagged criteria" or the phrase "Units that don't qualify skip directly to handoff." Instead it delegates all trigger and depth logic to `protocols/build-quality.md`.

### R4: Sharpened Adversarial Language

- [ ] AC-9: `core/agents/specwright-architect.md` behavioral discipline section contains two new items: (1) optimistic framing detection — treat phrases like "should work" or "straightforward integration" as red flags requiring evidence or assumption flagging, and (2) completeness by inversion — for each requirement, ask what happens when it is NOT met, flag if the design is silent.

- [ ] AC-10: `core/agents/specwright-tester.md` behavioral discipline section contains a new item: before finalizing a test suite, construct a mental model of a malicious implementation that technically passes all tests but violates spec intent; if one can be constructed, the tests have a hole that must be patched.

- [ ] AC-11: `core/agents/specwright-reviewer.md` behavioral discipline section contains two new items: (1) letter-vs-spirit compliance — flag implementations that technically satisfy criteria wording but miss underlying intent as WARN findings with spec criterion citation, and (2) error path swallowing — check for empty catch blocks, generic error returns, and silenced failures.

### Cross-cutting

- [ ] AC-12: `DESIGN.md` Internal Gate Skills table `gate-tests` row includes "mutation resistance" in the Checks column alongside existing dimensions.

- [ ] AC-13: No SKILL.md file modified in this unit grows by more than approximately 30 words net (measured by `wc -w` on added lines). All behavioral detail lives in protocols or agent prompts, not inlined in skill files.
