# Research Brief: Semi-Formal Reasoning for Specwright Quality Gates

Topic-ID: semi-formal-reasoning
Created: 2026-04-02
Updated: 2026-04-02
Tracks: 4

> **Cap warning:** Research directory is at 10 briefs (cap). This write
> exceeds the cap (11). Consider removing stale briefs:
> `non-interactive-skills-20260319.md`, `testing-strategy-20260319.md`,
> `guardrails-strategy-20260320.md`, `impact-analysis-20260320.md`

## Summary

Semi-formal reasoning (Ugare & Chandra, Meta, arXiv:2603.01896v2) is a
structured prompting technique that requires LLM agents to construct explicit
PREMISE → CLAIM → CONCLUSION certificates when reasoning about code. The
technique improves Opus accuracy by 4.5–10.6pp across patch verification,
fault localization, and code QA tasks, at a cost of 1.4–2.8x more agent steps.
Sonnet shows no benefit on code QA or fault localization. The proposal to
integrate this into Specwright's gate system is architecturally sound and maps
cleanly to existing protocol/evidence/gate structures. Cost mitigation through
selective application (behavioral criteria only, final gate, Opus model) is
well-supported by the broader literature on adaptive reasoning allocation.

## Findings

### Track 1: Source Paper Verification

#### F1: Numerical results verified with corrections
- **Claim**: All five accuracy improvements cited in the proposal are confirmed from the paper. Two corrections needed: (1) the real-world patch equivalence baseline is 87.0% (agentic standard), not 86.0% (single-shot standard) — the proposal conflates two comparison conditions; (2) the 2.8x cost overhead applies specifically to curated patch equivalence (10.08 → 28.17 steps), not uniformly across tasks — real-world overhead is ~1.9x, code QA overhead is ~1.8x (Opus) and ~1.4x (Sonnet).
- **Evidence**: Paper Tables 2-6, Section 4.1-4.3. Curated: 78.2% → 88.8% (+10.6pp). Real-world agentic: 87.0% → 93.0% (+6.0pp). Code QA Opus: 78.3% → 87.0% (+8.7pp). Fault loc Top-5 All: 43.3% → 47.8% (+4.5pp). Fault loc fit-in-context: 60.5% → 72.1% (+11.6pp).
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

#### F2: Certificate template structure confirmed
- **Claim**: The technique uses task-specific certificate templates with bracketed fields. Agents must fill Definitions, Premises, per-test execution traces (Analysis), Counterexample/Proof, and Formal Conclusion. The paper explicitly describes these as "certificates" because agents cannot skip cases or make unsupported claims.
- **Evidence**: "Unlike unstructured chain-of-thought, semi-formal reasoning acts as a certificate: the agent cannot skip cases or make unsupported claims." — arXiv:2603.01896v2 abstract. "The key insight is the PREMISE → CLAIM → PREDICTION chain: every prediction must trace back through a divergence claim to a specific test premise." — Appendix B.
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

#### F3: Sonnet shows no benefit on code QA and fault localization
- **Claim**: Sonnet-4.5 gains are negligible or negative on code QA (+0.6pp, 84.2% → 84.8%) and fault localization (-1.1pp, 31.1% → 30.0%). The paper attributes this to model capability plateau. Sonnet does gain on patch equivalence (+7.0pp).
- **Evidence**: Section 4.3: "For Sonnet, standard agentic reasoning already achieves 85.3%, and the semi-formal template does not yield further gains (84.8%), suggesting that the benefit of structured reasoning varies by model capability and may plateau when the base model is already strong."
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

#### F4: Four fault localization failure modes confirmed
- **Claim**: The paper identifies exactly four failure modes for semi-formal fault localization: (1) indirection bugs (bug in class not directly invoked by test), (2) multi-file bugs (spanning multiple locations), (3) domain-specific bugs (requiring algorithmic knowledge), (4) more than 5 fix regions (prediction limit exceeded). These are specific to fault localization; patch equivalence has three separate failure modes.
- **Evidence**: Section 4.2, explicit numbered list.
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

#### F5: Paper uses Claude Opus 4.5 and Sonnet 4.5
- **Claim**: The models evaluated are Claude Opus-4.5 and Claude Sonnet-4.5, not older versions. The proposal does not specify which model versions were used in the paper.
- **Evidence**: Model identification in paper methodology sections.
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

#### F6: Data contamination caveat
- **Claim**: The paper acknowledges SWE-bench instances may appear in training corpora, which could affect absolute scores. Authors argue relative comparisons (same model across conditions) are the reliable signal.
- **Evidence**: Discussed in paper limitations.
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

