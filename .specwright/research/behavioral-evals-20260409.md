# Research Brief: Behavioral Assessment with Evals

Topic-ID: behavioral-evals
Created: 2026-04-09
Updated: 2026-04-09
Tracks: 3

## Summary

Research into how eval systems should assess behavior, not just end-state artifacts, across prompts, workflows, and agents. The consistent pattern across OpenAI and Anthropic guidance is that behavioral assessment should be multidimensional, task-specific, automated where possible, and aimed at the actual nondeterministic points in the system: step outputs, tool choice, argument accuracy, handoffs, and edge-case handling.

## Findings

### Track 1: What "behavioral assessment" means

#### F1: Behavioral quality should be defined with explicit multidimensional success criteria, not a single score
- **Claim**: Behavioral assessment is expected to cover several dimensions at once, such as task fidelity, consistency, context use, latency, and price, rather than rely on one aggregate notion of "good behavior."
- **Evidence**: Anthropic's success-criteria guidance lists task fidelity, consistency, relevance/coherence, tone/style, privacy preservation, context utilization, latency, and price, and says most use cases need multidimensional evaluation. OpenAI likewise says evals should combine metrics with human judgment rather than rely on a single score.
- **Source**: https://docs.anthropic.com/en/docs/empirical-performance-evaluations, https://platform.openai.com/docs/guides/evaluation-best-practices
- **Confidence**: HIGH
- **Version/Date**: Anthropic docs crawled 2025; OpenAI docs crawled 2026
- **Potential assumption**: No

#### F2: Behavioral eval sets should mirror real task distributions and include edge and adversarial cases
- **Claim**: Strong behavioral evals are task-specific and should include typical, edge, and adversarial cases drawn from realistic distributions and production traffic when available.
- **Evidence**: OpenAI recommends task-specific evals that reflect real-world distributions, mining logs for cases, and ensuring datasets include typical, edge, and adversarial scenarios. Anthropic says evals should mirror real-world task distribution and explicitly include edge cases.
- **Source**: https://platform.openai.com/docs/guides/evaluation-best-practices, https://docs.anthropic.com/en/docs/test-and-evaluate/develop-tests
- **Confidence**: HIGH
- **Version/Date**: OpenAI docs crawled 2026; Anthropic docs crawled 2025
- **Potential assumption**: No

#### F3: Behavioral regressions should be re-run continuously against the same case set as prompts and code change
- **Claim**: A mature eval process re-runs the same behavioral cases across prompt/code versions and grows the case set over time from observed failures.
- **Evidence**: OpenAI recommends continuous evaluation on every change and growing eval sets from observed nondeterminism. Anthropic's evaluation tool explicitly supports re-running the same test suite after prompt changes and comparing versions side by side.
- **Source**: https://platform.openai.com/docs/guides/evaluation-best-practices, https://platform.claude.com/docs/en/test-and-evaluate/eval-tool
- **Confidence**: HIGH
- **Version/Date**: OpenAI docs crawled 2026; Anthropic docs crawled 2025
- **Potential assumption**: No

### Track 2: How to grade behavior reliably

#### F4: The preferred grading order is code-based first, then LLM-based when validated, with humans used for calibration or high-nuance cases
- **Claim**: For behavioral assessment, providers recommend choosing the fastest reliable grader: code-based checks first, human review only when necessary, and LLM-based grading once reliability is established.
- **Evidence**: Anthropic explicitly ranks code-based grading as fastest and most reliable, human grading as highest quality but slow, and LLM-based grading as scalable once tested for reliability. OpenAI similarly recommends automation where possible and calibrating automated scoring with human judgment.
- **Source**: https://docs.anthropic.com/en/docs/test-and-evaluate/develop-tests, https://platform.openai.com/docs/guides/evaluation-best-practices
- **Confidence**: HIGH
- **Version/Date**: Anthropic docs crawled 2025; OpenAI docs crawled 2026
- **Potential assumption**: No

