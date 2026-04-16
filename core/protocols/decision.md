# Autonomous Decision Protocol

How skills make unattended decisions between gates. This protocol also owns the design critic convergence loop and the assumption lifecycle.

> **"Autonomous" means foreground decision-making within a single turn.** Skills cannot be detached or backgrounded. For non-interactive execution, use `protocols/headless.md`.

## Reversibility Classification
Classify every decision by structural rules first, agent judgment second.

### Structural Overrides
These are always Type 1:
- Changes to `**/types.*`, `**/schema.*`, `**/model.*`, `**/interface.*`, `**/api.*`
- Changes outside the current task's `plan.md` file-change map
- Assumptions that contradict an existing acceptance criterion
- Destructive filesystem operations (for example `rm -rf`, file deletion)
- Plan mismatches (spec says X, codebase has Y)

### Agent Classification
| Type | Criteria | Action |
|------|----------|--------|
| **Type 2** | Undoable by a later commit, PR, or config change | Decide with available information. Bias to action. |
| **Type 1** | Requires significant rework, causes data loss, or impacts users | Analyze carefully. Use CCR when blast radius is systemic. Document thoroughly. |

Agent-classified Type 1 decisions are highlighted at the next gate handoff.

## Decision Heuristics
### APPROVAL
Artifacts auto-progress when quality checks pass: convergence >=4/5 on all four dimensions, spec-review has no BLOCKs, and TDD plus post-build review have no BLOCKs. On quality failure, auto-revise up to 2 iterations. If the deficiency is Type 1, halt and surface it at the gate. If Type 2, document it and proceed.

### DISAMBIGUATION
Resolve ambiguity in order:
1. Constitution or TESTING.md prescribes an answer.
2. `patterns.md` covers the case.
3. One option is more reversible.
4. One option is simpler (Principle of Least Surprise).
5. Still tied: choose the closest match to existing codebase conventions.

### ERROR_HANDLING
1. Mitigate first (restore working state), root-cause second.
2. Test fixes in decreasing likelihood order.
3. After 2 attempts: document failure and proceed to the next task.
4. Exception: if later tasks depend on the failure, halt.

### CURATION
- Promote to `patterns.md` when the pattern recurs across 2+ units or matches a known failure class.
- Promote to `{projectArtifactsRoot}/TESTING.md` when the learning is a boundary classification or test-infra discovery.
- Never auto-promote to the constitution or auto-memory; that is Type 1.
- Record all auto-promotions in `decisions.md`.

### CONFIRMATION
Destructive actions such as `sw-status --reset` and `sw-status --cleanup` need human confirmation. Other decisions are artifact-driven; the artifact is the review surface.

## Convergence Loop
Iterative critic loop for `sw-design`. Complex designs must survive adversarial review before approval.

### Dimensions
| Dimension | Question |
|-----------|----------|
| **Completeness** | Are all requirements addressed? |
| **Coherence** | Do the parts fit together without contradictions? |
| **Feasibility** | Can this actually be built with the stated approach? |
| **Risk Coverage** | Are failure modes and edge cases identified? |

### Critic Output Requirements
Every critic pass, initial and follow-up, includes findings, assumptions, scores, and the sections below.

#### Perspective Lenses
Four prose-only assessments:
- **Security Assessment**: trust boundaries, auth/authz, injection, exposure, blast radius
- **Performance Assessment**: latency, throughput, unbounded work, cache gaps, sync bottlenecks
- **Operability Assessment**: deploy, monitor, rollback, debug, runbook readiness
- **Simplicity Assessment**: complexity beyond the stated need, extra abstraction, needless indirection

#### Pre-Mortem
Assume the design shipped and caused a production incident 6 months later. State the likely root cause in 2-3 sentences. This is systemic and complements CCR, which is narrower and decision-specific.

#### Charter Alignment
State whether the design advances CHARTER.md and whether it violates any stated architectural invariants. Cite the relevant charter language when flagging a concern.

### Scoring Rubric

| Score | Meaning |
|-------|---------|
| 1-2 | Significant gaps remain |
| 3 | Adequate, but notable weaknesses remain |
| 4 | Strong with only minor issues |
| 5 | Comprehensive with no meaningful gaps |

### Dimension Rotation

| Iteration | Lead Dimension |
|-----------|----------------|
| 1 | Risk Coverage |
| 2 | Completeness |
| 3 | Coherence |
| 4 | Feasibility |

