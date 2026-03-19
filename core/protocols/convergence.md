# Convergence Protocol

Iterative critic loop for sw-design. Ensures complex designs receive sufficient
adversarial scrutiny before approval.

## Dimensions

Each critic pass is scored on four dimensions (1-5):

| Dimension | Question |
|-----------|----------|
| **Completeness** | Are all requirements addressed? |
| **Coherence** | Do the parts fit together without contradictions? |
| **Feasibility** | Can this actually be built with the stated approach? |
| **Risk Coverage** | Are failure modes and edge cases identified? |

## Critic Output Requirements

Every critic pass (initial and follow-up) must include the following sections in
its output, in addition to findings, assumptions, and scores.

### Perspective Lenses

Four narrative assessments — no scores, prose only. Each addresses a specific
quality angle that the scored dimensions do not fully capture:

**Security Assessment**
What are the trust boundaries? Are there authentication, authorization, injection,
or data exposure risks? What is the blast radius of a compromise?

**Performance Assessment**
Where are the latency or throughput bottlenecks? Are there unbounded queries,
missing caches, or synchronous paths that should be async?

**Operability Assessment**
Can this be deployed, monitored, and debugged in production? Are there gaps in
logging, alerting, rollback, or runbook coverage?

**Simplicity Assessment**
Is the design more complex than the problem requires? Flag any abstraction layers,
indirection, or configurability that serves no stated requirement.

### Pre-Mortem

Assume this design shipped and caused a production incident 6 months later. What
was the root cause? Answer in 2-3 sentences.

### Charter Alignment

Does this design advance the project's stated vision as described in CHARTER.md?
Does it violate any architectural invariants stated there? Cite the relevant
charter language when flagging a concern.

## Scoring Rubric

| Score | Meaning |
|-------|---------|
| 1-2 | Significant gaps — major issues unaddressed |
| 3 | Adequate but notable weaknesses remain |
| 4 | Strong with only minor issues |
| 5 | Comprehensive — no meaningful gaps |

## Dimension Rotation

Follow-up iterations use deterministic round-robin rotation to determine which
dimension leads evaluation (i.e., is examined first and given primary emphasis
when dimensions conflict for prioritization):

| Iteration | Lead Dimension |
|-----------|----------------|
| 1 | Completeness |
| 2 | Coherence |
| 3 | Feasibility |

This rotation is fixed — not random. A follow-up starting in iteration 2 leads
with Coherence regardless of which dimensions scored below 4.

## Procedure

1. **First iteration**: the existing critic pass. The architect reviews the design,
   produces findings and assumptions per its normal output format, including all
   perspective lens sections (see Critic Output Requirements below).

2. **Scoring**: a **separate architect invocation** (not the same pass) receives the
   original design plus the critic's findings and scores each dimension 1-5.
   Self-scoring within the same invocation is not permitted — the scorer must
   evaluate the critic's work independently.

3. **Convergence check**: if ALL four dimensions score 4 or higher, the loop exits.
   The design is ready for user review.

4. **Follow-up iteration**: if any dimension scores below 4, a targeted follow-up
   critic pass runs. The follow-up receives the original design, all accumulated
   findings, and the scores. It focuses ONLY on dimensions scoring below 4,
   leading with the dimension assigned by rotation (see Dimension Rotation above).
   After each follow-up, scoring is repeated using the same separate-invocation
   rule (step 2), then the convergence check (step 3) is applied again.

5. **Cap**: maximum 3 total iterations (1 initial + up to 2 follow-ups). The cap
   prevents infinite loops.

6. **Cap-exit behavior**: if the cap is reached without convergence (some dimensions
   still below 4), the loop exits anyway. All accumulated findings are preserved.
   The design proceeds to user review with the final scores as-is. The scores are
   recorded in the design artifacts so downstream phases have visibility into which
   areas the critic found weakest.

## Integration

After convergence (or cap exit), append a "Design Quality" section to `design.md`:

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

This section gives sw-plan visibility into design confidence levels.

## When to Skip

Skip the convergence loop for Lite and Quick intensity designs. These go through
a single critic pass (or no critic) per their existing sw-design constraints.