### Track 2: Protocol Integration Architecture

#### F7: Protocol placement is clean — no conflicts
- **Claim**: Specwright's `core/protocols/` directory has 26 existing protocols. A `semi-formal-reasoning.md` protocol fits the established pattern (loaded on demand, referenced from skills/agents via Protocol References section). No naming conflicts exist. The proposal's path `core/protocols/semi-formal-reasoning.md` is correct.
- **Evidence**: Direct inspection of `core/protocols/` directory and DESIGN.md principle 3 (progressive disclosure).
- **Source**: Local codebase analysis
- **Confidence**: HIGH
- **Potential assumption**: no

#### F8: Token budget is the binding constraint for skill modifications
- **Claim**: DESIGN.md mandates ~800 tokens per SKILL.md. Current word counts: gate-spec (397), gate-semantic (1,551 — already over budget), specwright-reviewer (359), specwright-tester (1,019). The proposal correctly puts template detail in the protocol. Gate-semantic modifications must be minimal — it already exceeds the token target. Gate-spec and reviewer have room for protocol references.
- **Evidence**: DESIGN.md line 17: "SKILL.md files stay under 800 tokens. Detail lives in protocols (loaded on demand), not inlined." Word counts via `wc -w`.
- **Source**: Local codebase analysis
- **Confidence**: HIGH
- **Potential assumption**: no

#### F9: Evidence chain extension is natural
- **Claim**: The evidence.md protocol (118 words) is lightweight and defines evidence storage format. Semi-formal certificates are a structured form of evidence — the relationship is extension, not replacement. A certificate produced by semi-formal reasoning becomes the evidence that gate-verdict.md evaluates. No changes to evidence.md or gate-verdict.md are needed.
- **Evidence**: Direct analysis of `protocols/evidence.md` (storage format only) and `protocols/gate-verdict.md` (verdict logic independent of evidence structure).
- **Source**: Local codebase analysis
- **Confidence**: HIGH
- **Potential assumption**: no

#### F10: Self-critique checkpoint is complementary, not redundant
- **Claim**: gate-verdict.md has an unstructured "Self-Critique Checkpoint" (4 questions: "Did I accept anything without citing proof?", "Would a skeptical auditor agree?"). Semi-formal reasoning's PREMISE → CLAIM → CONCLUSION chain makes this concrete by requiring structured evidence before the self-critique runs. They are complementary: semi-formal structures the reasoning, self-critique validates the output.
- **Evidence**: gate-verdict.md lines 9-15 vs. proposal Section 2 (certificate structure).
- **Source**: Local codebase analysis
- **Confidence**: HIGH
- **Potential assumption**: no

#### F11: Reviewer agent is the highest-value integration target
- **Claim**: The specwright-reviewer (359 words, Opus model, READ-ONLY) is gate-spec's primary delegate for evidence mapping. It already has the mandate to map criteria to file:line evidence. Adding structured analysis templates to the reviewer is the highest-value, lowest-risk change because: (a) Opus benefits most from semi-formal reasoning (F3), (b) the reviewer has token budget headroom, (c) gate-spec is the final gate where false-PASS has the highest cost.
- **Evidence**: `agents/specwright-reviewer.md` (model: opus, 359 words), `skills/gate-spec/SKILL.md` (delegates to reviewer), proposal Section 3.4.
- **Source**: Local codebase analysis
- **Confidence**: HIGH
- **Potential assumption**: no

#### F12: Convergence vs. semi-formal differentiation is correct
- **Claim**: The convergence protocol operates during design (iterative multi-perspective critique with 4 scored dimensions). Semi-formal reasoning operates during verify (single-pass structured code analysis). Different phases, different inputs, different outputs. The proposal's differentiation table (Section 6) is accurate. No overlap.
- **Evidence**: `protocols/convergence.md` (design phase, 4 dimensions, iterative loop) vs. proposal Section 2 (verify phase, code analysis, single-pass certificate).
- **Source**: Local codebase analysis
- **Confidence**: HIGH
- **Potential assumption**: no

### Track 3: Cost-Accuracy Tradeoffs