#### F5: LLM judges are more reliable when behavioral questions are turned into pass/fail, pairwise, classification, or rubric-guided scoring tasks
- **Claim**: LLM-as-judge is strongest when used for structured comparisons or explicit rubric checks rather than unconstrained qualitative judgment.
- **Evidence**: OpenAI recommends pairwise comparison, pass/fail, classification, and clear detailed rubrics, and warns about position and verbosity bias. Anthropic recommends empirical/specific rubrics and binary or bounded-scale outputs for scalable grading.
- **Source**: https://platform.openai.com/docs/guides/evaluation-best-practices, https://docs.anthropic.com/en/docs/test-and-evaluate/develop-tests
- **Confidence**: HIGH
- **Version/Date**: OpenAI docs crawled 2026; Anthropic docs crawled 2025
- **Potential assumption**: No

#### F6: Side-by-side comparisons are a first-class way to detect behavioral improvement or regression
- **Claim**: Comparing two prompt or system versions over the same cases is an endorsed pattern for spotting behavior changes quickly.
- **Evidence**: Anthropic's Evaluation tool documents side-by-side comparison, quality grading, and prompt versioning as built-in ways to compare outputs over the same test cases.
- **Source**: https://platform.claude.com/docs/en/test-and-evaluate/eval-tool
- **Confidence**: MEDIUM
- **Version/Date**: Anthropic docs crawled 2025
- **Potential assumption**: No

### Track 3: Which behaviors matter in workflows and agents

#### F7: Workflow behavior should be evaluated both per-step and at final outcome
- **Claim**: In multi-step workflows, the correct behavioral target is not only the final answer; each intermediate model step is also an evaluation surface.
- **Evidence**: OpenAI's workflow guidance says each step in a chained workflow can be evaluated in isolation, then also evaluated for final-response correctness.
- **Source**: https://platform.openai.com/docs/guides/evaluation-best-practices
- **Confidence**: MEDIUM
- **Version/Date**: OpenAI docs crawled 2026
- **Potential assumption**: No

#### F8: Agent behavior should explicitly evaluate tool selection and argument accuracy, not just output quality
- **Claim**: For agent architectures, behavioral assessment should cover whether the correct tool was chosen and whether arguments were extracted correctly from context.
- **Evidence**: OpenAI's single-agent guidance names tool selection and data precision as separate evaluation categories in addition to instruction following and functional correctness.
- **Source**: https://platform.openai.com/docs/guides/evaluation-best-practices
- **Confidence**: MEDIUM
- **Version/Date**: OpenAI docs crawled 2026
- **Potential assumption**: No

#### F9: Multi-agent and long-context behavior should be stress-tested with ambiguous tool outputs, conflicting instructions, and handoff complexity
- **Claim**: Important behavioral failure cases include multiple intents, short/ambiguous context, long context, ambiguous tool-return fields, multiple tool calls, and multi-agent handoff loops.
- **Evidence**: OpenAI's edge-case guidance explicitly lists short ambiguous requests, long context, ambiguous tool outputs, multiple tool calls, and multiple agent handoffs as reliability risks that require evaluation.
- **Source**: https://platform.openai.com/docs/guides/evaluation-best-practices
- **Confidence**: MEDIUM
- **Version/Date**: OpenAI docs crawled 2026
- **Potential assumption**: No

## Conflicts & Agreements

**Agreement — behavioral evals must be empirical and task-specific:** OpenAI and Anthropic both reject vague or generic evaluation. Both emphasize explicit success criteria, realistic test sets, and automation where possible.

**Agreement — a single behavioral metric is insufficient:** Both sources treat quality as multi-axis. OpenAI stresses architecture-specific nondeterminism surfaces; Anthropic stresses success criteria such as task fidelity, consistency, context use, latency, and price.

**Agreement — structured grading beats open-ended judging:** Both sources favor code checks, pairwise comparisons, pass/fail outputs, or tight rubrics over loose qualitative scoring.

**Difference in emphasis:** OpenAI goes deeper on architecture-specific behavior targets for workflows, agents, and multi-agent systems. Anthropic goes deeper on prompt-iteration workflow, grader ordering, and side-by-side prompt comparison.

## Open Questions

1. No official source found a provider-endorsed pattern for asserting stage-by-stage artifact files across a local file-based agent harness like Specwright's `.specwright/work/...` tree.
2. No official source found a standard metric for "handoff quality" beyond decomposing it into structured sub-signals such as correctness, format compliance, tool choice, and state transitions.
3. The sources support LLM grading for nuanced behavior, but none prescribe a canonical threshold for acceptable judge agreement before scaling; that remains application-specific.