Risk Coverage leads first because optimism bias most often hides there.

### Procedure

1. First iteration: the existing critic pass reviews the design and emits the required sections.
2. Scoring: a separate architect invocation scores the critic on all four dimensions. Self-scoring is not allowed.
3. Convergence check: if all four dimensions are >=4, the loop exits. In autonomous mode, >=4 with no BLOCK findings auto-approves the design.
4. Follow-up iteration: if any dimension is below 4, run a targeted critic pass focused only on the weak dimensions, starting with the rotated lead dimension.
5. Cap: maximum 3 total iterations (1 initial plus up to 2 follow-ups).
6. Cap exit: if the cap is reached without convergence, stop anyway, preserve all findings, and record the final scores.

### Integration

After convergence or cap exit, append this section to `design.md`:

```markdown
## Design Quality
Convergence: {converged | cap-reached} after {n} iterations
| Dimension | Score |
|-----------|-------|
| Completeness | N/5 |
| Coherence | N/5 |
| Feasibility | N/5 |
| Risk Coverage | N/5 |
```

This gives `sw-plan` visibility into design confidence.

### When to Skip

The convergence loop always runs for every design. There are no intensity levels that bypass it.

## Assumption Lifecycle

Design assumptions are statements treated as true without verification. Untracked assumptions become risks, so they must be visible, classified, and resolvable before implementation begins.

### Artifact

**Location:** the design assumptions artifact in `{workArtifactsRoot}/{id}/`

Produced by `sw-design` during the critic phase. Travels with the design to `sw-plan` and downstream stages.

### Format

```markdown
# Assumptions
Status: {resolved-count}/{total-count} resolved
## Blocking
### A1: {title}
- **Category**: {technical | integration | data | behavioral | environmental}
- **Resolution**: {clarify | reference | external}
- **Status**: UNVERIFIED
- **Impact**: {what breaks if this is wrong}
- **Needs**: {specific action to resolve}
## Accepted / Verified / Late
### A2: {title}
- **Status**: ACCEPTED | VERIFIED | LATE-FLAGGED | DEFERRED
- **Rationale/Evidence/Trigger**: {status-specific support}
```

### Classification

**Categories**

| Category | Description | Example |
|----------|-------------|---------|
| `technical` | Technology capability or limit | "Redis supports pub/sub at our expected throughput" |
| `integration` | External system behavior or API contract | "The payment API returns idempotency keys" |
| `data` | Data shape, quality, volume, or availability | "User records always have an email field" |
| `behavioral` | User or upstream interaction pattern | "Requests arrive at most 100/sec" |
| `environmental` | Infra, permissions, network, deployment | "Lambda has access to the VPC subnet" |

**Resolution types**

| Type | Meaning | Action required |
|------|---------|-----------------|
| `clarify` | User can resolve by clarifying ambiguity | Ask focused questions |
| `reference` | Needs authoritative docs or schemas | Obtain the source artifact |
| `external` | Needs another team or third party | Escalate and wait for answer |

**Statuses**

| Status | Meaning | Blocks design approval? |
|--------|---------|------------------------|
| `UNVERIFIED` | Not resolved yet | Yes |
| `ACCEPTED` | Risk acknowledged and accepted | No |
| `VERIFIED` | Confirmed with evidence | No |
| `LATE-FLAGGED` | Surfaced after design phase | No |
| `DEFERRED` | Parked with a backlog item | No |

### Lifecycle

1. Identification: critic or research surfaces the assumption.
2. Classification: assign category and resolution type.
3. Presentation: group `UNVERIFIED` assumptions by needed action.
4. Resolution: clarify, reference, accept, or defer.
5. Gate: design cannot be approved while blocking assumptions remain `UNVERIFIED`.

### Autonomous Resolution

| Resolution Type | Classification | Auto-resolution | Rationale |
|-----------------|----------------|-----------------|-----------|
| `clarify` | `technical` | auto-ACCEPT (Type 2) | Verifiable during build and reversible |
| `clarify` | non-behavioral | auto-ACCEPT (Type 2) | Integration, data, and environment assumptions are still reversible |
| `clarify` | `behavioral` | remains blocking | User intent cannot be inferred from code |
| `reference` | any | remains blocking | Requires authoritative external material |
| `external` | any | remains blocking | Requires another team or third party |

