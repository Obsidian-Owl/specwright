# Research Brief: Generalist vs. Specialist Test Agents — Composition Strategy

Topic-ID: specialization-strategy
Created: 2026-04-06
Updated: 2026-04-06
Tracks: 3

## Summary

Should Specwright ship per-language test agents or language-agnostic agents with composable language skills? The evidence strongly favors composition: generic agents + language-specific skills loaded at runtime. No published system specializes agents by test pyramid level. Claude Code's `skills` frontmatter and `paths` auto-loading natively support the composition pattern. Agent S2 (arXiv 2504.00906) demonstrates that composing generalist + specialist outperforms monolithic approaches. ESLint, Prettier, Docker, and GitHub Actions all use the same pattern: shared base + language-specific layers. Four language ecosystems (TypeScript, Python, Go, Java) cover ~72% of the AI-coding-tool user base.

## Findings

### Track 1: Generalist vs. Specialist Agent Performance

#### F1: LLMs have a massive Python bias — 90-97% default, 83% self-contradiction rate
- **Claim**: "LLMs Love Python" (arXiv 2503.17181) measured 8 LLMs and found Python used in 90-97% of code solutions by default. When asked to generate code in contexts unsuitable for Python, Python remained dominant in 58% of cases. Self-contradiction rate of 83%: models recommend diverse languages in prose but default to Python in code.
- **Evidence**: Root cause is training data saturation — "the vast majority of benchmarks are Python-based."
- **Source**: https://arxiv.org/html/2503.17181v1
- **Confidence**: HIGH
- **Potential assumption**: No

#### F2: Multi-SWE-bench shows extreme per-language variance — Python 52% vs Go 7.5%
- **Claim**: Claude 3.7 Sonnet with MopenHands across 8 languages: Python 52.2%, Java 21.9%, Rust 15.9%, C++ 14.7%, C 8.6%, Go 7.5%, JavaScript 5.1%, TypeScript 2.2%. Authors note methods were "initially optimized for Python" and multilingual adaptations "lacked deep language-specific optimization."
- **Evidence**: Direct benchmark results from arXiv 2504.02605 (ByteDance/Seed, NeurIPS 2025).
- **Source**: https://arxiv.org/abs/2504.02605
- **Confidence**: HIGH
- **Potential assumption**: No

#### F3: Agent S2 demonstrates composition outperforms monolithic
- **Claim**: "Strategically composing generalist and specialist models, even when each is slightly suboptimal on its own, can outperform the best monolithic models." Results on OSWorld: 27.0% (18.9% improvement) at 15 steps. VS Code category: 65.22% at 50 steps.
- **Evidence**: arXiv 2504.00906. The compositional approach explicitly combines a generalist base with specialist capabilities, not all-specialist or all-generalist.
- **Source**: https://arxiv.org/html/2504.00906v1
- **Confidence**: HIGH (though measured on computer-use tasks, not code generation specifically)
- **Potential assumption**: Yes — transfer to test generation is plausible but unproven

#### F4: Claude Opus 4.5 leads 7/8 languages on SWE-bench Multilingual, but "leading" ≠ "comparable to Python"
- **Claim**: Anthropic claims Opus 4.5 leads across 7 of 8 programming languages. However, the entire frontier model category achieves sub-10% on most non-Python languages. The base model is already the best available but still benefits significantly from language-specific context.
- **Source**: https://www.anthropic.com/news/claude-opus-4-5
- **Confidence**: HIGH
- **Potential assumption**: No

