# Stable Baseline Approaches for AI Agent CI Runs

**Topic:** stable-baseline-approaches-for-ai-agent-ci
**Date:** 2026-04-08
**Triggered by:** Unit 02b-2 field finding — first real `claude -p` smoke run shortcircuited (12/12 trials pass_rate=0). See `.specwright/work/legibility-recovery/units/02b-2-eval-baseline-ci/evidence/field-findings.md`.
**Question:** How do mature projects baseline non-deterministic AI agent runs in CI while keeping the suite fast, cheap, and stable enough to catch regressions?
**Confidence overall:** **HIGH** on the framework survey + Anthropic-specific patterns; **MEDIUM** on the determinism strategy comparison.

## Headline finding

**Anthropic's own `claude-code-action` (GitHub Action that ships Claude Code itself) has 28 test files. Zero of them invoke a real `claude` binary.** All are TypeScript unit tests of the action with mocks and fixtures. ([anthropics/claude-code-action/test](https://github.com/anthropics/claude-code-action/tree/main/test))

This is the production answer to "how do you test agent code in CI": don't run the live agent in CI. Test the code that wraps the agent at the unit layer with mocks; defer live agent verification to manual runs, nightly jobs, or human-in-the-loop review.

Anthropic separately ships an official **`skill-creator`** plugin at [anthropics/skills](https://github.com/anthropics/skills) that DOES test live skills, but it's explicitly **human-in-the-loop with parallel subagent runs and a viewer for manual review** — not CI-automated. Its testing pattern (Executor + Grader + benchmark.json) is ~80% the same shape as Specwright's existing eval framework, but it spawns subagents via the Task tool, not the live `claude -p` binary. ([Anthropic skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md))

The combination of these two facts is the recommendation: **don't try to test Claude's live compliance with output formats in PR-time CI.** Use static + fixture layers for CI; use subagent or viewer-based runs for periodic validation.

---

## Track 1 — Agent Eval Framework Survey

### Comparison

| Framework | Live model in CI? | Determinism strategy | Format checks separable from behavior checks? | Maturity | Notes |
|---|---|---|---|---|---|
| **[Promptfoo](https://github.com/promptfoo/promptfoo)** | Optional | Cache + cassettes + deterministic assertions | **Yes** — explicit split between "Deterministic Assertions" (regex, contains, JSON schema, custom code) and "Model-Assisted Assertions" (llm-rubric, similarity, factuality) | High — used by OpenAI and Anthropic per their README | Best CI story; declarative YAML; native GitHub Actions integration via `promptfoo eval --ci` |
| **[Inspect AI](https://inspect.aisi.org.uk/)** (UK AISI) | Yes | Scorer abstraction (text comparison, model grading, custom) | Yes — via Scorers component | High — 50+ contributors, used by govts/labs | More research-oriented than CI-oriented; CI integration not explicit in docs |
| **[LangSmith](https://docs.langchain.com/langsmith/evaluation-concepts)** | Yes (default) | Code evaluators ARE deterministic and free; LLM-as-judge for behavior | Yes — pytest/Vitest integration; deterministic code evals split from LLM-as-judge | High — LangChain ecosystem | Tightly coupled to LangChain; offline vs online split is documented |
| **[Anthropic skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md)** | Yes (subagent, not CLI) | Parallel subagent runs + grader + benchmark.json | Partial — grader is unified | Official Anthropic | Human-in-the-loop, not CI; closest analog to Specwright's existing pattern |

**Consensus pattern across all four:** every mature framework separates **deterministic assertions** (regex, equals, JSON schema, custom code) from **model-graded assertions** (LLM-as-judge, similarity, factuality). The deterministic layer runs in CI; the model-graded layer runs offline or in nightly jobs.

This is the same separation Specwright already implements between unit tests (with synthetic transcripts) and live invocations (with real claude). The gap isn't the philosophy — it's that Specwright tried to put live invocations in CI when no one else does.

### Per-framework detail

**Promptfoo** ([CI/CD docs](https://www.promptfoo.dev/docs/integrations/ci-cd/), [assertions docs](https://www.promptfoo.dev/docs/configuration/expected-outputs/)). The most CI-mature framework I found. Declarative YAML config; `promptfoo eval --ci` returns non-zero on regression. **Deterministic Assertions** include: `equals`, `contains`, `regex`, `is-json`, `contains-json`, `javascript`, `python`, `latency`, `cost`, BLEU/ROUGE/METEOR. **Model-Assisted Assertions** include: `llm-rubric`, `similar` (embeddings cosine), `factuality`, `answer-relevance`. Caching support exists. README explicitly says "Used by OpenAI and Anthropic." Confidence **HIGH**.

**Inspect AI** ([docs](https://inspect.aisi.org.uk/), [GitHub](https://github.com/UKGovernmentBEIS/inspect_ai)). Open-sourced by UK AISI in May 2024, widely adopted. Three core components: Datasets (labeled samples), Solvers (chained), Scorers (evaluate output). Scorers support text comparison, model grading, custom schemes — same split as Promptfoo. CI integration not prominent in docs; optimized for research evaluation rather than per-PR pipelines. Confidence **HIGH**.

**LangSmith** ([evaluation docs](https://docs.langchain.com/langsmith/evaluation-concepts), [CI integration blog](https://markaicode.com/langsmith-cicd-automated-regression-testing/)). pytest + Vitest integration native. **Code evaluators are deterministic and free** (per Analytics Vidhya 2025 review). Splits offline vs online evaluation explicitly. Dataset versioning lets CI pin to specific eval data versions. Best fit if already in LangChain ecosystem; less applicable elsewhere. Confidence **HIGH**.

**Anthropic skill-creator** ([SKILL.md on GitHub](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md), [agents/grader.md](https://github.com/anthropics/skills/blob/main/skills/skill-creator/agents/grader.md)). Ships an explicit Executor + Grader pattern with `evals/evals.json` schema, `agents/grader.md`, `agents/analyzer.md`, `scripts/aggregate_benchmark`, and an `eval-viewer/` web component for human review. Grader's prompt explicitly says "A passing grade on a weak assertion is worse than useless — it creates false confidence." The pattern is **manual + parallel + human-in-the-loop**, not CI. Tests "with-skill" against "baseline" (no-skill or previous-version) in parallel subagent runs. **This is the closest existing pattern to Specwright's eval framework, and Specwright already implements ~80% of it.** Confidence **HIGH**.

---

## Track 2 — Determinism Strategies for Agent CI

### Strategy comparison

| Strategy | Used by | CI cost | Catches | Misses | Maturity |
|---|---|---|---|---|---|
| **Cassette / VCR replay** | [vcrpy](https://vcrpy.readthedocs.io/), [pytest-recording](https://github.com/kiwicom/pytest-recording), [vcr-langchain](https://github.com/amosjyng/vcr-langchain), [baml_vcr](https://github.com/gr-b/baml_vcr) | Free after recording | Code-side regressions (changed prompts, logic bugs, parsing errors) | Model-side drift (model upgrades, sampling variance) | High — battle-tested for HTTP testing since 2010 |
| **Deterministic assertions** (regex, equals, JSON schema) | Promptfoo, LangSmith, Inspect AI scorers | Zero | Format violations, exact-match content drift | Semantic regressions | High |
| **Snapshot/golden file** | Jest community, [LangSmith dataset versioning](https://docs.langchain.com/langsmith/evaluation-concepts) | Zero | Output changes from baseline | Whether baseline itself was correct | High in software, medium in agent testing |
| **LLM-as-judge** | Promptfoo `llm-rubric`, LangSmith, [Anthropic grader](https://github.com/anthropics/skills/blob/main/skills/skill-creator/agents/grader.md) | High (judge is itself a model call) | Semantic regressions, soft criteria | Reproducibility (judge is also non-deterministic) | High |
| **Multi-trial median/mean** | Inspect AI, Specwright's existing aggregator | Linear in trials | Smooths random variance | Systemic shifts | Medium |
| **Structured output validation** (Pydantic, JSON schema) | Pydantic AI, Instructor, OpenAI structured outputs | Zero (after model call) | Format violations | Anything beyond shape | High |
| **Property-based testing** | [Anthropic property-based testing post](https://red.anthropic.com/2026/property-based-testing/) | Variable | Edge cases via generative inputs | Specific known failures | Medium for agent testing |

### Key finding for determinism

**The cassette/replay pattern is the only "stable + cheap + catches regressions" combination.** It works exactly the way the user has been advocating — record real behavior once, then run that behavior in CI without re-paying the model cost or facing the non-determinism. The tradeoff is that model-side drift (Anthropic ships a new model version, sampling changes) won't be caught by cassettes; you need a separate periodic re-record + diff to catch that.

vcrpy and pytest-recording are mature (used in production by many Python projects) and work with any HTTP-based API including Anthropic's. The Anthropic CLI uses HTTP under the hood, so cassette-based recording at the HTTP layer is theoretically possible — the question is whether the streaming JSON output complicates things in practice.

For **format-only verification** (the Specwright case), even cassettes are overkill. A static check on the SKILL.md prompt + a unit test on the grader's regex (which Specwright already has as `tests/test-handoff-template.sh` and `evals/tests/test_grader.py::TestCheckTranscriptFinalBlock`) is sufficient — no model invocation needed at any point.

---

## Track 3 — Format vs Behavior Testing Patterns

### The pattern exists and is widely recognized

**Yes** — every mature framework I surveyed separates these. The vocabulary varies:

- **Promptfoo:** "Deterministic Assertions" vs "Model-Assisted Assertions"
- **LangSmith:** "Code evaluators" vs "LLM-as-judge evaluators"
- **Inspect AI:** "Scorer" types include text-comparison, model-graded, custom
- **General ML eval literature:** "structural" vs "semantic" assertions

The pattern: **format = deterministic + cheap + CI-friendly. Behavior = model-graded + expensive + offline.**

### Patterns observed for the format layer specifically

| Pattern | What it tests | Live model? | Maturity for our case |
|---|---|---|---|
| **Regex on captured stdout** | Output structure, presence of expected strings | No (replay) or yes (live) | Already implemented in Specwright `transcript_final_block` |
| **JSON schema / structured output validation** | Output shape conforms to schema | No (post-hoc) | Strong fit if output is JSON; awkward for prose-with-format like the 3-line handoff |
| **Snapshot match** | Exact output equals saved snapshot | No (replay) | Brittle for non-deterministic prose |
| **Frontmatter / SKILL.md lint** | Skill metadata is valid | No (static) | Specwright already has `tests/test-claude-code-build.sh` |
| **Prompt-template lint (no model)** | The prompt itself contains the format constraint | No (static) | **No prior art found** — but the most promising new layer for Specwright |

### Recommendation for the Specwright case

The 3-line handoff format (`Done. ... / Artifacts: ... / Next: /sw-...`) needs verification at THREE static layers, all of which can run in CI without invoking a model:

1. **Protocol-side static check** — does `core/protocols/decision.md` document the format correctly? **Already covered** by `tests/test-handoff-template.sh`.
2. **Skill-side static check** — does each pipeline SKILL.md reference the format and not the old four-section template? **Already covered** by `tests/test-handoff-template.sh`.
3. **Grader function unit test** — does the `transcript_final_block` check function correctly recognize a valid handoff and reject a malformed one? **Already covered** by `evals/tests/test_grader.py::TestCheckTranscriptFinalBlockHappyPath` and `TestCheckTranscriptFinalBlockFailure` (22 unit tests).

**All three layers are already shipped on main.** The mistake in Unit 01 was treating "live verification" as a fourth layer that should also run in CI. The fourth layer doesn't belong in CI per any of the four mature frameworks I surveyed. The right place for it is offline / nightly / on-demand.

---

## Track 4 — Claude Code Specific Testing Patterns

### Anthropic's official guidance

Three sources, in order of authority:

**1. anthropics/claude-code-action ([test/ directory](https://github.com/anthropics/claude-code-action/tree/main/test))**
The GitHub Action that ships Claude Code itself. **28 test files. Zero invoke a real `claude` binary.** All are TypeScript unit tests of the action's logic with mocks and fixtures. Test directory includes `test/fixtures/` and `test/modes/` for fixture-based testing. Files include `comment-logic.test.ts`, `create-prompt.test.ts`, `data-fetcher.test.ts`, `permissions.test.ts`, `parse-permissions.test.ts`, `sanitizer.test.ts`, `integration-sanitization.test.ts`, etc. **The "integration" tests are integration AT THE TYPESCRIPT BOUNDARY, not at the live-model boundary.** Confidence **HIGH** — directly inspected the directory listing.

**2. anthropics/skills/skill-creator ([SKILL.md](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md))**
Anthropic's official meta-skill for creating skills. Documents an Executor + Grader test pattern. Key quote: *"Spawn parallel test runs — run both with-skill AND baseline in the same turn... grade each run by spawning a grader subagent that reads `agents/grader.md` and evaluates each assertion against the outputs."* Crucially, this uses **subagents (spawned Claude instances via Task tool), NOT the live `claude -p` binary**. The viewer provides human review with "prev/next navigation, collapsible formal grades, and a feedback textbox." This is **explicitly human-in-the-loop**, not CI. Confidence **HIGH** — fetched directly.

**3. agents/grader.md from skill-creator ([raw](https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/agents/grader.md))**
The grader prompt itself. Quote: *"A passing grade on a weak assertion is worse than useless — it creates false confidence."* The grader produces JSON with expectations (text + passed + evidence), summary (counts + pass_rate), execution_metrics (tool calls, steps, errors), timing, claims (extracted statements with verification status), and eval_feedback. **This is the same shape as Specwright's existing `grade_eval` output.** Confidence **HIGH** — fetched directly.

### Mock/stub patterns for the `claude` binary

I searched for prior art on mocking `claude` for testing skills. Found:

- Cassette/replay for HTTP-level recording (vcrpy and friends, but not `claude`-specific)
- The `skill-creator` pattern uses subagents rather than the binary, sidestepping the question
- One blog post ([Practical Guide to Evaluating and Testing Claude Code Skills](https://www.fabianmagrini.com/2026/03/practical-guide-to-evaluating-and.html)) describes the manual test pattern
- A [Medium article](https://medium.com/@karkeralathesh/the-complete-guide-to-testing-claude-code-skills-with-the-skill-creator-1ae3821bd7b8) describes the skill-creator workflow as 15 minutes per skill (5 min write evals + 5 min run + 5 min read feedback)

**No prior art found for stubbing the `claude` CLI binary as a PATH-mock.** This is a gap in the ecosystem.

### Recommendation for Specwright

Given:
- Specwright already has comprehensive static-layer coverage (`test-claude-code-build.sh` + `test-handoff-template.sh` + `transcript_final_block` unit tests)
- Anthropic's own action testing pattern uses zero live model calls
- The skill-creator pattern is human-in-the-loop, not CI

**The right architecture for Specwright's eval CI is:**

| Layer | Where it runs | Cost | What it catches |
|---|---|---|---|
| **Static markdown checks** (protocol + SKILL.md regex) | PR time, in `tests/test-*.sh` | Free | Doc/protocol drift |
| **Grader function unit tests** (synthetic transcripts) | PR time, in `evals/tests/test_grader.py` | Free | Grader logic regressions |
| **Workflow + script unit tests** | PR time, in `tests/test-eval-*.sh` | Free | CI plumbing regressions |
| **Cassette-based skill replay** (NEW — not yet built) | PR time, optional | Free after recording | Code-side regressions in skill behavior |
| **Subagent-based skill runs** (Anthropic skill-creator pattern, NEW) | Manual / nightly | High but fixed | Live skill format compliance |
| **Live `claude -p` end-to-end** | NEVER in PR-time CI | Variable, slow, non-deterministic | Reserved for manual integration runs |

The first three layers are **already shipped on main**. The remaining gap is layers 4 and 5, both of which can be added in a follow-up unit. The current workflow.json + scripts/ infrastructure from Unit 02b-2 is correct for layer 4 if we add cassettes or layer 5 if we adapt the skill-creator subagent pattern to a CI-runnable form.

---

## Synthesis: what to design next

### The problem restated

Specwright's pipeline-skill outputs need a regression check in CI. The first attempt invoked the live skill end-to-end and discovered live invocation is structurally infeasible (5+ min per run, shortcircuit on ambiguity, non-deterministic). The eval CI infrastructure (workflows, dispatch, baselines) is correct; the missing piece is a **CI-feasible test target**.

### The space of solutions

| Option | Pros | Cons | Cost to build |
|---|---|---|---|
| **A. Static layers only — no live testing in CI** | Already shipped; zero cost; zero false positives | No live verification ever happens unless someone runs it manually | Zero |
| **B. Cassette-based skill replay** | Catches code-side regressions cheaply; deterministic; CI-friendly | Doesn't catch model drift; HTTP recording for `claude` binary may be tricky | Medium (need to figure out the recording layer) |
| **C. Subagent-based runs (skill-creator pattern)** | Anthropic's own pattern; works against live agent; produces real evidence | Still slow (5+ min); still non-deterministic; needs human review per Anthropic's guidance | Medium-high (need to adapt skill-creator scripts) |
| **D. Hybrid: A in CI + C nightly** | Best coverage; matches Anthropic's split | Two separate systems to maintain | Medium |
| **E. Hybrid: A in CI + B nightly + C on demand** | Most comprehensive; covers all three failure modes (code, drift, semantic) | Most complex; three test surfaces | High |

### Recommendation

**Option D — A in CI + C nightly.** Rationale:

1. **A is already shipped.** Static layers exist on main. Don't undo them.
2. **B (cassettes) sounds clean but the `claude` binary's streaming JSON output likely makes HTTP-level recording brittle.** Worth a spike but not a blocker.
3. **C is Anthropic's own pattern.** Adapting skill-creator's Executor+Grader to a non-interactive CI mode is the lowest-risk way to add live verification. It's slow and expensive — so it goes nightly, not per-PR.
4. **D matches the universal "deterministic in CI, model-graded offline" split** from every mature framework I surveyed.

### What to do with Unit 02b-2

The current Unit 02b-2 ships:
- Eval CI workflows (eval-smoke.yml + eval-full.yml)
- Dispatch scripts (post-eval-comment.sh + eval-weekly-dispatch.sh)
- Baselines (skill, workflow, integration as stubs)
- Smoke filter infrastructure (zero entries currently tagged)
- Auth via `CLAUDE_CODE_OAUTH_TOKEN`

**This is the right infrastructure for Option D.** The smoke workflow can run static checks (option A) per-PR; the weekly workflow can run subagent-based skill verifications (option C) on a schedule. **Ship Unit 02b-2 as-is.** The next sub-unit's job is to populate the smoke workflow with static-layer checks (re-tag with cheap deterministic eval entries, NOT the broken live-invocation entries from Unit 01).

### Open questions for the design phase

1. **Should the existing `*-handoff-format` eval entries from Unit 01 be deleted?** They're broken and misleading. Either delete them outright or repurpose them as nightly subagent-based tests.
2. **What are the cheap deterministic smoke evals that DO belong in CI?** Candidates: skill structure validation, frontmatter completeness, protocol cross-reference integrity, eval suite schema validation. None invoke a model.
3. **Is the cassette layer (Option B) worth a spike?** Specifically: can `pytest-recording` or `vcrpy` capture and replay the `claude` binary's HTTP traffic?
4. **What's the determinism rubric for the C-layer (subagent runs)?** The original 02b-1 spec proposed pass_rate stddev > 0.1 OR duration stddev > 30%. Still valid, but applied to different test targets.

---

## References

### Tools and frameworks
- [Promptfoo](https://github.com/promptfoo/promptfoo) — declarative LLM eval with CI integration. ([CI/CD docs](https://www.promptfoo.dev/docs/integrations/ci-cd/), [assertions](https://www.promptfoo.dev/docs/configuration/expected-outputs/), [GitHub Action integration](https://www.promptfoo.dev/docs/integrations/github-action/))
- [Inspect AI](https://github.com/UKGovernmentBEIS/inspect_ai) — UK AISI eval framework with 100+ pre-built evals. ([docs](https://inspect.aisi.org.uk/), [evals](https://inspect.aisi.org.uk/evals/))
- [LangSmith](https://docs.langchain.com/langsmith/evaluation-concepts) — LangChain's eval platform with pytest/Vitest integration.

### Determinism / replay
- [vcrpy](https://vcrpy.readthedocs.io/) — HTTP record/replay for Python.
- [pytest-recording](https://github.com/kiwicom/pytest-recording) — pytest plugin powered by VCR.py.
- [vcr-langchain](https://github.com/amosjyng/vcr-langchain) — record/replay LangChain LLM interactions.
- [baml_vcr](https://github.com/gr-b/baml_vcr) — record LLM calls and play them back during tests.
- [Eliminating Flaky Tests: VCR for LLMs](https://anaynayak.medium.com/eliminating-flaky-tests-using-vcr-tests-for-llms-a3feabf90bc5) — Medium write-up.

### Anthropic-specific (highest authority for our case)
- [anthropics/claude-code-action](https://github.com/anthropics/claude-code-action) — the official GitHub Action.
- [anthropics/claude-code-action/test](https://github.com/anthropics/claude-code-action/tree/main/test) — 28 test files, zero invoke real claude.
- [anthropics/skills/skill-creator](https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md) — official meta-skill with Executor+Grader pattern.
- [anthropics/skills/skill-creator/agents/grader.md](https://raw.githubusercontent.com/anthropics/skills/main/skills/skill-creator/agents/grader.md) — grader prompt.
- [Anthropic property-based testing](https://red.anthropic.com/2026/property-based-testing/) — testing patterns research.
- [Practical Guide to Evaluating and Testing Claude Code Skills](https://www.fabianmagrini.com/2026/03/practical-guide-to-evaluating-and.html) — community guide.
- [The Complete Guide to Testing Claude Code Skills With the Skill Creator](https://medium.com/@karkeralathesh/the-complete-guide-to-testing-claude-code-skills-with-the-skill-creator-1ae3821bd7b8) — Medium walkthrough.

### Specwright internal references (for the design phase to consume)
- `.specwright/work/legibility-recovery/units/02b-2-eval-baseline-ci/evidence/field-findings.md` — the field finding that triggered this research
- `tests/test-handoff-template.sh` — existing static-layer coverage
- `evals/framework/grader.py::check_transcript_final_block` — existing grader function
- `evals/tests/test_grader.py::TestCheckTranscriptFinalBlock*` — existing grader unit tests
- `evals/framework/baseline.py` — existing baseline comparison logic from Unit 02b-1

## Confidence summary

| Track | Confidence | Notes |
|---|---|---|
| 1 — Framework survey | **HIGH** | Promptfoo / Inspect AI / LangSmith / skill-creator all confirmed via official docs |
| 2 — Determinism strategies | **MEDIUM-HIGH** | Cassette pattern is well-documented; some frameworks' specifics (Inspect non-determinism story) couldn't be confirmed from the docs I fetched |
| 3 — Format vs behavior | **HIGH** | The split is universal; Promptfoo's explicit naming makes it concrete |
| 4 — Claude Code specific | **HIGH** | Three primary sources fetched directly from anthropics repos |

### Sources I could not fetch (UNFETCHED)

- The full text of `agents/analyzer.md` from skill-creator (only inferred from SKILL.md references)
- The full Promptfoo caching docs (only sidebar reference observed)
- The `evals/evals.json` example schema from skill-creator (referenced but not fetched)
- Any specific Inspect AI CI integration docs (not prominent in the docs site I fetched)

These are gaps that the design phase may want to fill if specific implementation choices depend on them. None of them would change the headline finding.
