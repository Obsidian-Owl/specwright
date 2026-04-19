---
topic-id: deep-semantic-analysis
date: 2026-03-22
status: approved
confidence: HIGH (tool capabilities, hook mechanics, context injection points), MEDIUM (performance benchmarks, context budgeting ratios), LOW (additionalContext size limits, feedback loop persistence through compaction)
sources: 120+ primary across 6 tracks
---

# Research Brief: Deep Semantic Analysis, Context Engineering, and Agentic Guardrails

Topic-ID: deep-semantic-analysis
Created: 2026-03-22
Updated: 2026-03-22
Tracks: 6

## Summary

Researched options for robust semantic analysis with user-installed dependencies, LLM
context injection throughout the build lifecycle, and hook-based guardrails for agentic
tools. Key findings: ast-grep is the only analysis tool fast enough for real-time hooks
(~50-150ms); OpenGrep restores cross-function taint tracking for free (LGPL fork of
Semgrep); LSP daemon pattern provides 50ms call-site lookups when warm; Claude Code's
SubagentStart hook is the primary injection point for repo maps and type context;
compaction bridge pattern (PreCompact → file → SessionStart) is validated; and correction
feedback plateaus after 2-4 iterations with largest gain in first round.

## Track 1: Deep Semantic Analysis Tools

### F1: ast-grep is structural-only but fast enough for real-time hooks
- **Claim**: ast-grep (~50-150ms single-file, single-rule) fits within the 300ms PostToolUse budget. It supports metavariable capture, relational rules (inside/has/follows/precedes), and composite logic (all/any/not). JSON output includes match text, range, file, metaVariables. Installation: `npm install -g @ast-grep/cli` or `brew install ast-grep`. Supports 34 languages via tree-sitter grammars. Stdin mode (`sg scan --stdin`) enables scanning content before disk write.
- **Evidence**: Benchmark: 10.8s → 0.975s for multi-file multi-rule scan after optimization. Single-file cold start is Rust binary startup (~10-50ms) plus sub-ms AST construction. No official single-file benchmark exists.
- **Source**: https://ast-grep.github.io/blog/optimize-ast-grep.html, https://ast-grep.github.io/reference/cli/scan.html
- **Confidence**: HIGH (capabilities); MEDIUM (single-file latency is inferred, not measured)

### F2: ast-grep cannot detect dataflow, types, or control flow paths
- **Claim**: ast-grep's own documentation states it "cannot detect: type information, control flow analysis, data flow analysis, taint analysis, constant propagation." For resource leak detection, it can find acquisition and release sites structurally but cannot verify all paths are covered.
- **Evidence**: ast-grep tool comparison page. Confirmed by rule language specification lacking any path or flow operators.
- **Source**: https://ast-grep.github.io/advanced/tool-comparison.html
- **Confidence**: HIGH

### F3: OpenGrep restores cross-function taint with at-exit sinks under LGPL
- **Claim**: OpenGrep (forked January 2025 by Aikido, Endor Labs, Jit, Orca) restores features Semgrep moved to Pro in late 2024: cross-function intraprocedural taint tracking across 12 languages, result fingerprinting, tracking ignores, and at-exit sinks. At-exit sinks detect "resource acquired but not released by function exit." Rule format and JSON/SARIF output are Semgrep-compatible.
- **Evidence**: OpenGrep launch announcement, Endor Labs benchmark (3.15x faster than current Semgrep CE average).
- **Source**: https://www.aikido.dev/blog/launching-opengrep-why-we-forked-semgrep, https://www.endorlabs.com/learn/benchmarking-opengrep-performance-improvements
- **Confidence**: MEDIUM (younger project, single performance benchmark source)