#### F13: Cost overhead varies significantly by task (1.4x–2.8x)
- **Claim**: The 2.8x figure is from curated patch equivalence only. Actual overhead by task: curated patch 2.79x, real-world patch (Opus) 1.92x, real-world patch (Sonnet) 2.09x, code QA (Opus) 1.82x, code QA (Sonnet) 1.44x. The proposal's "~2.8x" headline is misleading as a general characterization.
- **Evidence**: arXiv:2603.01896v2 Table 2 step counts across all experimental conditions.
- **Source**: https://arxiv.org/abs/2603.01896
- **Confidence**: HIGH
- **Version/Date**: arXiv v2, March 4, 2026
- **Potential assumption**: no

#### F14: Adaptive reasoning routing frameworks validate selective application
- **Claim**: Two frameworks directly support the proposal's selective application strategy. Route to Reason (RTR, arXiv:2505.19435) uses a dual-prediction router to select model-strategy combinations, achieving 82.5% accuracy with 60%+ token reduction vs. uniform expensive reasoning. Ares (arXiv:2603.07915) selects per-step effort level, achieving 52.7% reasoning token reduction with no accuracy loss. Neither addresses code analysis gates specifically, but the general principle — route by task complexity — supports the proposal's behavioral/structural criterion distinction.
- **Evidence**: RTR: arXiv:2505.19435. Ares: arXiv:2603.07915 (46.5% vs. 45.0% on WebArena while saving 45.3% tokens).
- **Source**: https://arxiv.org/abs/2505.19435, https://arxiv.org/abs/2603.07915
- **Confidence**: MEDIUM (frameworks validated on general tasks, not code gates)
- **Potential assumption**: yes — extrapolating from general reasoning tasks to code quality gates

#### F15: Fail-fast mechanisms achieve 41–75% token reduction
- **Claim**: Two approaches enable early termination in structured reasoning. ES-CoT (arXiv:2509.14004) monitors answer convergence via consecutive identical step answers, achieving 41% average token reduction while maintaining accuracy. "Stop Spinning Wheels" (arXiv:2508.17627) identifies a Reasoning Completion Point (RCP) where additional computation degrades accuracy, achieving 56–75% compression. Neither has been evaluated on PREMISE → CLAIM → CONCLUSION templates specifically.
- **Evidence**: ES-CoT: arXiv:2509.14004. RCP: arXiv:2508.17627 (GPQA-D: 64.65% vs. 60.10% baseline — accuracy improved with early stopping).
- **Source**: https://arxiv.org/abs/2509.14004, https://arxiv.org/abs/2508.17627
- **Confidence**: MEDIUM (general reasoning, not code-specific templates)
- **Potential assumption**: yes — convergence signals may differ in structured code analysis templates

#### F16: Token elasticity risk with tight template constraints
- **Claim**: The TALE framework (arXiv:2412.18547) found that if a token budget is too tight, models abandon constraints and produce longer outputs than without a budget at all ("token elasticity"). This is relevant: a structured reasoning template that imposes tight structure may paradoxically increase token usage if the model struggles to follow the template format.
- **Evidence**: TALE-EP optimal budget on GSM8K: ~77 tokens (vs. ~318 for standard CoT) with <3% accuracy loss. But budgets below the optimal range triggered elastic blowup.
- **Source**: https://arxiv.org/abs/2412.18547
- **Confidence**: MEDIUM (general reasoning, not code templates)
- **Potential assumption**: yes — whether elasticity applies to structured code templates is untested

### Track 4: Prior Art in Structured Code Reasoning

#### F17: SemLoc is the closest sibling technique
- **Claim**: SemLoc (arXiv:2603.29109, March 2026) is a concurrent, independent work that also structures LLM reasoning for fault localization. It converts free-form reasoning into a "semantic violation spectrum" — a constraint-by-test matrix where each property is bound to a typed program anchor and runtime-checked. Results on SemFault-250: 42.8% Top-1, 68% Top-3. Counterfactual verification adds 12% accuracy. SemLoc's representation is more formal (runtime-checkable) than Ugare & Chandra's natural-language certificate.
- **Evidence**: arXiv:2603.29109 abstract: "Converts free-form LLM reasoning into a closed intermediate representation that binds each inferred property to a typed program anchor."
- **Source**: https://arxiv.org/abs/2603.29109
- **Confidence**: HIGH
- **Version/Date**: March 2026
- **Potential assumption**: no

