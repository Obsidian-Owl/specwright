# Design: Quality Enhancements Across All Phases

## Overview

Eight refinements across three themes that strengthen Specwright's quality outcomes
without changing the workflow stages or adding stack-specific assumptions.

**Revision 1** — Addresses critic findings: extracts new behavior to protocols (not
inline in SKILL.md files), simplifies R5 criticality, separates R1 scoring invocation,
notes R9→R2 dependency, and honestly scopes R10.

Note: R7 and R8 (Evidence Traceability theme) were intentionally dropped at the user's
request during design scoping. Numbering preserved for traceability.

## Token Budget Strategy

SKILL.md files already exceed the 800-token target. This design adds ONLY protocol
references (single lines) to skill files. All new behavioral detail goes into
existing or new protocol sections. Net SKILL.md growth: ~1-3 lines per modified skill.

---

## Theme 1: Adversarial Depth

### R1: Convergence-Tracked Critic Iterations

**Problem:** The architect critic gets a single pass during design. Complex designs may
need multiple rounds to surface all flaws and assumptions.

**Solution:** Add an iterative critic loop to sw-design with convergence dimensions:

1. After each critic pass, a **separate architect invocation** (not self-scoring)
   evaluates four dimensions (1-5):
   - **Completeness** — are all requirements addressed?
   - **Coherence** — do the parts fit together without contradictions?
   - **Feasibility** — can this actually be built with the stated approach?
   - **Risk coverage** — are failure modes and edge cases identified?

2. Convergence rule: stop when ALL dimensions score 4+ OR after max 3 iterations
   (whichever comes first). The cap prevents infinite loops.

3. Each iteration focuses ONLY on dimensions scoring below 4. The scoring invocation
   receives the original design + accumulated findings from prior iterations.

4. First iteration is the existing critic pass. Second and third are targeted follow-ups.
   For simple designs, the first pass will score 4+ on all dimensions and the loop
   exits immediately (no added cost).

**Files changed:**
- `core/skills/sw-design/SKILL.md` — Add one line to Critic constraint: "Follow convergence
  loop in `protocols/convergence.md`." (~15 words added)
- `core/agents/specwright-architect.md` — Add convergence dimensions to output format
  when invoked as a scorer (~40 words added)

**New file:**
- `core/protocols/convergence.md` — Convergence loop procedure, dimension definitions,
  scoring rubric, separate-invocation requirement, cap enforcement (~300 words)

**Integration:** The convergence scores travel in `design.md` as a "Design Quality" section,
giving sw-plan visibility into which areas the critic found weakest.

---

### R2: Mutation-Aware Test Quality Gate

**Problem:** gate-tests checks assertion strength, boundary coverage, mock discipline,
error paths, and behavior focus — but doesn't formalize the question "could a trivially
wrong implementation pass these tests?" The tester agent has a "lazy implementation test"
informal self-check, but it's not a gate dimension with structured output.

**Solution:** Add a 6th quality dimension to gate-tests: **mutation resistance**.

The tester agent, when auditing tests, must explicitly attempt to construct 3 classes
of bypassing implementation:
1. **Hardcoded returns** — would a lookup table pass?
2. **Partial implementations** — would implementing half the requirements pass?
3. **Off-by-one / boundary skips** — would an implementation that handles the happy
   path but silently fails on edges pass?

**Verdict criteria per class** (distinct from the existing lazy implementation test,
which is an unstructured self-check):
- PASS: tester identifies specific tests that would catch this class of bypass
- WARN: tester cannot identify catching tests but the gap is in low-risk code
- BLOCK: tester constructs a concrete bypassing implementation and no test catches it

The key difference from the existing lazy implementation test: structured output per
class with specific test references, not a yes/no self-check.

**Files changed:**
- `core/skills/gate-tests/SKILL.md` — Add mutation resistance to the analysis dimensions
  list (~20 words added)
- `core/agents/specwright-tester.md` — Add structured mutation analysis section to the
  audit behavior (~60 words added to "How you work" section)

---

### R3: Universal Post-Build Review with Calibrated Depth

**Problem:** Post-build review only triggers on large units (4+ tasks / 5+ files /
security-tagged). Small units — which are the majority — skip review entirely.