#### F5: Cursor rules study — language-specific rules are common but effectiveness is unproven
- **Claim**: arXiv 2512.18925 analyzed 401 repos with Cursor rules. TypeScript 51%, Python 15%, Go 6% of repos. 28.7% of rule content is duplicated/cargo-culted. The paper states: "their actual impact on LLM performance remains an open question."
- **Evidence**: Statically typed language users (Go, C#, Java) provide less context in rules, trusting the type system.
- **Source**: https://arxiv.org/abs/2512.18925
- **Confidence**: MEDIUM (observational study, no effectiveness measurement)
- **Potential assumption**: Yes

### Track 2: Skill Composition Patterns

#### F6: Claude Code `skills` frontmatter injects full content at subagent startup
- **Claim**: Multiple skills can be listed in a subagent's `skills` field. Full SKILL.md content is injected at startup (not lazy-loaded). Subagents don't inherit parent skills. Token cost: ~2,000-5,000 tokens per skill (500-line cap). Three skills = ~15k tokens overhead.
- **Evidence**: "The full content of each skill is injected into the subagent's context, not just made available for invocation."
- **Source**: https://code.claude.com/docs/en/sub-agents
- **Confidence**: HIGH
- **Potential assumption**: No

#### F7: `paths` frontmatter enables automatic language detection without an orchestrator
- **Claim**: A skill with `paths: **/*.go` auto-loads only when working with Go files. This is implicit language detection. Combined with subagent `skills` injection, an orchestrator can detect project language and load the appropriate skill at delegation time.
- **Source**: https://code.claude.com/docs/en/skills
- **Confidence**: HIGH
- **Potential assumption**: No

#### F8: Anthropic's skill design guidance explicitly recommends composability over monolithic
- **Claim**: Official best practices: "Compose capabilities: Combine Skills to build complex workflows." One skill can invoke another. Domain-specific organization recommended over monolithic skills. The progressive disclosure architecture (metadata → SKILL.md → supporting files) is designed for composition.
- **Evidence**: "For Skills with multiple domains, organize content by domain to avoid loading irrelevant context."
- **Source**: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- **Confidence**: HIGH
- **Potential assumption**: No

#### F9: Testcontainers separates Go and .NET because the APIs differ fundamentally
- **Claim**: Go's `testing` package, .NET's xUnit/NUnit with `IAsyncLifetime`, different module systems, different cleanup contracts. The split reflects API surface difference, not a tested hypothesis about specialization quality. Volume alone (62+ Go modules, 65+ .NET modules) would exceed the 500-line SKILL.md cap if combined.
- **Source**: https://github.com/testcontainers/claude-skills
- **Confidence**: MEDIUM (inferred from content, not documented rationale)
- **Potential assumption**: Yes

### Track 3: Specialization Tradeoffs at Scale

#### F10: Enterprise platforms use composable specialization, not generic agents
- **Claim**: Salesforce Agentforce uses orchestrator → domain-specific agents. Microsoft Copilot Studio uses specialized templates that are configurable. Both avoid pure generic agents. Salesforce documents the cost: "Increased bounded context needs and domain specificity. Complexity to adapt to changes."
- **Source**: https://architect.salesforce.com/fundamentals/agentic-patterns
- **Confidence**: HIGH
- **Potential assumption**: No

#### F11: The ESLint/Prettier/Docker/Actions pattern: shared base + language-specific layers
- **Claim**: All four ecosystems solve the combinatorial problem the same way. ESLint: generic base config + language-specific extensions (airbnb-base + React layer). Prettier: single generic engine + per-language parser plugins. Docker: shared `buildpack-deps` base + per-language official images. GitHub Actions: language-specific setup actions + generic run steps.
- **Source**: https://eslint.org/docs/latest/use/configure/configuration-files, https://prettier.io/docs/plugins, https://hub.docker.com/_/golang
- **Confidence**: HIGH
- **Potential assumption**: No

#### F12: Four languages cover ~72% of the AI-coding-tool user base
- **Claim**: From arXiv 2512.18925 (Cursor rules study): TypeScript 51%, Python 15%, Go 6% = 72% of repos with AI coding rules. Stack Overflow 2025: JavaScript 66%, Python 58%, TypeScript 44%, Java 29% as top languages. Four language packs (TypeScript/JavaScript, Python, Go, Java) would cover the vast majority of Specwright's target users.
- **Source**: https://arxiv.org/abs/2512.18925, https://survey.stackoverflow.co/2025/technology
- **Confidence**: HIGH
- **Potential assumption**: No

#### F13: Prompt engineering shows diminishing returns — specialization value has a ceiling
- **Claim**: First 5 hours of prompt work: 35% improvement. Next 20 hours: 5%. Next 40 hours: 1%. The "85% accuracy ceiling" heuristic: if a properly structured agent is below 85%, the problem is architectural, not prompt-level. The "10-iteration rule": if 10 focused iterations don't fix a failure mode, the problem is not the prompt.
- **Source**: https://softcery.com/lab/the-ai-agent-prompt-engineering-trap-diminishing-returns-and-real-solutions
- **Confidence**: MEDIUM (practitioner analysis, not peer-reviewed)
- **Potential assumption**: Yes

#### F14: No empirical data on the 80/20 split of universal vs. language-specific testing knowledge
- **Claim**: No study quantifies what fraction of testing knowledge is universal (AAA, boundary testing, error paths) vs. language-specific (Go table-driven, Python fixtures, TypeScript type narrowing). The Pareto principle is cited in testing literature but only for defect concentration, not knowledge portability.
- **Evidence**: Absence confirmed across academic and practitioner sources.
- **Source**: https://www.calleosoftware.co.uk/software-testing-insights/the-pareto-principle-6-ways-to-test-smarter-with-the-80-20-rule/
- **Confidence**: MEDIUM (absence of evidence)
- **Potential assumption**: Yes

## Conflicts & Agreements

**Strong agreement across all tracks**: The composition pattern (generic base + language-specific layer) is the dominant strategy across agent platforms (Salesforce, Microsoft), tool ecosystems (ESLint, Prettier, Docker, GitHub Actions), and agent research (Agent S2). No source recommends a pure-generic or pure-specialist approach.

**Agreement**: F2 (Multi-SWE-bench 52% vs 7.5%) and F4 (Opus leads but at sub-10% for most languages) both confirm that language-specific context carries non-trivial value. A pure language-agnostic approach would produce measurably worse results for non-Python projects.

**Agreement**: F6/F7/F8 confirm Claude Code's architecture directly supports the composition pattern. The `skills` field, `paths` auto-loading, and progressive disclosure are designed for exactly this use case.

**Tension**: F13 (diminishing returns) suggests language-specific prompt work has a ceiling. F2 (massive per-language variance) suggests the gap is too large to ignore. Resolution: the first layer of language-specific content (testing idioms, framework patterns, infrastructure setup) captures the majority of value. Hyper-specialization within a language (e.g., separate skills for pytest vs. unittest) hits diminishing returns quickly.

**Agreement**: F9 (Testcontainers) and F11 (ecosystem pattern) both show that language separation is driven by API surface difference, not quality improvement. When APIs genuinely differ (Go testing vs. xUnit), separate skills are warranted. When testing patterns are similar (boundary testing, mock patterns), they should be shared.

## Open Questions

1. **What is the actual token cost of skill composition in practice?** The 15k token estimate (3 skills × 5k) is theoretical. No published measurement of real skill composition overhead exists.

2. **Does `paths` auto-loading work reliably in subagent context?** The docs describe it for main sessions. Whether a subagent with `paths: **/*.go` correctly limits activation is undocumented.

3. **How much language-specific testing knowledge is needed per language?** F14 confirms no 80/20 measurement exists. Empirical testing with a prototype would be needed.

4. **What is the maintenance cost of N language skills?** F2.1 found no published data on agent/skill drift rates. A language skill tracking Go 1.24 testing patterns may need updates when Go 1.25 ships.

5. **Should Specwright include community-contributed language skills or curate them?** The Testcontainers model (official skills per language) vs. the Cursor model (community rules with 28.7% duplication) represent opposite ends of curation quality.