#### F18: Typed Chain-of-Thought (PC-CoT) formalizes CoT as verifiable certificates
- **Claim**: PC-CoT (arXiv:2510.01069) applies the Curry-Howard correspondence to verify faithfulness of CoT traces. Each reasoning step gets a type under lightweight rule schemas, forming a Typed Reasoning Graph. A well-typed trace is a "verifiable certificate of computational faithfulness." 81% of certified runs showed full or partial alignment. Conceptually close to semi-formal reasoning: both treat reasoning traces as certifiable artifacts. Unlike Ugare & Chandra, PC-CoT applies post-hoc type-checking rather than prescribing task-specific templates.
- **Evidence**: "A faithful reasoning trace is analogous to a well-typed program, where each intermediate step corresponds to a typed logical inference."
- **Source**: https://arxiv.org/abs/2510.01069
- **Confidence**: HIGH (but not evaluated on code-specific tasks)
- **Version/Date**: Submitted to ICLR 2026
- **Potential assumption**: yes — PC-CoT was not evaluated on code analysis tasks

#### F19: Formal verification with LLMs is possible but high-cost
- **Claim**: Claude 3.5 Sonnet can generate formal proofs (Dafny 86%, Nagini 66%, Verus 45% verification rates) but degrades sharply when specifications must come from natural language (29-61%). This establishes the upper bound: fully formal verification is possible but impractical for general-purpose quality gates. Semi-formal reasoning occupies the practical middle ground.
- **Evidence**: arXiv:2503.14183, six verification modes tested across three proof languages.
- **Source**: https://arxiv.org/abs/2503.14183
- **Confidence**: HIGH
- **Version/Date**: March 2025
- **Potential assumption**: no

#### F20: No head-to-head comparisons exist
- **Claim**: No published evaluation compares semi-formal reasoning (Ugare & Chandra), SemLoc, SCoT, or PC-CoT against each other. Each was evaluated on different benchmarks with different models. The relative effectiveness of these techniques cannot be determined from current literature.
- **Evidence**: Absence of cross-technique evaluations in all papers reviewed.
- **Source**: Literature survey across tracks 1 and 4
- **Confidence**: HIGH
- **Potential assumption**: no

## Conflicts & Agreements

**Agreement across sources:**
- All papers agree that structured reasoning improves accuracy over free-form CoT for code analysis tasks (F1, F17, F18, F19).
- The cost-quality tradeoff literature uniformly supports selective application over uniform application of expensive reasoning (F14, F15).
- Multiple sources confirm that model capability matters: weaker models gain less or nothing from structured reasoning (F3, F14).

**Conflicts:**
- The 2.8x cost characterization (F1) conflicts with the task-specific data showing a 1.4–2.8x range (F13). The proposal should use the range, not the headline figure.
- SemLoc's approach (runtime-checkable constraints, F17) is more formal than Ugare & Chandra's approach (natural-language certificates with structure, F2). It's unclear which level of formality is optimal for practical quality gates.
- The TALE elasticity finding (F16) raises a risk not addressed in the proposal: template structure may increase cost for simple criteria where free-form reasoning would suffice. This reinforces the selective application strategy but suggests it's more important than the proposal implies.

**Reinforcements across tracks:**
- The Sonnet plateau (F3) + adaptive routing literature (F14) jointly strengthen the proposal's model-dependent application strategy.
- The fail-fast literature (F15) validates the proposal's "short-circuit on obvious FAIL" recommendation, with quantified savings (41–75%).
- SemLoc (F17) as a concurrent independent approach confirms that structured code reasoning is an emerging research direction, not an isolated technique.

## Open Questions

1. **Optimal formality level:** Semi-formal (natural-language certificates) vs. more formal (SemLoc's runtime-checkable constraints) — which produces better gate evidence? No comparative data exists.
2. **Template elasticity in practice:** Will Specwright's agents follow certificate templates reliably, or will the structured format trigger token elasticity (F16) on simple criteria?
3. **Model version sensitivity:** The paper used Opus 4.5 and Sonnet 4.5. Current model is Opus 4.6. Will improvements hold or change with model updates?
4. **Fail-fast detection within structured templates:** The ES-CoT and RCP approaches (F15) were designed for free-form reasoning. How should convergence be detected within a PREMISE → CLAIM → CONCLUSION template? The proposal suggests "if a premise reveals an obvious FAIL" but doesn't specify the detection mechanism.
5. **Gate-semantic integration cost:** Gate-semantic already exceeds the 800-token SKILL.md budget (1,551 words, F8). How can the localization template be referenced without further inflating the skill?
6. **Per-criterion routing:** The proposal suggests behavioral vs. structural classification for criteria. What's the classification heuristic? Manual annotation in spec.md, or automated detection?
7. **Interaction with data contamination:** The paper's absolute scores may be inflated by training data overlap (F6). Do the relative improvements hold on truly novel codebases (like Specwright users' private repos)?
