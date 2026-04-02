# Semi-Formal Reasoning Protocol

Structured reasoning for quality gate evidence. Agents construct explicit
certificates with traced evidence chains instead of free-form claims.

Based on Ugare & Chandra, "Agentic Code Reasoning" (arXiv:2603.01896v2).

## Certificate Structure

Every certificate follows three phases:

**PREMISES** — Observable facts grounded in code. File:line citations required.
Each premise states what the code does, not what it should do.

**CLAIMS** — Trace execution for each scenario using premises as input.
Each claim references one or more premises with file:line evidence.
Follow function calls across files; do not guess from names.

**CONCLUSION** — Derive verdict from premises and claims only. No new evidence
introduced. If any premise directly contradicts the claim being evaluated,
emit conclusion immediately — do not complete remaining fields.

## When to Use

Apply to **behavioral criteria** — those involving execution-path claims,
interprocedural behavior, or state transitions. Examples: "handles concurrent
writes correctly", "error path releases resources", "returns correct result
when input shadows a module-level name".

Do NOT apply to **structural criteria** — file existence, endpoint definition,
config presence, type annotations. These are verified by inspection.

## Verification Template (gate-spec)

For each behavioral acceptance criterion:
- **PREMISES**: What the criterion requires (from spec) + what the code does
  (file:line evidence from codebase search)
- **CLAIMS**: Trace the execution path showing the criterion is satisfied or
  violated. Reference specific premises.
- **CONCLUSION**: PASS with evidence chain, or FAIL with identified gap
- **Alternative hypothesis**: State what evidence would exist if the opposite
  were true. Search for it.

## Localization Template (gate-semantic)

For validating each candidate finding from tool tiers:
- **PREMISES**: What behavior does the affected code path serve? What resource
  or error state is involved?
- **CLAIMS**: Trace from entry point through the finding location. Where does
  the implementation diverge from safe behavior?
- **CONCLUSION**: Confidence-ranked finding with supporting claim chain.
  Rate: confirmed, likely, possible, or false-positive.

## Analysis Template (specwright-reviewer)

For understanding code to map criteria to evidence:
- **Function trace**: Every function examined — file:line, parameters, return,
  verified behavior
- **Data flow**: How key variables flow through the code path
- **Semantic properties**: Claims about behavior, each grounded in file:line
- **Alternative hypothesis**: "If I'm wrong about this criterion, what
  evidence would exist?" Search for it before concluding.

## Graceful Degradation

If this protocol is not loaded (compaction, context limits):
- **gate-semantic** retains inline diagnostic questions per category
- **gate-spec** retains its evidence mapping constraints and verdict rules
- **specwright-reviewer** retains its verification methodology

Quality degrades to pre-protocol baseline, not below it. No skill depends
on this protocol for basic functionality.