Structural override: any assumption that contradicts an acceptance criterion is Type 1 regardless of resolution type. If more than 5 assumptions are auto-accepted in one skill run, surface the full list in the gate handoff with an attention flag. Auto-resolved assumptions are recorded in `{workDir}/decisions.md`.

### Identification Heuristics

Flag an assumption when the design:
- references an API, schema, or interface not verified against docs
- assumes third-party behavior without evidence
- depends on data shape or format without validation
- assumes infrastructure or permissions exist without checking
- relies on unbenchmarked performance characteristics
- expects another team's system to support a specific interaction
- uses language like "should work", "probably supports", or "typically returns"

### Downstream Usage

- `sw-plan` checks that specs do not depend on `UNVERIFIED` assumptions.
- `sw-verify` may use `VERIFIED` assumptions as supporting evidence.
- `external` assumptions may become explicit plan dependencies.

### Late Discovery Lifecycle

Assumptions can surface after design approval.

#### Identification

- In `sw-plan`: append newly surfaced assumptions to the design assumptions artifact with status `LATE-FLAGGED` and discovery phase `planning`.
- In `sw-build` pre-build: scan `spec.md` and `context.md` for stale assumptions.
- In `sw-build` post-task: check whether tester or executor hit a contradiction or hidden dependency.

#### Format

Late assumptions use the same format with:
- **Status**: `LATE-FLAGGED`
- **Discovered**: `{planning | building}`
- **Trigger**: what surfaced it

#### Presentation

- In `sw-plan`: present late assumptions at the spec approval checkpoint.
- In `sw-build`: capture non-critical late assumptions in as-built notes under `## Late Assumptions`.

#### Criticality Rule

Pause only when the assumption directly contradicts an existing acceptance criterion. That is the sole trigger for stopping the build.

#### Transitions

`LATE-FLAGGED` can become `VERIFIED`, `ACCEPTED`, or `DEFERRED`.

#### Gate Interaction

`LATE-FLAGGED` does not participate in design approval. Only `UNVERIFIED` assumptions block the design gate.

#### Stage Boundary Re-surfacing

Any unresolved `LATE-FLAGGED` assumptions must be surfaced again at the next stage boundary so they do not silently persist into verification.

### Size

Target 10-30 assumptions for a complex design. Skip the artifact for Quick intensity. Lite designs keep assumptions inline in `context.md`.

## Cross-Context Review

For Type 1 decisions with systemic blast radius:
- Reviewer receives only the artifact, not the reasoning or summary.
- Reviewer mandate: "Assume this shipped and caused an incident 6 months later. What was the root cause?"
- Findings are tagged `[CCR]` in `decisions.md`.
- If CCR returns BLOCK, reverse the decision.
- Skip CCR for Type 2 choices, cases already covered by convergence, or speed-critical work.

## Decision Record

Every autonomous decision is recorded in `{workDir}/decisions.md`:

```markdown
## D-{n}: {description}
- **Type**: 1 | 2
- **Category**: APPROVAL | DISAMBIGUATION | ERROR_HANDLING | CURATION | CONFIRMATION
- **Rule applied**: {which heuristic resolved it}
- **Choice**: {what was decided}
- **Alternatives**: {rejected options and why}
- **Timestamp**: {ISO-8601}
- **Reversible by**: {undo path}
```

CCR-reviewed decisions also add `**CCR verdict**` and `**CCR findings**`.

## Stage Report

Every pipeline skill handoff writes `{stageReportPath}` before emitting the
terminal three-line handoff.

**Top line:** `Attention required: {single-sentence summary}`

**Cap:** hard limit of ~40 lines. This artifact is a pointer-sized digest, not
the full report.

**Required sections:**
- `Precondition State`
- `What I did`
- `Decisions digest`
- `Quality Checks` (omit only when genuinely inapplicable)
- `Postcondition State`
- `Recommendation`

The "Attention required" line stays at the top of the file so the next stage
can see the risk signal without scrolling.

## Gate Handoff

When a pipeline skill finishes, emit exactly three lines:

```text
Done. {one-line outcome}.
Artifacts: {stageReportPath}
Next: /sw-{next-skill}
```

The detail lives in the artifact files. Terminal output is the pointer, not the report.

## Precedence

In headless or CI mode, `protocols/headless.md` takes precedence. This protocol governs interactive autonomous behavior.
