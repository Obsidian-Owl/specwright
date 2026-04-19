# Research Brief: Just-in-Time and Mutation Testing Practices

Topic-ID: jit-mutation-testing
Created: 2026-04-19
Updated: 2026-04-19
Tracks: 4

## Summary

Deep external survey of JIT testing and mutation testing for a potential new Specwright verify capability. Key takeaways: (1) "JIT testing" is not one field — it decomposes into four distinct practices (test generation, test selection, defect prediction, test case prioritization), each with its own literature, benchmarks, and tooling. (2) The user-provided arxiv reference (2601.22832) is VERIFIED as Harman et al. "Just-in-Time Catching Test Generation at Meta" (FSE '26) — about LLM-generated failing tests ("catching tests"), but the abstract does NOT address mutation testing despite the user pairing them. (3) Mutation testing has strong 1978 foundations (DeMillo/Lipton/Sayward), a dominant practical barrier (equivalent mutants, 4-39% of output), and a recent inflection: LLM-generated mutants outperform rule-based tools on fault detection (87-91% vs 40-66%). (4) The tightest JIT+mutation integration in production is Meta's ACH system (FSE '25, arXiv 2501.12862) — different paper from the user's reference but likely what they meant if the goal is JIT+mutation together. (5) Tooling is mature and language-specific: PIT (Java), Stryker (JS/TS/.NET), cargo-mutants (Rust), mutmut/cosmic-ray (Python), Infection (PHP). cargo-mutants has the most explicitly documented diff-scoped CI pattern. The Stryker `mutation-testing-report-schema` is the de facto cross-tool JSON standard. (6) Only 27.9% of surveyed OSS projects enforce a mutation threshold as a CI gate — mutation testing is a known-good practice with low adoption, primarily due to runtime cost. (7) Atlassian's Rovo Dev + PIT workflow is the only publicly documented AI-coding-tool+mutation integration; no Claude Code skill or MCP server for mutation testing was found.

## Findings

### Track 1: JIT Testing Taxonomy and Practices

#### F1: "JIT testing" decomposes into four distinct practices with separate literatures
- **Claim**: There is no single coherent "JIT testing" field. At least four distinct practices are labeled JIT or are JIT-adjacent: (1) JIT test generation (LLM-based, per-change), (2) JIT test selection / RTS (choose which tests to run), (3) JIT defect prediction / JIT-DP (predict commit risk), (4) Test Case Prioritization in CI / TCP-CI (reorder tests). Each has its own benchmarks, venues, and tooling. Only variant 1 uses "JIT" as a self-applied label in recent work.
- **Evidence**: Practitioner Donald Firesmith (2024) solicited definitions of JIT testing because he "hasn't been able to find a good definition of the term that is clear, unambiguous." Academic literature confirms four separate fields with distinct founding papers.
- **Source**: https://www.linkedin.com/pulse/what-just-in-time-jit-testing-donald-firesmith
- **Confidence**: HIGH
- **Version/Date**: 2024-2026 literature survey
- **Potential assumption**: No

#### F2: Meta's TestGen-LLM operates at class level, not per-change
- **Claim**: Meta's TestGen-LLM (FSE '24) improves existing test classes with LLM-generated tests; its published scope is per-class, not per-commit. 73% of TestGen-LLM recommendations were accepted for production; it improved 11.5% of all classes it was applied to. The per-change JIT positioning comes from later Meta work (ACH for mutation, JiTTests blog 2026).
- **Evidence**: Abstract: "improved 11.5% of all classes to which it was applied" with "73% of its recommendations being accepted for production deployment."
- **Source**: https://arxiv.org/abs/2402.09171
- **Confidence**: HIGH
- **Version/Date**: FSE 2024
- **Potential assumption**: No

#### F3: LLM test generation regresses under code evolution
- **Claim**: LLM-generated tests fail to detect regressions when re-run after semantic-altering changes. Pass rate drops to 66% under semantic-altering changes, and "more than 99% of failing SAC tests pass on the original program while executing the modified region." Tests are coupled to the code snapshot they were generated against.
- **Evidence**: Haroon et al., 8 LLMs tested across 22,374 program variants. "Current LLM-based test generation relies heavily on surface-level cues and struggles to maintain regression awareness as programs evolve."
- **Source**: https://arxiv.org/abs/2603.23443
- **Confidence**: HIGH
- **Version/Date**: March 2026
- **Potential assumption**: No

#### F4: Meta's Predictive Test Selection (2019) is the canonical industry RTS deployment
- **Claim**: Facebook/Meta's ML-based test selection cuts total testing infrastructure cost by a factor of 2 while maintaining >95% test-failure recall and >99.9% faulty-change recall. It trains on historical test outcomes, not static code analysis.
- **Evidence**: Abstract: "reduces the total infrastructure cost of testing code changes by a factor of two" while "over 95% of individual test failures and over 99.9% of faulty changes are still reported." Production deployment since 2018.
- **Source**: https://arxiv.org/abs/1810.05286, https://engineering.fb.com/2018/11/21/developer-tools/predictive-test-selection/
- **Confidence**: HIGH
- **Version/Date**: ICSE-SEIP 2019
- **Potential assumption**: No

#### F5: JIT-DP is a mature research field (Kamei 2013) with 4 documented open problems
- **Claim**: JIT Defect Prediction was formalized by Kamei et al. IEEE TSE 2013. A 2023 ACM CSUR systematic review covers 67 JIT-DP studies. Four canonical open problems remain: (1) label delay (bug labels arrive 1 day to 11 years after commit), (2) concept drift, (3) class imbalance, (4) black-box opacity. The 2024 state of the art (BiCC-BERT, JIT-Smart) uses bi-modal transformers over code+commit messages.
- **Evidence**: Kamei abstract: "we propose defect prediction models that focus on identifying defect-prone software changes instead of files or packages." Survey covers 67 studies. BiCC-BERT: "10.8% improvement in F1-score" over prior SOTA on 27,391 code changes.
- **Source**: https://ieeexplore.ieee.org/document/6341763/, https://dl.acm.org/doi/abs/10.1145/3567550, https://arxiv.org/abs/2410.12107
- **Confidence**: HIGH
- **Version/Date**: Kamei 2013; survey 2023; SOTA 2024
- **Potential assumption**: No

#### F6: No confirmed production deployment of JIT-DP as a blocking CI gate
- **Claim**: Industry tools (Amazon CodeGuru, Microsoft AI Code Defect, CodeScene, Teamscale) use defect-prediction signals advisorily, but no primary source confirms a production blocking gate that runs a JIT-DP model per commit to block merges.
- **Evidence**: JIT survey literature cites defect-prediction-adjacent tools but no documented hard-gate deployment. Contrast with Meta's Predictive Test Selection (F4), which is both blocking and published.
- **Source**: https://damevski.github.io/files/report_CSUR_2022.pdf (UNFETCHED — cited via search results)
- **Confidence**: MEDIUM
- **Version/Date**: 2022-2024
- **Potential assumption**: Yes — absence of published deployment is not proof none exists

#### F7: History-based test prioritization beats coverage-based on long-running suites
- **Claim**: On 10 large OSS projects across 21,255 CI builds (57,437 test-suite runs), the ISSTA 2024 study found that "prioritizing faster tests that recently failed performs the best, outperforming the sophisticated [coverage-based] techniques." Simple heuristics beat ML for long-running suites.
- **Evidence**: Paper title and finding: "Revisiting Test Case Prioritization on Long-Running Test Suites" — LRTS dataset across real Jenkins CI.
- **Source**: https://2024.issta.org/details/issta-2024-papers/50/Revisiting-Test-Case-Prioritization-on-Long-Running-Test-Suites
- **Confidence**: HIGH
- **Version/Date**: ISSTA 2024
- **Potential assumption**: No

### Track 2: Mutation Testing Foundations

#### F8: Mutation testing rests on two hypotheses from DeMillo, Lipton, Sayward (1978)
- **Claim**: The Competent Programmer Hypothesis ("programmers write programs close to being correct" — behaviorally) and the Coupling Effect ("simple faults couple to emergent complex faults") together justify why killing first-order mutants yields high-quality test suites. Both hypotheses were empirically re-evaluated in 2024 and remain foundational.
- **Evidence**: Original paper: DeMillo, Lipton, Sayward, "Hints on test data selection: Help for the practicing programmer," IEEE Computer 11(4):34-41, 1978.
- **Source**: https://en.wikipedia.org/wiki/Mutation_testing, https://onlinelibrary.wiley.com/doi/full/10.1002/stvr.1874 (UNFETCHED - 403)
- **Confidence**: HIGH
- **Version/Date**: 1978 origin; 2024 re-evaluation
- **Potential assumption**: No

#### F9: Mutation mechanics: operators → mutants → kill/survive → score
- **Claim**: Mutation testing applies syntactic transformation rules (operators) to produce program variants (mutants). Each mutant is executed against the test suite: if any test fails, the mutant is "killed"; otherwise "survives." Mutation score = killed / total-non-equivalent. Offutt et al. empirically established that 5 operators (ABS, UOI, LCR, AOR, ROR) emulate the full operator set at 99.5% effectiveness.
- **Evidence**: Standard operator taxonomy documented in the Major framework docs. Offutt's selective mutation paper: 5-operator set "found to be very effective."
- **Source**: https://mutation-testing.org/docs.html
- **Confidence**: HIGH
- **Version/Date**: Offutt 1993-1996; Major current 2024
- **Potential assumption**: No

#### F10: The equivalent mutant problem is the dominant practical barrier
- **Claim**: Equivalent mutants (syntactically different, semantically identical to original) represent 4-39% of generated mutants depending on language and operator set. Trivial Compiler Equivalence (TCE) automatically detects ~21% of C and ~5.4% of Java equivalent mutants. LLM-based detection achieves F1=86.58% (precision 94.33%, recall 81.81%), improving over TCE by ~75% in F1 for Java.
- **Evidence**: Empirical studies consistently report the 4-39% range. TCE: "TCE is surprisingly effective, being able to identify at least 30% of all the equivalent mutants" (average 21% C, 5.4% Java). LLM study uses fine-tuned UniXCoder.
- **Source**: https://ieeexplore.ieee.org/document/7194639/, https://arxiv.org/html/2408.01760v1
- **Confidence**: HIGH (TCE, LLM F1); MEDIUM (4-39% range — context-dependent)
- **Version/Date**: TCE 2015; LLM 2024
- **Potential assumption**: Yes — the 4-39% range collapses language and operator differences

#### F11: LLM-generated mutants outperform rule-based tools on fault detection
- **Claim**: Comprehensive TOSEM 2024/2025 study: LLMs achieve 87.98% fault detection vs 41.64% for rule-based. Best model (DeepSeek-V3) hit 91.1% vs PIT at 40.1%. Tradeoffs: LLM mutants have worse compilability (62.5-77.6% vs PIT 100%), more duplicates, and 3.51 pp higher equivalent-mutant rate.
- **Evidence**: Direct from paper: "87.98% (for LLMs) vs. 41.64% (for rule-based)" fault detection; "LLMs generate more diverse mutants, that are behaviorally closer to real bugs."
- **Source**: https://arxiv.org/abs/2406.09843
- **Confidence**: HIGH
- **Version/Date**: 2024-2025
- **Potential assumption**: No

#### F12: Meta's ACH combines LLM mutations + LLM tests at production scale (FSE '25)
- **Claim**: Meta's Automated Compliance Hardening (ACH) system ran on 10,795 Android Kotlin classes across 7 platforms. Generated 9,095 mutants and 571 privacy-hardening tests. Engineer acceptance: 73%. LLM-based equivalent mutant detection: precision 0.79 / recall 0.47 baseline → 0.95 / 0.96 after preprocessing. Finding: 61% of equivalent mutants differed only by non-executable comments — trivially filterable.
- **Evidence**: Direct from FSE 2025 Industry paper. Trial Oct-Dec 2024 across Facebook, Instagram, WhatsApp, Meta wearables.
- **Source**: https://arxiv.org/abs/2501.12862, https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/
- **Confidence**: HIGH
- **Version/Date**: FSE 2025; trial late 2024
- **Potential assumption**: No

#### F13: Google runs mutation testing at scale change-by-change, not whole-codebase
- **Claim**: Google's production mutation system operates during code review on changed lines only, with "arid node detection" to skip non-testable code. 24,000+ developers across 1,000+ projects used it; 82% of reported mutants with developer feedback were labeled productive. 16,935,148 mutants analyzed across 10 languages (TSE 2022).
- **Evidence**: Paper: "used by more than 24,000 developers on more than 1,000 projects... 82% of all reported mutants with feedback were labeled as productive by developers." Whole-codebase mutation would be infeasible at Google's "two billion lines of code."
- **Source**: https://arxiv.org/abs/2102.11378, https://ieeexplore.ieee.org/document/9524503/
- **Confidence**: HIGH
- **Version/Date**: IEEE TSE 2022
- **Potential assumption**: No

#### F14: Mutation testing adoption is low despite tooling maturity
- **Claim**: Survey of OSS developers (IEEE TSE 2024): 33.7% generate mutation coverage reports in builds; 34.6% define a minimum threshold; only 27.9% actually enforce a mutation score as a blocking build gate. A practitioner example cites 60x runtime overhead (30 s test suite → 30 min under mutation). "Mutation testing has not caught on as a standard practice in industry due to factors such as computational cost."
- **Evidence**: IEEE TSE 2024 survey of 104 OSS contributors. PIT's claim "can analyse in minutes what would take earlier systems days" — fast by historical but still costly in absolute terms.
- **Source**: https://ieeexplore.ieee.org/document/10472898/ (UNFETCHED), https://pitest.org/, https://javapro.io/2026/01/21/test-your-tests-mutation-testing-in-java-with-pit/
- **Confidence**: MEDIUM — single survey, 104 respondents; runtime figure is one project example
- **Version/Date**: 2024-2026
- **Potential assumption**: Yes — "27.9% enforce" does not generalize to all industry

### Track 3: Tooling Ecosystem and Integration Patterns

#### F15: Per-language mutation tools are actively maintained with machine-readable output
- **Claim**: As of April 2026, every major language has an actively maintained mutation tool with JSON-compatible output (native or via plugin). PIT v1.23.0 (Java, March 2026, XML/CSV native, JSON via `pitest-mutation-testing-elements-plugin` v0.7.1). StrykerJS (JS/TS, native JSON). Stryker.NET (.NET, native JSON). mutmut v3.5.0 (Python, Feb 2026, junitxml). cosmic-ray v8.4.6 (Python, April 2026). mutant (Ruby, requires commercial license for closed-source). cargo-mutants v27.0.0 (Rust, March 2026, native JSON with diffs). Infection PHP (`--logger-summary-json`, `--logger-gitlab`). Gremlins v0.6.0 (Go, Dec 2025, JSON). gomu v0.2.0 (Go, March 2026).
- **Evidence**: Release pages and README docs across all repos listed.
- **Source**: https://github.com/hcoles/pitest, https://github.com/stryker-mutator/stryker-js, https://github.com/boxed/mutmut, https://github.com/sixty-north/cosmic-ray, https://github.com/mbj/mutant, https://github.com/sourcefrog/cargo-mutants, https://infection.github.io, https://github.com/go-gremlins/gremlins, https://github.com/sivchari/gomu
- **Confidence**: HIGH
- **Version/Date**: April 2026
- **Potential assumption**: No

#### F16: Stryker mutation-testing-report-schema is the de facto cross-tool JSON standard
- **Claim**: The `stryker-mutator/mutation-testing-elements` JSON schema (`http://stryker-mutator.io/report.schema.json`) is consumed by StrykerJS, Stryker.NET, Stryker4s, and — via third-party plugin — PIT. It is not a formal external standard (not OASIS/ISO) but is the only cross-tool schema in use. Top-level required fields: `schemaVersion`, `thresholds` (high/low 0-100), `files`.
- **Evidence**: Schema published at `unpkg.com/mutation-testing-report-schema@VERSION`. Stryker dashboard accepts "all mutation testing frameworks that support the mutation testing report schema."
- **Source**: https://github.com/stryker-mutator/mutation-testing-elements, https://github.com/Wmaarts/pitest-mutation-testing-elements-plugin
- **Confidence**: HIGH
- **Version/Date**: In active use as of 2026
- **Potential assumption**: No

#### F17: Threshold-as-gate is the standard CI integration with three documented models
- **Claim**: Stryker (JS/.NET/4s) uses a three-level threshold model: `{high, low, break}` — build fails below `break`. Infection PHP uses `--min-msi` and `--min-covered-msi`. PIT GitHub Action exposes a single `threshold` parameter. Gremlins and gomu expose single-threshold gates. cargo-mutants has no numeric threshold — any surviving mutant fails the build by default.
- **Evidence**: Documentation across tools. Stryker example: `thresholds: { high: 80, low: 60, break: 50 }`.
- **Source**: https://stryker-mutator.io/, https://infection.github.io/guide/command-line-options.html, https://github.com/marketplace/actions/pitest-report, https://gremlins.dev
- **Confidence**: HIGH
- **Version/Date**: 2024-2026
- **Potential assumption**: No

#### F18: Diff-scoped mutation is supported across 5+ tools with documented accuracy caveats
- **Claim**: StrykerJS `--incremental` stores baseline in `reports/stryker-incremental.json` (94% reuse rate in one example; limitation: cannot detect changes outside mutated/test files). PIT `historyInputLocation`/`historyOutputLocation` — tool marks this "experimental." cargo-mutants `--in-diff FILE` accepts git diff directly. Infection PHP `--git-diff-lines` mutates only touched lines. gomu auto-detects changed files since last commit. All tools document that diff-scoped runs "can miss some problems that would be found by running mutants on the whole codebase."
- **Evidence**: Tool-specific documentation; accuracy caveats appear in each tool's incremental docs.
- **Source**: https://stryker-mutator.io/docs/stryker-js/incremental/, https://pitest.org/quickstart/incremental_analysis/, https://mutants.rs/pr-diff.html, https://infection.github.io/guide/command-line-options.html
- **Confidence**: HIGH
- **Version/Date**: 2024-2026
- **Potential assumption**: No

#### F19: cargo-mutants publishes the most explicit PR-diff CI workflow
- **Claim**: cargo-mutants docs provide a complete reusable GitHub Actions workflow: checkout with `fetch-depth: 0` → `git diff origin/${{ github.base_ref }}.. | tee git.diff` → `cargo mutants --no-shuffle -vV --in-diff git.diff` → archive `mutants.out`. This is the cleanest published template; other tools require composition from generic pieces.
- **Evidence**: Official docs at `mutants.rs/pr-diff.html`.
- **Source**: https://mutants.rs/pr-diff.html
- **Confidence**: HIGH
- **Version/Date**: cargo-mutants v27.0.0, March 2026
- **Potential assumption**: No

#### F20: Atlassian Rovo Dev + PIT is the only publicly documented AI-tool + mutation integration
- **Claim**: Atlassian's Rovo Dev CLI uses MCP tools to parse PITest XML reports, target mutants labeled `NO_COVERAGE` or `SURVIVED`, write new tests to kill them, re-run Pitest, iterate to threshold, and open a PR. No equivalent published workflow exists for Claude Code, Cursor, Windsurf, Aider, or OpenCode. No open-source Claude Code skill or MCP server for mutation testing was found.
- **Evidence**: Atlassian blog post documenting the full workflow. Search across claude-code/skills, Cursor/Windsurf ecosystems returned no equivalents.
- **Source**: https://www.atlassian.com/blog/atlassian-engineering/rovo-dev-cli-and-mutation-testing-to-write-better-tests
- **Confidence**: HIGH
- **Version/Date**: 2025
- **Potential assumption**: No

#### F21: mutahunter is the only openly-available LLM-based, language-agnostic mutation tool (pre-release)
- **Claim**: `codeintegrity-ai/mutahunter` is open-source (AGPL-3.0), uses external LLM APIs (OpenAI GPT-4o demonstrated), and self-describes as language-agnostic. 295 stars, no versioned releases, Java is the only documented example language. Breadth of actual language support is unverified.
- **Evidence**: Repo inspection. No GitHub Releases published. 126 commits on main. Example invocation: `--model "gpt-4o-mini"`.
- **Source**: https://github.com/codeintegrity-ai/mutahunter
- **Confidence**: HIGH (repo facts); MEDIUM (language-agnostic claim is unverified)
- **Version/Date**: April 2026
- **Potential assumption**: Yes — "language-agnostic" is a maintainer claim

### Track 4: Arxiv Paper Verification (2601.22832)

#### F22: Paper is VERIFIED as "Just-in-Time Catching Test Generation at Meta" (Harman et al., FSE '26)
- **Claim**: The user-cited URL `https://arxiv.org/pdf/2601.22832` resolves to a real paper: "Just-in-Time Catching Test Generation at Meta" by Matthew Becker, Yifei Chen, Nicholas Cochran, Pouyan Ghasemi, Abhishek Gulati, Mark Harman, Zachary Haluza, Mehrdad Honarkhah, Herve Robert, Jiacheng Liu, Weini Liu, Sreeja Thummala, Xiaoning Yang, Rui Xin, Sophie Zeng. Submitted 2026-01-30. Accepted at FSE Companion '26 (34th ACM International Conference on Foundations of Software Engineering, June 2026, Montreal). Keywords: Unit Tests, Automated Testing, LLMs, Test Oracles. CC-BY 4.0.
- **Evidence**: arxiv metadata page retrieved successfully; PDF 689.5 KB, 18 pages.
- **Source**: https://arxiv.org/abs/2601.22832
- **Confidence**: HIGH
- **Version/Date**: v1, January 2026
- **Potential assumption**: No

#### F23: Paper's core concept — "catching tests" vs "hardening tests"
- **Claim**: The paper defines **catching tests** as LLM-generated tests intentionally designed to fail in order to surface bugs before code lands. This contrasts with traditional **hardening tests** which pass at generation time. Catching tests are a new category of automated tests specific to the JIT workflow — not a relabel of mutation testing.
- **Evidence**: Abstract verbatim: "Unlike traditional hardening tests, which pass at generation time, catching tests are meant to fail, surfacing bugs before code lands."
- **Source**: https://arxiv.org/abs/2601.22832
- **Confidence**: HIGH
- **Version/Date**: v1
- **Potential assumption**: No

#### F24: Paper's primary results — change-aware generation, LLM assessor filtering, true-positive yield
- **Claim**: Across 22,126 generated tests: code-change-aware methods improve candidate catch generation 4x over hardening tests and 20x over coincidentally failing tests. Rule-based + LLM-based assessors reduce human review load by 70%. Of 41 candidate catches reported to engineers, 8 were confirmed true positives; 4 of those would have caused serious production failures.
- **Evidence**: Abstract verbatim.
- **Source**: https://arxiv.org/abs/2601.22832
- **Confidence**: HIGH
- **Version/Date**: v1
- **Potential assumption**: No

#### F25: Paper does NOT address mutation testing in its abstract or keywords
- **Claim**: The paper's abstract and keywords ("Unit Tests, Automated Testing, LLMs, Test Oracles") contain no mention of mutation testing. If the user's design intent is JIT + mutation testing together, this paper is not the combined-practice reference. The closest combined-practice reference is Meta's ACH system (F12, arXiv 2501.12862), which is mutation-guided LLM test generation.
- **Evidence**: Keyword and abstract inspection. The 18-page body was not parsed, so mutation discussion could exist beyond the abstract (flagged as open question).
- **Source**: https://arxiv.org/abs/2601.22832
- **Confidence**: HIGH (absence at abstract/keyword level)
- **Version/Date**: v1
- **Potential assumption**: Yes — full body not parsed; mutation content may exist deeper in the paper

## Conflicts & Agreements

- **"JIT testing" terminology conflict (Track 1 vs Track 4)**: The user's paired framing "JIT & Mutation testing" does not match the literature. The referenced paper (F22-F25) uses "JIT" to mean change-triggered test generation for catching tests, and does not combine with mutation testing. If the design goal is JIT+mutation together, Meta's ACH system (F12) is the better reference — it is mutation-guided LLM test generation at scale.
- **LLM mutation vs LLM JIT test generation — different objectives**: Mutation testing (F8-F14) measures test-suite strength via surviving mutants. JIT catching test generation (F22-F24) generates tests that fail on the current code. These are adjacent but distinct practices: one audits an existing suite, the other generates new tests per change. Meta's ACH bridges them by using mutants to seed test-generation prompts.
- **Diff-scoped mutation tradeoff (Track 2 F13 + Track 3 F18-F19)**: Google demonstrates change-scoped mutation is the only way to run mutation at industrial scale, and StrykerJS/PIT/cargo-mutants/Infection/gomu all implement it. But every tool explicitly warns that diff-scoped runs miss some cross-cutting defects. This is a known, quantified tradeoff.
- **Adoption gap (F14 + F20 + F21)**: Mutation testing has mature per-language tools (F15) and a cross-tool JSON standard (F16), yet only ~28% of OSS projects gate on it (F14). Integration with AI coding tools exists in exactly one public case (Atlassian Rovo + PIT, F20). mutahunter is pre-release (F21). The practice is technically mature but the AI-tooling bridge is thin.
- **History-based heuristics vs ML (F7 + F4)**: ISSTA 2024 found simple "recently-failed-first" beats ML for long-running test prioritization. Meta's Predictive Test Selection (F4) is ML-based and produces strong results — but for test *selection* (discard unnecessary), not prioritization (reorder). These are compatible findings: different problems, different optimal approaches.

## Open Questions

1. **Does the user intend JIT+mutation as a single combined practice, or as two separate verify-phase capabilities?** The cited arxiv paper (F22) is JIT test generation only. Meta's ACH (F12) is the combined practice. This affects the scope of any design.
2. **Which of the four JIT variants (F1) is the target?** Verify-phase integration differs substantially: per-change test generation (F22, F12), test selection (F4), defect prediction (F5-F6), or prioritization (F7).
3. **Full body of arxiv 2601.22832 (18 pages) was not parsed.** Methodology, tool references, and any mutation-testing discussion beyond the abstract are unverified.
4. **Kamei 2013 citation count** ("~2500+" claimed in prior briefs) not independently verified — Semantic Scholar unreachable in this session.
5. **JIT-DP production blocking deployment**: No primary source confirms any major organization runs JIT-DP as a blocking CI gate. Does one exist?
6. **No Claude Code skill or MCP server for mutation testing was found** (F20). Is there one being built privately? Anthropic's own internal testing practices are not public.
7. **TCE figures (21% C, 5.4% Java) are from 2015** (F10). What is the current state of automated equivalent-mutant detection for TypeScript, Python, Kotlin, Go?
8. **Runtime cost benchmarks**: No authoritative published benchmarks for mutation testing wall-clock on modern medium codebases (~50k LOC). The 60x figure (F14) is one project anecdote.
9. **Does cosmic-ray support diff-based or incremental mutation**? Not documented in search results.
10. **Are there PR annotation standards for mutation output** beyond Stryker dashboard and the PIT-specific `pitest-report` Action?
11. **ACM TOSEM Jan 2026 "JIT-QA"** (doi:10.1145/3779653, UNFETCHED) combines defect prediction + test generation — may be an emergent fifth JIT variant.

## Source Index

### Primary papers
- Harman et al., JIT Catching Test Generation at Meta (FSE '26): https://arxiv.org/abs/2601.22832
- Foroutan et al., ACH mutation-guided LLM test gen at Meta (FSE '25): https://arxiv.org/abs/2501.12862
- Meta TestGen-LLM (FSE '24): https://arxiv.org/abs/2402.09171
- Meta Predictive Test Selection (ICSE-SEIP '19): https://arxiv.org/abs/1810.05286
- Google Practical Mutation Testing at Scale (TSE '22): https://arxiv.org/abs/2102.11378
- Kamei et al. JIT-DP founding (TSE '13): https://ieeexplore.ieee.org/document/6341763/
- JIT-DP systematic survey (ACM CSUR '23): https://dl.acm.org/doi/abs/10.1145/3567550
- Comprehensive LLM Mutation Study (TOSEM '24/'25): https://arxiv.org/abs/2406.09843
- LLM Equivalent Mutant Detection: https://arxiv.org/html/2408.01760v1
- LLMorpheus JS mutation: https://arxiv.org/abs/2404.09952
- BiCC-BERT JIT-DP (2024): https://arxiv.org/abs/2410.12107
- LLM test gen under code evolution (2026): https://arxiv.org/abs/2603.23443
- TCP on long-running suites (ISSTA '24): https://2024.issta.org/details/issta-2024-papers/50/Revisiting-Test-Case-Prioritization-on-Long-Running-Test-Suites

### Tools
- PIT: https://github.com/hcoles/pitest | https://pitest.org/
- Stryker (JS/.NET/4s): https://stryker-mutator.io/
- Stryker report schema: https://github.com/stryker-mutator/mutation-testing-elements
- cargo-mutants: https://mutants.rs/ | https://mutants.rs/pr-diff.html
- mutmut: https://github.com/boxed/mutmut
- cosmic-ray: https://github.com/sixty-north/cosmic-ray
- mutant (Ruby): https://github.com/mbj/mutant
- Infection PHP: https://infection.github.io
- Gremlins (Go): https://github.com/go-gremlins/gremlins
- gomu (Go): https://github.com/sivchari/gomu
- avito-tech/go-mutesting: https://github.com/avito-tech/go-mutesting
- mutahunter: https://github.com/codeintegrity-ai/mutahunter

### Industry and integrations
- Meta ACH engineering blog: https://engineering.fb.com/2025/09/30/security/llms-are-the-key-to-mutation-testing-and-better-compliance/
- Meta Predictive Test Selection blog: https://engineering.fb.com/2018/11/21/developer-tools/predictive-test-selection/
- Atlassian Rovo Dev + PIT: https://www.atlassian.com/blog/atlassian-engineering/rovo-dev-cli-and-mutation-testing-to-write-better-tests
- Launchable predictive test selection: https://www.launchableinc.com/docs/features/predictive-test-selection/
- Chromium RTS: https://chromium.googlesource.com/infra/luci/luci-go/+/0ceab97fd301/rts/README.md

### Terminology & background
- Firesmith on JIT testing ambiguity: https://www.linkedin.com/pulse/what-just-in-time-jit-testing-donald-firesmith
- Mutation Testing (Wikipedia): https://en.wikipedia.org/wiki/Mutation_testing
- Major mutation framework: https://mutation-testing.org/docs.html