**Solution:** Make post-build review universal, with depth calibrated by unit size.
All detail lives in the protocol:

| Unit size | Review depth | Reviewer scope |
|-----------|-------------|---------------|
| 1-3 tasks AND <5 files | **Light**: spec compliance check only (criteria → impl mapping) | Single pass, BLOCK findings only |
| 4+ tasks OR 5+ files | **Standard**: full review (current behavior) | Full triage: BLOCK → user, WARN → awareness |
| Security-tagged criteria | **Standard** regardless of size | Full triage + security focus |

Iterative loop (max 2 cycles): if reviewer finds BLOCKs, present to user. If user
fixes, reviewer gets ONE re-review pass. No further cycles.

**Files changed:**
- `core/protocols/build-quality.md` — Replace trigger heuristic with universal + depth
  table + iterative loop cap (~80 words net change, replaces existing trigger section)
- `core/skills/sw-build/SKILL.md` — No change needed; build already says "follow
  `protocols/build-quality.md`" for post-build review

---

### R4: Sharpened Adversarial Language in Agent Prompts

**Problem:** Agent prompts are competent but could be more explicitly adversarial.

**Solution:** Targeted additions to the Behavioral Discipline section of three agents.
These are behavioral nudges — their impact cannot be formally verified, but they cost
nothing and may improve adversarial depth at the margins.

**specwright-architect** — Add to behavioral discipline:
> - Detect optimistic framing: when a design says "this should work" or "straightforward integration," treat it as a red flag. Demand evidence or flag as an assumption.
> - Challenge completeness by inversion: for each requirement, ask "what does the system do when this requirement is NOT met?" If the design is silent, flag it.

**specwright-tester** — Add to behavioral discipline:
> - Before finalizing any test suite, explicitly construct a mental model of a "malicious implementation" — one that technically passes all tests but violates the spec's intent. If you can construct one, your tests have a hole. Patch it.

**specwright-reviewer** — Add to behavioral discipline:
> - Check for "letter vs. spirit" compliance: an implementation that technically satisfies acceptance criteria wording but misses the underlying intent is a WARN finding. Cite the spec criterion and explain the gap.
> - Verify error paths aren't swallowed: look for empty catch blocks, generic error returns, and silenced failures. These pass tests but break production.

**Files changed:**
- `core/agents/specwright-architect.md` — ~40 words added to behavioral discipline
- `core/agents/specwright-tester.md` — ~30 words added to behavioral discipline
- `core/agents/specwright-reviewer.md` — ~40 words added to behavioral discipline

---

## Theme 2: Assumption Continuity

### R5: Late Assumption Capture in Plan and Build

**Problem:** Assumptions are surfaced exclusively during sw-design's critic phase. But
new assumptions emerge during planning and building. These go untracked.

**Solution:** Extend the assumption lifecycle to span design → plan → build. All
behavioral detail lives in the protocol extension — SKILL.md files get protocol
references only.

**In sw-plan (via protocol):**
- While writing specs, if the planner encounters an unverified dependency or behavioral
  assumption not in `assumptions.md`, append it with status `LATE-FLAGGED` and the
  discovery phase.
- Present late assumptions to the user at the spec approval checkpoint (alongside the
  spec). User resolves same as design: VERIFY, ACCEPT, or DEFER.
- Late assumptions do NOT block spec approval by default. The user sees them and can
  choose to block.

**In sw-build (via protocol, pre-build + post-task):**
- **Pre-build checkpoint:** Before starting the first task, scan spec.md and context.md
  for assumptions that may have become stale since planning. Quick pass — not a full
  critic cycle.
- **Post-task checkpoint:** After each task commit, check: did the tester or executor
  encounter something that contradicts the spec?
- **Criticality rule (bright-line):** An assumption is critical if it **directly
  contradicts an existing acceptance criterion**. That's the only trigger for pausing.
  Not "affects 2+ criteria" — just "contradicts one."
- Critical: pause and present to user with options: (a) accept and continue, (b) `/sw-pivot`
- Non-critical: capture in as-built notes `## Late Assumptions` section. No pause.

