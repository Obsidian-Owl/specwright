# Autonomous Decision Protocol

How skills make decisions without human intervention between gates. Skills consult
this protocol at decision points — it is reference material, not loaded at start.

## Reversibility Classification

Classify every decision by **structural rules first, agent judgment second**.

### Structural Overrides (always Type 1)

These are Type 1 regardless of the agent's assessment:
- Changes to files matching `**/types.*`, `**/schema.*`, `**/model.*`, `**/interface.*`, `**/api.*`
- Changes to files outside the current task's plan.md file-change-map
- Assumptions that contradict an existing acceptance criterion
- Destructive filesystem operations (`rm -rf`, file deletion)
- External-facing actions (PR comment replies to non-self reviewers)
- Plan mismatches (spec says X, codebase has Y)

### Agent Classification

| Type | Criteria | Action |
|------|----------|--------|
| **Type 2** (reversible) | Undoable by a later commit, PR, or config change | Decide with available information. Bias to action. |
| **Type 1** (irreversible) | Requires significant rework, causes data loss, or impacts users | Analyze carefully. CCR if high-consequence. Document thoroughly. |

Agent-classified Type 1 decisions are highlighted in the gate handoff.

## Decision Heuristics

### APPROVAL
Artifacts auto-progress when quality checks pass (convergence ≥4/5, spec-review
no BLOCKs, TDD + post-build review no BLOCKs). On quality failure: auto-revise
(up to 2 iterations). If the deficiency involves a Type 1 decision (structural
override or agent-classified), halt and surface at the gate — do not proceed.
For Type 2 deficiencies: document and proceed. At the gate: human sees artifact +
quality results + deficiencies.

### DISAMBIGUATION
Apply in order until resolved:
1. Constitution or TESTING.md prescribes an answer → follow it
2. Existing pattern in patterns.md covers this case → follow it
3. One option is more reversible → choose it
4. One option is simpler (Principle of Least Surprise) → choose it
5. Still tied → choose closest to existing codebase conventions

### ERROR_HANDLING
SRE-informed recovery:
1. Mitigate first (restore working state), root-cause second
2. Test fixes in decreasing likelihood order
3. After 2 attempts: document failure, proceed to next task
4. **Exception**: cascading failure (later tasks depend on this one) → halt

### CURATION
Objective promotion criteria:
- Candidate for patterns.md: recurs across 2+ units OR known failure category
- Candidate for TESTING.md: boundary classification or test infra discovery
- Never auto-promote to constitution or auto-memory (Type 1 — irreversible)
- Lightweight gate: show proposed changes before writing

### CONFIRMATION
Destructive actions always require human confirmation. No exceptions.

## Cross-Context Review (CCR)

For Type 1 decisions with systemic blast radius:
- **Reviewer receives**: ONLY the artifact. NOT the reasoning or summary.
- **Reviewer mandate**: "Assume this shipped and caused an incident 6 months later.
  What was the root cause?" (narrow, artifact-specific — distinct from convergence
  pre-mortem which covers systemic/architectural failure)
- **Integration**: findings tagged `[CCR]` in decisions.md. BLOCK → reverse decision.
- **Skip when**: Type 2, already covered by convergence critic, speed > thoroughness.

## Decision Record

Every autonomous decision is recorded in `{workDir}/decisions.md`:

```
## D-{n}: {description}
- **Type**: 1 | 2
- **Category**: APPROVAL | DISAMBIGUATION | ERROR_HANDLING | CURATION | CONFIRMATION
- **Rule applied**: {which heuristic resolved it}
- **Choice**: {what was decided}
- **Alternatives**: {rejected options and why}
- **Timestamp**: {ISO-8601}
- **Reversible by**: {undo path}
```

CCR-reviewed decisions add: `**CCR verdict**: PASS | BLOCK` and `**CCR findings**`.

## Gate Handoff Template

```
## Gate: {skill} → {next skill}

### Artifact
{link to design.md, spec.md, branch diff, or aggregate report}

### Decision Digest
{N} decisions: {X Type 1, Y Type 2} | {categories breakdown}
**Attention**: {agent-classified Type 1, CCR-reviewed, deficiencies only}
Full log: decisions.md

### Quality Checks
{convergence/spec-review/gate results}

### Deficiencies
{unresolved Type 1 assumptions, persistent BLOCKs, unfixed errors}

### Recommendation
{"Approve" | "Review D-{n}" | "Redesign — see deficiencies"}
```

## Precedence

In headless/CI mode: `protocols/headless.md` takes precedence. This protocol governs
interactive autonomous behavior. Different contexts, different risk profiles.
