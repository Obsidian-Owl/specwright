---
topic-id: retro-refinement
date: 2026-03-22
status: approved
confidence: HIGH (gate gap, security checks, plan grounding, constitution fitness), MEDIUM (tree-sitter repo map, source-level brittleness coverage)
sources: 60+ primary
---

# Specwright Refinement Approaches: Generalizability Analysis

## Context

Retro from 2026-03-20 produced 8 themes and 4 recommended changes from 4 projects
(Go backends, Next.js frontend, Markdown plugin, Go+Python platform). This research
tests whether those recommendations generalize across domains or overfit to the
observed stack.

## Track 1: Gate Gap Generalizability

### Claim: "Catches structure, misses semantics" is universal

**CONFIRMED with qualification.**

- ESLint/CodeClimate: purely structural. Semgrep/CodeQL: add dataflow but remain
  security-scoped. Meta's Infer: catches semantic bugs (null deref, races) but FP
  rate is "unmeasurable in practice."
- The gap exists in Java (PMD/SpotBugs study: 35.7% missed bugs from "missing cases"),
  C/C++ (47-80% vulnerability miss rate), Python (98% of bugs are non-type-related),
  Rust (narrower gap for memory/concurrency due to borrow checker, still present
  for application logic).
- Industry pattern confirmed: Google, Meta, Microsoft all automate structural checks,
  leave semantic review to humans.
- LLMs partially close gap: 67% accuracy on simple patterns with full context
  (CORRECT framework), 54% balanced accuracy overall (To Err is Machine). Best use
  is filtering static analysis FPs (94-98% elimination), not finding new bugs.

**Implication:** Don't try to make gates catch semantic bugs. Invest in mechanisms
that do: architect critic and learning lifecycle.

Sources: Google SWE Book (abseil.io), arXiv:2408.13855, arXiv:2601.18844,
arXiv:2504.13474, OpenReview Q0mp2yBvb4, Meta Infer (fbinfer.com)

## Track 2: Security Gate Expansion

### 10 domain-agnostic, LLM-auditable logical security checks

**Tier 1 — BLOCK candidates (high confidence, low FP):**
1. Hardcoded credentials (CWE-798)
2. Broken/absent cryptography (CWE-327)
3. Fail-open exception handling (CWE-636) — new in OWASP 2025
4. Error messages exposing sensitive data (CWE-209)
5. Missing authentication on critical functions (CWE-306) — only when completely absent

**Tier 2 — WARN candidates (moderate confidence):**
6. Missing request size limits (CWE-400)
7. Insecure deserialization (CWE-502)
8. Missing authorization on data access (CWE-862) — only obvious local absence
9. Dangerous defaults (debug mode, permissive CORS)
10. Sensitive data in logs (CWE-532)

**Critical constraint:** LLM auth detection has 88% FP rate when RBAC is distributed
across files, 68% accuracy when auth is completely absent (Semgrep 2025 IDOR study).
Scope to obvious absence or FPs destroy gate trust.

**Alert fatigue:** 70%+ FP rate causes "desensitization." Three-tier severity
(BLOCK/WARN/LOG) is the documented mitigation.

Sources: OWASP Top 10:2021, OWASP Top 10:2025 RC1, CWE Top 25:2024,
Semgrep IDOR study 2025, arXiv:2412.15004, Praetorian alert fatigue analysis

## Track 3: Plan-to-Code Grounding

### Confirmed as known problem across all AI coding tools

- ~85% of compilation failures in project-level code generation are context-related:
  UNDEF, API, OBJECT errors (ProCoder, ACL 2024)
- 65% of developers report AI misses context during refactoring (Qodo 2025)
- Tasks with 20+ accumulated errors: 22.6% resolution rate vs. 53.8% error-free

### Techniques that work

- **Repository maps (tree-sitter):** Aider reduces context 98% while preserving type
  signatures. Prevents "hallucinate a method" failures.
- **Iterative compiler feedback:** ProCoder shows 80%+ improvement, plateaus after
  3 iterations. Catches type errors; functional errors need different signals.