### F4: Semgrep CE lost critical features; cold-start makes it unsuitable for real-time hooks
- **Claim**: Semgrep CE cold-start is seconds (OCaml binary + Python wrapper + rule parsing + grammar loading). Per-file timeout default is 5 seconds. No daemon mode exists for the community CLI. Suitable for pre-commit and CI only. Features moved to Pro: cross-function taint, at-exit sinks, interfile analysis, fingerprinting.
- **Evidence**: Semgrep benchmark blog: CI scan average "just under 10 seconds." Historical 2-second MacOS startup traced to OCaml `wait4` (issue #3405, fixed but base overhead remains).
- **Source**: https://semgrep.dev/blog/2025/benchmarking-semgrep-performance-improvements/, https://github.com/semgrep/semgrep/issues/3405
- **Confidence**: HIGH

### F5: tree-sitter queries alone are insufficient for semantic bug detection
- **Claim**: tree-sitter S-expression queries match AST structure only. Predicates (#eq?, #match?, #any-of?) are not enforced by the C library — consuming code must implement filtering. No concept of control flow, data flow, or path conditions. For non-trivial resource leak detection, tree-sitter must be combined with programmatic AST traversal in Node.js/Rust.
- **Evidence**: tree-sitter docs: "Predicates and directives are not handled directly by the Tree-sitter C library. They are just exposed in a structured form so that higher-level code can perform the filtering."
- **Source**: https://tree-sitter.github.io/tree-sitter/using-parsers/queries/3-predicates-and-directives.html
- **Confidence**: HIGH

### F6: Recommended semantic analysis pipeline: ast-grep → filter → LLM
- **Claim**: The evidence-backed architecture is three layers: (1) ast-grep extracts structural facts (resource sites, error handlers, return paths) as JSON, (2) filter passes only suspicious patterns to layer 3, (3) LLM receives structured fragments with targeted semantic questions. This matches published SAST + LLM hybrid architectures (OWASP benchmark: 71% vs 48% detection).
- **Evidence**: Pattern documented in haasonsaas.com security scanner research and VT Code agent (tree-sitter + ast-grep + LLM). Every published system that outperforms pure LLM review constrains LLM input with structured slices.
- **Source**: https://www.haasonsaas.com/blog/security-scanner/, neuro-symbolic-gates research brief
- **Confidence**: HIGH

### F7: LSP daemon provides precision layer for cross-file analysis
- **Claim**: `cli-lsp-client` maintains long-running LSP server processes per project root. Key capabilities when warm: `textDocument/references` (~50ms for all call sites vs ~45s for text search), `callHierarchy/incomingCalls` (impact analysis), `publishDiagnostics` (type errors, unused vars). gopls has native daemon support (`-remote=auto`); tsserver and rust-analyzer require wrapper daemons.
- **Evidence**: gopls scalability blog confirms file-based cache for warm restarts. LSPRAG shows +174% line coverage for Go via LSP context.
- **Source**: https://go.dev/blog/gopls-scalability, https://github.com/eli0shin/cli-lsp-client, https://arxiv.org/abs/2510.22210
- **Confidence**: HIGH (capabilities); MEDIUM (latency figures are from varied sources)

### F8: Piggybacking on editor LSP is not viable
- **Claim**: LSP protocol assumes single-client handshake. Multiple clients connecting to the same server instance causes state corruption, conflicting diagnostics, and editor lockup. GitHub issue microsoft/language-server-protocol#160 confirms: "servers weren't architecturally designed for multi-client scenarios."
- **Evidence**: LSP 3.17 spec: "The client must not send any additional requests or notifications to the server until it has received the initialize response." Single-client design is fundamental.
- **Source**: https://github.com/microsoft/language-server-protocol/issues/160, LSP 3.17 specification
- **Confidence**: HIGH

### F9: CodeQL works for interpreted languages without compilation but has licensing constraints
- **Claim**: CodeQL extracts databases directly from source for Python, JavaScript/TypeScript, Ruby without compilation. Provides full interprocedural and interfile dataflow. CLI is a large download (multiple GB). Free for open-source local analysis; commercial redistribution of results may require license.
- **Evidence**: CodeQL docs: "For Python and JavaScript, the extractor does not require a build system."
- **Source**: https://docs.github.com/en/code-security/codeql-cli/getting-started-with-the-codeql-cli/preparing-your-code-for-codeql-analysis
- **Confidence**: HIGH

### F10: Joern (Code Property Graphs) is too heavy for plugin use
- **Claim**: Joern requires JVM + SBT. Startup involves Scala VM initialization. Benchmark comparisons found "Joern was the slowest by far." No lightweight CPG alternative exists at comparable quality.
- **Evidence**: Published benchmark comparing Joern to SrcML and LLVM.
- **Source**: https://docs.joern.io/
- **Confidence**: HIGH

## Track 2: Context Injection for LLM Builds

### F11: Aider repo-map uses tree-sitter + PageRank to compress codebase into ~1024 tokens
- **Claim**: Aider extracts Tag tuples (file, name, kind, line) via tree-sitter, builds a NetworkX MultiDiGraph where edges represent dependency relationships, applies PageRank with personalization biased toward active files (100/N vs 1/N weights), then binary-searches for the maximum tags fitting the token budget. Default 1,024 tokens; expands to 8,192 when no files are in chat. Cached via diskcache keyed by file path + mtime.
- **Evidence**: Aider source code (repomap.py) and official documentation.
- **Source**: https://aider.chat/docs/repomap.html, https://deepwiki.com/Aider-AI/aider/4.1-repository-mapping
- **Confidence**: HIGH

### F12: SubagentStart hook is the primary injection point for executor context
- **Claim**: SubagentStart fires when a subagent is spawned, receives `agent_type` and `agent_id`, and supports `additionalContext` injection via JSON stdout. Can discriminate by agent type (e.g., inject repo map only for executor, inject test patterns only for tester). No documented size limit on additionalContext.
- **Evidence**: Claude Code hooks reference: output schema includes `hookSpecificOutput.additionalContext`.
- **Source**: https://code.claude.com/docs/en/hooks
- **Confidence**: HIGH (mechanism); LOW (size limits undocumented)

### F13: Context length degrades LLM performance 13.9-85% even with perfect retrieval
- **Claim**: Across 5 models, performance degrades substantially as input length increases, even when all relevant information is retrievable. Effective capacity is 60-70% of advertised maximum. Early and late context achieves 85-95% accuracy; middle sections drop to 76-82% ("lost in the middle").
- **Evidence**: arXiv 2510.05381 controlled study; Chroma Research "context rot" study.
- **Source**: https://arxiv.org/html/2510.05381v1, https://research.trychroma.com/context-rot
- **Confidence**: HIGH

### F14: Queries placed after longform data improve response quality by up to 30%
- **Claim**: Anthropic's internal tests show that placing the instruction/query after longform data (not before) improves response quality by up to 30%, especially with complex multi-document inputs.
- **Evidence**: Anthropic prompt engineering best practices: "Put longform data at the top... Queries at the end can improve response quality by up to 30%."
- **Source**: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- **Confidence**: HIGH

### F15: LSPRAG achieves +174% Go coverage via LSP-based context injection
- **Claim**: LSPRAG uses four LSP capabilities (Symbol, Token, Definition, Reference providers) to build semantic dependency graphs as RAG context. LSP retrieval takes ~5 seconds per focal method (18% of total). Python improvements are dramatically smaller (+31.57%) due to Pylance's weaker LSP completeness.
- **Evidence**: Controlled evaluation on open-source projects. Go +174.55%, Java +213.31%, Python +31.57%.
- **Source**: https://arxiv.org/abs/2510.22210
- **Confidence**: HIGH

### F16: ProCoder shows 80%+ improvement with first-iteration compiler feedback; plateaus at 3 iterations
- **Claim**: First iteration reduces UNDEF errors from 5,133 to 1,042. Pass@10 rises from 34.55% to 49.09% over 3 iterations, then drops slightly at 10 iterations. Generalizes to any tool producing structured error output mappable to missing context.
- **Evidence**: ProCoder paper, ACL Findings 2024.
- **Source**: https://arxiv.org/abs/2403.16792
- **Confidence**: MEDIUM

### F17: OpenCode feeds LSP diagnostics directly back to LLM after file writes
- **Claim**: OpenCode queries LSP server after tool execution, passes diagnostics back to the LLM. Described as "extremely useful: it keeps the LLM grounded and prevents it from going off the rails." Uses 150ms debounce after last diagnostic notification with 3-second maximum wait.
- **Evidence**: Community deep-dive analysis confirmed by OpenCode LSP documentation.
- **Source**: https://cefboud.com/posts/coding-agents-internals-opencode-deepdive/, https://opencode.ai/docs/lsp/
- **Confidence**: MEDIUM

## Track 3: Real-Time Guardrail Hooks

### F18: PostToolUse hooks cannot block — only inject feedback via additionalContext
- **Claim**: PostToolUse hooks exit code is ignored for blocking purposes. Feedback reaches the agent only via `additionalContext` in JSON stdout. For blocking, PreToolUse on the next tool call or pre-commit hooks are required.
- **Evidence**: Claude Code hooks docs explicitly list PostToolUse under events that "cannot block."
- **Source**: https://code.claude.com/docs/en/hooks
- **Confidence**: HIGH

### F19: What fits at each enforcement layer (evidence-based latency allocation)
- **Claim**: PreToolUse (<500ms): regex/grep patterns, secret scanning, dangerous command detection, file protection. PostToolUse (<300ms sync, unbounded async): formatter auto-fix, ast-grep single rule (~100-150ms), additionalContext feedback. Pre-commit (seconds): full ast-grep scan, OpenGrep/semgrep, linters, type check, secret scan. Pre-push (minutes): full test suite, coverage. CI (minutes): everything above plus dependency audit, history-level secret scan.
- **Evidence**: Synthesized from ast-grep benchmarks, semgrep cold-start data, and the existing 300ms PostToolUse heuristic.
- **Source**: Cross-track synthesis
- **Confidence**: MEDIUM (latency figures are estimates for some tools)

### F20: Session hooks and pre-commit are additive, not redundant, when scoped differently
- **Claim**: Session hooks should use targeted fast single-rule passes catching the most common/dangerous patterns. Pre-commit should use the full configured ruleset. Running the same full scan at both layers wastes pre-commit time.
- **Evidence**: Logical derivation from latency constraints and the principle of distinct catch domains per layer (guardrails-strategy research).
- **Source**: Cross-track synthesis with guardrails-strategy-20260320
- **Confidence**: MEDIUM

### F21: Opencode subagent tool calls bypass plugin hooks entirely
- **Claim**: Subagent tool calls spawned via the task tool bypass `tool.execute.before` in Opencode. This is an open security issue (anomalyco/opencode #5894). Plugin hooks cannot be relied upon as a security boundary when multi-agent delegation is used.
- **Evidence**: GitHub issue #5894, verified open with no fix merged.
- **Source**: https://github.com/anomalyco/opencode/issues/5894
- **Confidence**: HIGH

### F22: Hook security — analysis tool hooks should default to settings.local.json
- **Claim**: CVE-2025-59536 showed project-level `.claude/settings.json` hooks as RCE vectors. Hooks invoking external binaries (ast-grep, semgrep) with project-contributed rule configs are a viable attack surface. Safe pattern: use `settings.local.json` (gitignored), pin rule configs to checksummed local files or trusted remote URLs.
- **Evidence**: Check Point CVE research, NVD entries.
- **Source**: https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/
- **Confidence**: HIGH

## Track 4: LSP as Unified Analysis Backend

### F23: LSP daemon pattern eliminates cold-start for warm queries
- **Claim**: gopls supports native daemon mode (`-remote=auto`). cli-lsp-client implements generic daemon for any LSP server. OpenCode maintains an LSP client pool indexed by (root + serverID). Once warm: `textDocument/references` ~50ms, `callHierarchy` sub-second, `publishDiagnostics` push-based (no polling).
- **Evidence**: gopls scalability blog, cli-lsp-client README, OpenCode LSP integration analysis.
- **Source**: https://go.dev/blog/gopls-scalability, https://github.com/eli0shin/cli-lsp-client, https://deepwiki.com/sst/opencode/5.4-language-server-integration
- **Confidence**: HIGH

### F24: Cold-start costs are language-server dependent and significant
- **Claim**: tsserver semantic diagnostics: ~7s (mid-size) to 60s+ (large monorepos). rust-analyzer: 5-10s (small/medium), 22.8s (large). gopls with warm cache: ~0.5s. Pyright: fast watch-mode updates (~1000 files/s) but cold-start not precisely benchmarked. Memory: 245MB-1.8GB depending on project size and language.
- **Evidence**: Issue reports and community benchmarks (not controlled studies).
- **Source**: https://github.com/microsoft/TypeScript/issues/39844, https://github.com/rust-lang/rust-analyzer/issues/5109, https://go.dev/blog/gopls-scalability
- **Confidence**: MEDIUM (project-size dependent, not controlled)

### F25: Highest-value LSP features for Specwright gates
- **Claim**: In priority order: (1) `publishDiagnostics` — push-based type errors and lint violations, maps to build gate. (2) `textDocument/references` — 50ms all call sites, enables dead-code detection and impact analysis. (3) `callHierarchy` — call graph for wiring validation. (4) `textDocument/hover` — type information at positions for semantic assertions. (5) `workspace/symbol` — cross-workspace symbol lookup for spec verification.
- **Evidence**: Synthesized from LSP 3.17 spec capabilities and Specwright gate requirements.
- **Source**: Cross-track synthesis
- **Confidence**: HIGH

## Track 5: Agentic Quality Feedback Loops

### F26: Strands steering achieves 100% accuracy but costs 44% more input tokens
- **Claim**: Hook-based steering: 100% accuracy across 600 evaluation runs. Prompt instructions: 82.5%. Graph-based workflows: 80.8%. The 44% token overhead comes from corrective guidance injected when the agent strays. Mechanism: intercept at pre-tool/post-response, inject targeted "Guide" response, agent retries with correction in context.
- **Evidence**: Strands Agents blog post with controlled benchmark.
- **Source**: https://strandsagents.com/blog/steering-accuracy-beats-prompts-workflows/
- **Confidence**: MEDIUM (vendor benchmark, not independent study)

### F27: Correction effects plateau at 2-4 iterations; first iteration yields largest gain
- **Claim**: SWE-Bench Lite: 7B model plateaus after 2 iterations (7.0% → 10.0%). 32B model plateaus after 1 iteration (19.0% → 19.7%). ProCoder UNDEF errors: 5133 → 1042 in first iteration. Cursor hard-caps linting correction at 3 iterations. Consistent pattern: diminishing returns after 3-4 rounds.
- **Evidence**: arXiv 2509.16941 (SWE-Bench Pro), arXiv 2403.16792 (ProCoder), Cursor analysis blog.
- **Source**: https://arxiv.org/pdf/2509.16941, https://arxiv.org/abs/2403.16792, https://blog.sshh.io/p/how-cursor-ai-ide-works
- **Confidence**: MEDIUM

### F28: Observation masking outperforms LLM summarization for in-loop context management
- **Claim**: Environment observations constitute ~84% of context tokens in SWE agents. Simple observation masking (replace older observations with placeholders) reduces costs ~52% while maintaining solve rates. LLM summarization paradoxically increases trajectory length 13-15% by smoothing failure signals.
- **Evidence**: arXiv 2508.21433 controlled study on SWE-bench scaffold agents.
- **Source**: https://arxiv.org/html/2508.21433v1
- **Confidence**: MEDIUM

### F29: LLM sycophancy in corrections affects 58% of multi-turn interactions
- **Claim**: In multi-turn evaluation, 58.19% of cases showed sycophantic behavior: apparent compliance without genuine fix. Progressive sycophancy (correct outcome) in 43.52% of cases; regressive (incorrect) in 14.66%.
- **Evidence**: SYCON benchmark, arXiv 2505.23840.
- **Source**: https://arxiv.org/pdf/2505.23840
- **Confidence**: MEDIUM

### F30: Corrections do not inherently survive Claude Code auto-compaction
- **Claim**: No documentation confirms behavioral corrections survive compaction. PreCompact hooks cannot modify compaction. The PreCompact → file → SessionStart(compact) bridge must be used to persist corrections explicitly.
- **Evidence**: Claude Code hooks docs confirm PreCompact has no decision control. mvara-ai precompact-hook demonstrates the bridge pattern.
- **Source**: https://code.claude.com/docs/en/hooks, https://github.com/mvara-ai/precompact-hook
- **Confidence**: HIGH (mechanism); LOW (what survives default compaction is undocumented)

### F31: PostToolUse additionalContext is the mechanism for per-tool-call feedback injection
- **Claim**: PostToolUse hook JSON stdout with `additionalContext` in `hookSpecificOutput` is injected into Claude's context. Plain text stdout from PostToolUse is NOT sent to Claude (shown in verbose mode only). This is the documented mechanism for feeding linter/diagnostic output back to the agent after each file write.
- **Evidence**: Claude Code hooks reference: "PostToolUse | additionalContext in hookSpecificOutput | Yes (reaches Claude)."
- **Source**: https://code.claude.com/docs/en/hooks
- **Confidence**: HIGH

## Track 6: Context Engineering Patterns

### F32: Subagents start fresh — only final message returns to parent
- **Claim**: Each subagent has its own context window. It receives only its system prompt plus basic environment details — not the parent's conversation history. Intermediate tool calls and results stay inside the subagent. Subagents cannot spawn other subagents.
- **Evidence**: Claude Code sub-agents documentation.
- **Source**: https://code.claude.com/docs/en/sub-agents
- **Confidence**: HIGH

### F33: Skills in subagent frontmatter inject full content, not just availability
- **Claim**: The `skills` field in a subagent definition injects the full skill content into the subagent's context at startup. Subagents do not inherit skills from the parent. This means skill bloat directly consumes subagent context budget.
- **Evidence**: "The full content of each skill is injected into the subagent's context, not just made available for invocation."
- **Source**: https://code.claude.com/docs/en/sub-agents
- **Confidence**: HIGH

### F34: MCP servers in subagent frontmatter keep tool descriptions out of parent context
- **Claim**: MCP servers defined inline in a subagent's `mcpServers` frontmatter connect when the subagent starts and disconnect when it finishes. Tool descriptions do not appear in the parent conversation's context window. This prevents context pollution from analysis-specific tools.
- **Evidence**: "To keep an MCP server out of the main conversation entirely... define it inline here rather than in .mcp.json."
- **Source**: https://code.claude.com/docs/en/sub-agents
- **Confidence**: HIGH

### F35: Auto-compaction fires at ~95% with configurable override
- **Claim**: Default compaction at ~95% capacity. `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` shifts trigger (1-100). With ~33K buffer, effective usable window is ~167K tokens of 200K. Subagent transcripts survive main conversation compaction (stored separately).
- **Evidence**: Claude Code sub-agents docs (95% figure), claudefa.st reverse-engineering (33K buffer).
- **Source**: https://code.claude.com/docs/en/sub-agents, https://claudefa.st/blog/guide/mechanics/context-buffer-management
- **Confidence**: HIGH (95%); MEDIUM (buffer size)

### F36: Issue #5812 — no first-class subagent→parent context bridge; three workarounds
- **Claim**: additionalContext does not propagate from subagent hooks to parent agent. Three documented workarounds: (1) SubagentStop hook with `decision: "block"` feeds reason to parent, (2) SubagentStop writes state file + UserPromptSubmit reads it, (3) PostToolUse auto-commits via git, parent discovers via git status.
- **Evidence**: GitHub issue #5812 with detailed workaround descriptions.
- **Source**: https://github.com/anthropics/claude-code/issues/5812
- **Confidence**: HIGH

### F37: TeammateIdle hook enables context-driven task reassignment
- **Claim**: TeammateIdle fires when a teammate is about to go idle. Exit code 2 sends feedback and keeps the teammate working. This is the documented mechanism for dynamic work assignment in agent teams.
- **Evidence**: Claude Code agent teams documentation.
- **Source**: https://code.claude.com/docs/en/agent-teams
- **Confidence**: HIGH

### F38: Anthropic's context engineering principles for agents
- **Claim**: Anthropic recommends: (1) Sub-agent architectures returning "condensed, distilled summaries" to isolate search contexts. (2) System prompts in a "Goldilocks zone" between brittle and vague. (3) Compaction preserves "architectural decisions, unresolved bugs, and implementation details" while discarding "redundant tool outputs." (4) Just-in-time retrieval using lightweight identifiers (file paths, links) rather than pre-loading.
- **Evidence**: Anthropic engineering blog: "Effective Context Engineering for AI Agents."
- **Source**: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- **Confidence**: HIGH

### F39: XML tags recommended for multi-component context; "ground in quotes" pattern for long docs
- **Claim**: Anthropic recommends XML tags to separate instructions, context, examples, and variable inputs. For long-document tasks, the "ground in quotes" pattern (Claude extracts relevant quotes in `<quotes>` tags before reasoning) improves accuracy. 3-5 few-shot examples optimal.
- **Evidence**: Anthropic prompt engineering best practices documentation.
- **Source**: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- **Confidence**: HIGH

### F40: MCP stdio servers add under 5ms per call; Context Mode achieves ~98% context reduction
- **Claim**: stdio MCP servers: <5ms per-call latency. Context Mode MCP server intercepts raw tool outputs, stores in SQLite with FTS5, injects 1-2KB compressed summaries instead of 56KB raw payloads (~98% reduction). Zilliz Claude Context MCP: ~40% token reduction via hybrid BM25 + vector search.
- **Evidence**: Community documentation for stdio latency. Context Mode README and HN discussion.
- **Source**: https://github.com/mksglu/context-mode, https://github.com/zilliztech/claude-context
- **Confidence**: MEDIUM (secondary sources for latency)

## Conflicts & Agreements

**Agreement — ast-grep is the real-time workhorse**: T1 (structural extraction), T3 (within 300ms budget), T4 (complements LSP for pattern matching) all converge on ast-grep as the only analysis tool fast enough for per-file-write hooks.

**Agreement — first correction yields largest gain**: ProCoder (T2), SWE-Bench policy improvement (T5), and Cursor's 3-iteration cap all confirm diminishing returns after the first few rounds.

**Agreement — context placement matters as much as content**: T2 (lost-in-the-middle for code), T5 (U-shaped attention curve), and T6 (Anthropic's "queries at end" +30%) independently confirm positional effects.

**Conflict — LLM summarization utility**: T5 finds LLM summarization of agent trajectories increases trajectory length 13-15% and reduces efficiency. T2's Aider approach uses tree-sitter-structured error context successfully. Resolution: structure feedback with tool output (AST context, not prose summaries); avoid LLM-generated summaries in running agent loops.

**Conflict — compaction threshold**: Official docs say 95%, community source says 83.5% effective usable. Not contradictory — the 33K buffer means effective usable is ~83.5% of 200K, while compaction fires at 95% of usable window.

## Open Questions

1. **additionalContext size limits**: No documentation specifies maximum size or truncation policy for SubagentStart additionalContext injection. Behavior under large payloads (e.g., full repo map for a large project) is unknown.

2. **What survives default compaction?**: Anthropic says "architectural decisions, unresolved bugs, implementation details" are preserved, but the exact algorithm is undocumented. Whether behavioral corrections (gate findings, hook feedback) survive without explicit PreCompact bridging is unknown.

3. **OpenGrep production readiness**: Forked January 2025, actively maintained, but younger than Semgrep with less production history. At-exit sink feature quality across all 12 supported languages is unverified.

4. **LSP daemon lifecycle management**: Who starts/stops the daemon? How does it interact with the editor's own LSP server for the same workspace? No published pattern for coexistence.

5. **Feedback loop measurement**: No published methodology for measuring whether per-write feedback injection (PostToolUse additionalContext) actually reduces violation rates vs. deferred feedback (pre-commit). The observational report (12 blocks in first 20 writes, 2 in last 30) is the only data point.

6. **Agent teams context sharing at scale**: Agent teams are experimental, requiring feature flag. No published experience reports from real-world plugin usage. TeammateIdle feedback pattern is documented but not validated for quality enforcement use cases.

## Comprehensive Source List

### Tool Documentation
- ast-grep: https://ast-grep.github.io/ (scan CLI, rule reference, optimization blog, tool comparison, JSON output, NAPI)
- tree-sitter: https://tree-sitter.github.io/ (query syntax, predicates, CLI)
- Semgrep CE: https://semgrep.dev/docs/ (taint mode, rule syntax, performance, pre-commit, JSON/SARIF output)
- OpenGrep: https://www.aikido.dev/blog/launching-opengrep-why-we-forked-semgrep, https://www.endorlabs.com/learn/benchmarking-opengrep-performance-improvements
- CodeQL: https://docs.github.com/en/code-security/codeql-cli/
- Joern: https://docs.joern.io/
- Oxc: https://oxc.rs/, https://www.npmjs.com/package/oxc-parser
- Biome: https://biomejs.dev/blog/biome-v2/
- cli-lsp-client: https://github.com/eli0shin/cli-lsp-client
- mcp-language-server: https://github.com/isaacphi/mcp-language-server

### Claude Code & Anthropic
- Hooks: https://code.claude.com/docs/en/hooks
- Sub-agents: https://code.claude.com/docs/en/sub-agents
- Agent teams: https://code.claude.com/docs/en/agent-teams
- MCP: https://code.claude.com/docs/en/mcp
- Prompt engineering: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices
- XML tags: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/use-xml-tags
- Context engineering blog: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents

### OpenCode
- LSP: https://opencode.ai/docs/lsp/
- Plugins: https://opencode.ai/docs/plugins/
- LSP integration analysis: https://deepwiki.com/sst/opencode/5.4-language-server-integration
- Hook bypass issue: https://github.com/anomalyco/opencode/issues/5894

### Research Papers
- LSPRAG: https://arxiv.org/abs/2510.22210
- ProCoder: https://arxiv.org/abs/2403.16792
- Context length degradation: https://arxiv.org/html/2510.05381v1
- Context rot: https://research.trychroma.com/context-rot
- Observation masking: https://arxiv.org/html/2508.21433v1
- SWE-Bench Pro: https://arxiv.org/pdf/2509.16941
- Sycophancy (SYCON): https://arxiv.org/pdf/2505.23840
- RACG survey: https://arxiv.org/abs/2510.04905
- Knowledge graph code gen: https://arxiv.org/html/2505.14394v1
- Code Graph Model: https://arxiv.org/abs/2505.16901

### Feedback & Context Patterns
- Strands Agents steering: https://strandsagents.com/blog/steering-accuracy-beats-prompts-workflows/
- Aider repo map: https://aider.chat/docs/repomap.html
- Aider linting: https://aider.chat/2024/05/22/linting.html
- mvara-ai precompact-hook: https://github.com/mvara-ai/precompact-hook
- Factory.ai context: https://factory.ai/news/context-window-problem, https://factory.ai/news/evaluating-compression
- CodeScene agentic patterns: https://codescene.com/blog/agentic-ai-coding-best-practice-patterns-for-speed-with-quality
- Context Mode MCP: https://github.com/mksglu/context-mode
- Zilliz Claude Context: https://github.com/zilliztech/claude-context
- Lance Martin context engineering: https://rlancemartin.github.io/2025/06/23/context_engineering/

### Security
- CVE-2025-59536: https://research.checkpoint.com/2026/rce-and-api-token-exfiltration-through-claude-code-project-files-cve-2025-59536/
- CVE-2026-21852: https://nvd.nist.gov/vuln/detail/CVE-2026-21852
- CVE-2026-24887: https://nvd.nist.gov/vuln/detail/cve-2026-24887

### GitHub Issues
- additionalContext subagent→parent: https://github.com/anthropics/claude-code/issues/5812
- additionalContext duplication: https://github.com/anthropics/claude-code/issues/14281
- Compaction threshold: https://github.com/anthropics/claude-code/issues/23711
- LSP multi-client: https://github.com/microsoft/language-server-protocol/issues/160

### LSP Servers
- gopls scalability: https://go.dev/blog/gopls-scalability
- rust-analyzer startup: https://github.com/rust-lang/rust-analyzer/issues/5109
- tsserver performance: https://github.com/microsoft/TypeScript/issues/39844
- LSP 3.17 spec: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/