**Files changed:**
- `core/protocols/assumptions.md` — Add `LATE-FLAGGED` status, late discovery lifecycle,
  bright-line criticality rule, post-task timing (~120 words added)
- `core/skills/sw-plan/SKILL.md` — Add one line: "Follow late assumption capture in
  `protocols/assumptions.md`." (~15 words)
- `core/skills/sw-build/SKILL.md` — Add one line: "Follow late assumption capture in
  `protocols/assumptions.md` at build start and after each task commit." (~25 words)

---

### R6: Spec Discovery Annotations During Build

**Problem:** During build, the tester or executor discovers behaviors not covered by
the spec — edge cases, integration quirks, error conditions. These are lost.

**Solution:** Extend as-built notes with a `## Discovered Behaviors` section. Detail
lives in the protocol.

- After each task, if the tester wrote tests for edge cases not in the spec, or the
  executor handled errors not in acceptance criteria, capture a one-line annotation:
  `- DB-{n}: {behavior description} (discovered in task {id})`
- Maximum 10 discovered behaviors per unit.
- Informational only — no spec modification, no pivots.

**Downstream consumers (explicit):**
- `sw-learn` — Scan discovered behaviors when extracting patterns. If a behavior
  appears across 2+ work units, propose it as a spec template pattern.
- `gate-spec` — Reference discovered behaviors as "additional coverage beyond spec"
  at INFO level in the compliance report. (Does not change PASS/FAIL verdict.)

**Files changed:**
- `core/protocols/build-quality.md` — Add Discovered Behaviors section format and
  consumer guidance (~80 words added)
- `core/skills/sw-build/SKILL.md` — Add one line: "Follow discovered behaviors capture
  in `protocols/build-quality.md`." (~15 words)
- `core/skills/sw-learn/SKILL.md` — Add one line to discovery section: "Check as-built
  notes for discovered behaviors per `protocols/build-quality.md`." (~15 words)
- `core/skills/gate-spec/SKILL.md` — Add one line: "Reference discovered behaviors at
  INFO level per `protocols/build-quality.md`." (~15 words)

---

## Theme 3: Feedback Loops

### R9: Verify Escalation Heuristics

**Problem:** When BLOCK findings indicate a design-level problem, verify says "fix and
re-verify." But some problems need a design revision, not an implementation fix.

**Solution:** Add escalation heuristics to the gate-verdict protocol, consumed by
sw-verify's aggregate report.

**Escalation signals** (any 2+ triggers escalation recommendation):
- gate-spec: 3+ criteria have FAIL status (systemic, not isolated)
- gate-wiring: circular dependencies in changed files (structural problem)
- gate-tests: mutation resistance BLOCK on 50%+ of test files (testing approach is wrong)
  — **Note: this signal depends on R2 being implemented. Without R2, this signal is
  absent and the remaining 4 signals still function.**
- gate-security: BLOCK findings in core data flow (not just a missed escape)
- Multiple gates FAIL simultaneously (compound failure)

**Escalation recommendation** (added to aggregate report when triggered):
> Design-level concerns detected. Consider `/sw-pivot` to revise remaining plan, or
> `/sw-design <changes>` if the approach needs rethinking. Fixing individual findings
> may not address the root cause.

Advisory only — the user decides.

**Files changed:**
- `core/protocols/gate-verdict.md` — Add escalation signals section and recommendation
  template (~100 words added)
- `core/skills/sw-verify/SKILL.md` — Add one line to aggregate report constraint:
  "Check escalation heuristics per `protocols/gate-verdict.md`." (~15 words)

---

### R10: Gate Calibration Tracking

**Problem:** Gates have fixed sensitivity with no feedback loop. Over time, false
positives erode trust and false negatives miss bugs.

**Honest scope:** This feature is designed for projects with 5+ work units shipped
through Specwright. For smaller projects (1-4 units), calibration data will be
insufficient and the feature will be silently absent. This is acceptable — the
calibration investment pays off exactly when it's most needed (mature, active projects).

**Solution:** Lightweight gate outcome tracking, entirely in protocols and learnings:

**During sw-learn** (after shipping):
- Record gate outcomes for the shipped unit: per gate, verdict and finding count.
- If the user dismisses a learning as irrelevant → "false positive" signal.
- If the user reports a shipped bug → "false negative" signal.
- Store in learnings json: `gateCalibration: { gateName: { verdict, findingCount,
  falsePositives: [], falseNegatives: [] } }`

**During sw-verify** (consuming calibration):
- Before running gates, scan `.specwright/learnings/` for calibration data (last 5 units).
- 3+ false positive signals for a gate+dimension → note in report: "This dimension has
  been flagged as potentially over-sensitive in recent work units."
- Any false negative signal → note: "This gate missed issues in a recent unit. Consider
  extra scrutiny."
- Purely informational. No automatic threshold changes.

**Files changed:**
- `core/protocols/gate-verdict.md` — Add calibration data format and consumption rules
  (~80 words added)
- `core/skills/sw-learn/SKILL.md` — Add one line: "Record gate calibration data per
  `protocols/gate-verdict.md`." (~15 words)
- `core/skills/sw-verify/SKILL.md` — Add one line: "Load calibration notes per
  `protocols/gate-verdict.md`." (~15 words)

---

## Complete File Impact Summary

### Modified files (14):

| File | Refinements | Net growth |
|------|------------|-----------|
| `core/skills/sw-design/SKILL.md` | R1 | ~15 words |
| `core/skills/sw-plan/SKILL.md` | R5 | ~15 words |
| `core/skills/sw-build/SKILL.md` | R5, R6 | ~35 words |
| `core/skills/sw-verify/SKILL.md` | R9, R10 | ~30 words |
| `core/skills/sw-learn/SKILL.md` | R6, R10 | ~30 words |
| `core/skills/gate-tests/SKILL.md` | R2 | ~20 words |
| `core/skills/gate-spec/SKILL.md` | R6 | ~15 words |
| `core/agents/specwright-architect.md` | R1, R4 | ~80 words |
| `core/agents/specwright-tester.md` | R2, R4 | ~90 words |
| `core/agents/specwright-reviewer.md` | R4 | ~40 words |
| `core/protocols/build-quality.md` | R3, R6 | ~160 words (replaces ~80) |
| `core/protocols/gate-verdict.md` | R9, R10 | ~180 words |
| `core/protocols/assumptions.md` | R5 | ~120 words |
| `DESIGN.md` | All | Update principles/gate descriptions |

### New files (1):

| File | Purpose | Size |
|------|---------|------|
| `core/protocols/convergence.md` | Critic convergence loop (R1) | ~300 words |

### Files NOT changed:

The 6-stage workflow, config.json schema, workflow.json schema, evidence format,
directory structure, hook infrastructure, CI/CD configuration, adapter layer,
CLAUDE.md, AGENTS.md.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Convergence loop stalls design (R1) | Low | Medium | Hard cap at 3 iterations; separate scoring invocation prevents self-bias |
| Mutation analysis adds latency to gate-tests (R2) | Medium | Low | Mental model construction, not actual mutation runs |
| Universal review adds ceremony for small units (R3) | Medium | Low | Light depth = compliance check only, single pass |
| Late assumptions disrupt build flow (R5) | Low | Medium | Post-task timing (not mid-TDD); bright-line criticality |
| Discovered behaviors become noise (R6) | Low | Low | Capped at 10; informational only |
| R9 escalation signals depend on R2 (partial) | Medium | Low | 4/5 signals work without R2; dependency noted |
| R10 cold-start: no value for small projects (R10) | High | Low | Feature is silently absent until data exists; designed for mature projects |

## Alternatives Considered

1. **External mutation testing tools** (R2) — Rejected: stack-specific, violates constraint.
2. **Separate assumption skill** (R5) — Rejected: too much ceremony. Protocol extension is lighter.
3. **Automatic gate sensitivity adjustment** (R10) — Rejected: too risky. Humans decide.
4. **Mandatory critic convergence to 5/5** (R1) — Rejected: diminishing returns.
5. **Inline all behavior in SKILL.md files** — Rejected by critic (BLOCK-1): violates
   progressive disclosure. Protocol extraction preserves token budgets.
6. **Mid-TDD assumption detection** (R5) — Rejected by critic (BLOCK-3): architecturally
   awkward. Post-task timing is cleaner.