- **LSP integration:** LSPRAG uses LSP diagnostics for compilation-free verification.
- **Spec-before-plan with editable checkpoints:** Copilot Workspace pattern.

### Cross-domain variation

- 94% of LLM compilation errors are type-check failures → typed languages have
  built-in grounding verification via the compiler
- TypeScript cross-file type consistency: only 21% of full packages pass (TypeWeaver)
- Brownfield codebases: AI improves performance 84% but does NOT improve
  comprehension (arXiv:2511.02922) — code generated without understanding

Sources: arXiv:2403.16792 (ProCoder), arXiv:2503.12374 (Beyond Final Code),
Aider docs, arXiv:2510.22210 (LSPRAG), Qodo 2025, GitHub Blog Oct 2025

## Track 4: Constitution Rule Fitness

### Decision Framework

**Google's criteria (SWE Book Ch.8):**
1. Must address demonstrated real patterns — not hypothetical
2. Benefit must exceed compliance cost
3. "Problems must be proven with patterns found in existing code"
4. Distinguish rules (mandatory) from guidance (recommended)

**Rule of 3 (Bernhardsson):** Don't generalize until 3+ independent examples.
"Overfitting — detecting patterns prematurely based on limited data — leads to
brittle, overengineered solutions."

**Wieringa & Daneva case-based generalization:** A finding generalizes when the
component (e.g., test lifecycle) varies less than the case (full project stack).

### Applying to the 4 retro recommendations

| Recommendation | Rule of 3? | Cross-stack? | Verdict |
|---------------|-----------|-------------|---------|
| Test resource lifecycle | Yes (3+ projects) | Yes (Go, JS, Python all have equivalent) | **Constitution** — phrase as principle |
| Security gate expansion | No (single category) | Partially (OWASP Tier 1 is universal) | **Constitution** for OWASP baseline; **Pattern** for stack-specific |
| Plan type verification | Yes (Go, TS, Markdown) | Yes (typed languages) | **Pattern** — executor constraint, not coding practice |
| Source-level test brittleness | No (1 project) | Principle is universal | **Existing constitution** already covers it; document specifics as pattern |

### Overfitting signals

An overfitted rule: too specific, only catches the original bug, high FP on other
codebases. Cost: 50%+ FP rates cause override culture → tool abandonment.
ESLint handles this with plugins (not core) for context-specific rules.

Sources: Google SWE Book (abseil.io/resources/swe-book/html/ch08.html),
Bernhardsson 2017, Wieringa & Daneva 2015, ESLint docs, SonarQube docs

## Synthesis: What to Change in Specwright

### Ready to implement (universal, evidence-backed)

1. **Constitution rule:** "Test resources must be registered for cleanup at the
   point of acquisition." Stack-specific syntax (t.Cleanup, afterEach) in patterns.
2. **Security gate Tier 1:** Add CWE-636 (fail-open), CWE-209 (error data leakage),
   CWE-306 (missing auth — obvious absence only) to gate-security.
3. **Executor grounding constraint:** "Verify type/interface signatures exist in the
   codebase before writing implementation code."
4. **Gate communication:** Clearly document what gates DO (structural verification)
   and do NOT (semantic/runtime correctness) catch.

### Needs more evidence before implementing

5. **Security gate Tier 2:** CWE-400, CWE-502, CWE-862, dangerous defaults, log
   leakage. Need to validate FP rates on at least 2 more projects.
6. **Tree-sitter repo map for sw-plan:** Promising (Aider evidence) but no controlled
   study. Test on 1-2 projects before adding to the workflow.
7. **Neuro-symbolic semantic analysis:** ConSynergy shows 87.5% CVE detection for
   concurrency bugs. Requires dedicated research track.

### Already covered (no change needed)

8. **Source-level test brittleness:** Existing constitution rule "Tests must assert
   behavior, not implementation details" covers this. Document the specific
   DOM/CSS/line-count examples as a pattern.

## Open Questions

- Should sw-learn always produce gateCalibration data? (Only 2/40 learnings have it)
- Should the executor agent use LSP for pre-implementation type verification?
- Is neuro-symbolic hybrid (static slicing + LLM reasoning) feasible as a gate?
