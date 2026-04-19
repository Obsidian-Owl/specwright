# Specwright Patterns

Reusable patterns promoted from work unit learnings. These are guidelines, not constitution rules.

## Planning

**P1: Never skip the critic phase.**
The architect critic is the highest-leverage gate in the planning workflow. On `learning-lifecycle`, the critic caught 3 blocking issues (wrong hook mechanism, gitignored files, broken contracts) that would have required rewriting the protocol, skill, and docs post-build. Fix design flaws before implementation, not after.
*Source: learning-lifecycle*

## Building

**P2: Budget-aware SKILL.md editing.**
When modifying existing SKILL.md files, check current word count before adding new content. If within 80% of the token budget (~450 words for a 600-token target), tighten existing sections preemptively. On `learning-lifecycle`, sw-learn hit 621 words and required trimming 5 sections in a revision cycle that was avoidable.
*Source: learning-lifecycle*

## Tooling

**P3: Use `gh api` for PR updates.**
`gh pr edit` fails on repos with Projects Classic enabled (`GraphQL: Projects (classic) is being deprecated`). Use `gh api repos/{owner}/{repo}/pulls/{n} --method PATCH` with `-f title=` and `-f body=` instead. Works reliably regardless of project board configuration.
*Source: learning-lifecycle*

## Architecture

**P4: Keep protocols consumer-agnostic.**
Protocols must not reference specific skills by name. Use generic consumer language ("the calling skill", "the consumer") instead. This prevents tight coupling — if a consuming skill is renamed or split, the protocol stays valid. On `learning-lifecycle`, the wiring gate verified this property held.
*Source: learning-lifecycle*

**P5: Audit against external guidelines for prompt refinement.**
When refining agent or skill prompts, use published behavioral guidelines (e.g., Karpathy's coding principles) as an external audit lens. Gap analysis against an outside framework surfaces blind spots invisible from within the system. On `karpathy-alignment`, this approach found 4 categories of missing agent behavior in a single pass.
*Source: karpathy-alignment*

**P6: Audit existing rules before adding new ones.**
When adding behavioral rules to agent prompts, explicitly list existing constraints (e.g., "What you never do") and verify new rules don't duplicate them. Without this, rule sections grow redundant and dilute signal. On `karpathy-alignment`, the non-duplication audit prevented 3 near-duplicates across executor and build-fixer.
*Source: karpathy-alignment*

**P7: Cross-category wiring reveals structural debt.**
When touching all files in a category (e.g., all 6 agents), run wiring analysis — it reliably surfaces pre-existing inconsistencies. On `karpathy-alignment`, the wiring gate found the executor's incorrect frontmatter description and the tester's missing "What you never do" section, both pre-dating the work unit.
*Source: karpathy-alignment*

**P8: Agent behavior belongs in agent prompts, not protocols.**
Agent-level behavioral rules should be inlined in agent markdown files, not in shared protocols. Agents load their full prompt at session start and don't dynamically import protocols. A shared protocol would require delegation-time injection by the calling skill, adding complexity for no benefit.
*Source: karpathy-alignment*

**P9: Prefer prompt/agent hook types over command hooks in plugins.**
Command-type hooks with exit code 2 are buggy in Claude Code (issues #10412, #10875, #12151). Prompt-type hooks use a different execution path and avoid the issue entirely. Agent-type hooks add tool access for richer behavior. Reserve command-type for hooks that must run external tooling (formatters, linters).
*Source: pilot-inspired-resilience*

**P10: Persistent artifacts need a skill-level synthesis step.**
When a skill creates persistent documents from agent analysis, design an explicit synthesis step: agents return raw findings, the skill aggregates, matches, and writes. Never delegate artifact creation to READ-ONLY agents. On `codebase-audit`, the adversarial critic caught this as a BLOCK — agents can't write AUDIT.md.
*Source: codebase-audit*

**P11: Reference documents follow a reusable template.**
Reference documents (LANDSCAPE.md, AUDIT.md) share a proven structure: optional, `Snapshot:` header (ISO 8601), freshness protocol with configurable staleness threshold, consumer-agnostic protocol in `protocols/`, loaded on demand by consumers, never blocks workflow. Use this template for any future codebase-level persistent document.
*Source: codebase-audit*

**P12: Trace new execution paths end-to-end through the skill chain.**
When adding alternative paths through the workflow (e.g., Lite/Quick intensity), verify every downstream skill's pre-conditions accept the artifacts that path actually produces. On `pilot-inspired-resilience`, the Lite path was dead on arrival because sw-plan required `design.md` which Lite doesn't produce. The wiring gate's end-to-end trace caught this.
*Source: pilot-inspired-resilience*

**P18: Platform markers over adapter overrides.**
Use `<!-- platform:X -->` conditional markers in core SKILL.md files for platform-specific body differences. Reserve full adapter overrides (`adapters/{platform}/skills/{name}/SKILL.md`) for skills with fundamentally different goals or constraint structures. Markers keep a single source of truth and prevent drift.
*Source: audit-remediation/platform-markers*

**P19: Bash test script hardening.**
Bash test scripts must: (a) use `trap 'cleanup' EXIT` to prevent artifact accumulation on failure, (b) include parser sanity checks that catch broken extractors (e.g., verify tool count >= expected), (c) use `git diff --exit-code` for source-integrity verification rather than spot-checking individual lines.
*Source: audit-remediation/claude-code-tests*

**P20: ast-grep CLI: `sg scan` vs `sg run`.**
`sg scan` operates on project directories with `sgconfig.yml` — it does NOT accept individual file arguments. `sg run --pattern '...' --lang <lang> <file> --json` is the per-file extraction command. `sg scan --stdin` is invalid (`--stdin` belongs to `sg run`). This misconception recurred across 3 units and 3 PR reviews. Always verify ast-grep CLI flags against official documentation before writing protocols or hook handlers.
*Source: semantic-context (recurred in foundation, gate-semantic-tiers, feedback-loops)*

**P21: Validate `sg` binary identity on Linux.**
On Debian/Ubuntu/RHEL, `/usr/bin/sg` is `newgrp` from shadow-utils, not ast-grep. Plain `which sg` returns a false positive. Validate with `sg --version 2>&1 | grep -iq 'ast-grep'`. Apply this pattern to any tool detection where the binary name could collide with system utilities.
*Source: semantic-context/foundation PR review*

**P22: JavaScript regex — no `\Z` support.**
JavaScript regex does not support `\Z` (PCRE/Python end-of-string anchor). In JS, `\Z` matches literal `Z`, silently breaking patterns. Use `$` for end-of-string. This caused a P1 bug in the correction bridge where Correction Summary extraction silently failed when the section was last in the file (the common case).
*Source: semantic-context/feedback-loops PR review*

**P23: Claude Code hook handlers run in plugin context.**
`CLAUDE_PLUGIN_ROOT` is always set when a Claude Code plugin hook executes. Conditional branches checking for it create dead code. Design hooks assuming the plugin environment — external tool fallbacks belong in gate skills (verify-time), not in PostToolUse hooks (real-time). Standalone CLI behavior should be a separate code path, not a conditional branch within the hook.
*Source: semantic-context/feedback-loops PR review*

**P24: Use list-form subprocess args in all hook handlers.**
`execSync` with string-interpolated arguments enables shell injection via file paths containing metacharacters. Use `execFileSync` (Node.js) or equivalent list-form APIs. This applies to ALL hook handlers, not just security-sensitive ones — file paths from `tool_input.file_path` are a system boundary even when sourced from Claude Code's own platform.
*Source: semantic-context/feedback-loops security gate*

**P25: Git staging through symlinks requires real paths.**
When the project uses symlinks (`protocols/` → `core/protocols/`), `git add protocols/file.md` may fail or behave unexpectedly. Always stage using the real path (`core/protocols/file.md`). Run `ls -la` on the directory to identify symlinks before first commit in a new project area.
*Source: semantic-context/foundation as-built notes*

## Maintenance

**P13: Fix pre-existing debt surfaced by verify in the same work unit.**
Verify reliably catches adjacent tech debt, not just issues introduced by the current work. When the fix is small (e.g., tightening token budgets), resolve it in the same unit. This prevents debt from being perpetually deferred across work units.
*Source: pilot-inspired-resilience*

## Research

**P14: Periodic competitive analysis filtered through charter invariants.**
Reviewing similar tools (e.g., Claude Pilot) yields concrete, actionable improvements. Filter findings through existing architecture constraints rather than adopting wholesale. On `pilot-inspired-resilience`, this produced 4 implementable features from a single analysis session.
*Source: pilot-inspired-resilience*

## Protocols

**P15: Protocol compression requires structural rewrite, not word trimming.**
When a protocol exceeds its word budget, restructure before trimming. Effective techniques: flow notation for lifecycles (`Open → Stale → Resolved → Purged`), inline format descriptions, collapse separate sections into compound sentences. On `codebase-audit`, the audit protocol went from 214→123 words by restructuring, not word-level editing.
*Source: codebase-audit*

**P16: Measure baseline word counts before implementing spec word-count limits.**
When a spec sets explicit word-count limits for skill modifications, run `wc -w` on the baseline file before editing. Track the delta during implementation and trim in the same edit. On `codebase-audit`, both sw-design (+14 vs <=10 limit) and sw-learn (+36 vs <=15 limit) exceeded limits on first pass, requiring a fix commit.
*Source: codebase-audit*

**P17: Dedicate a documentation task as the final build task.**
Include a dedicated docs task as the last task in every work unit to systematically update counts, tables, and cross-references in DESIGN.md, CLAUDE.md, and README.md. On `codebase-audit`, this produced 0 WARN/BLOCK wiring findings (19/19 checks passed) — a marked improvement over previous units with 6+ findings.
*Source: codebase-audit*

## Workflow

**P26: Wire all documentation surfaces when adding or modifying skills and protocols.**
When adding a new user-facing skill, update all 5 documentation surfaces in the same task: DESIGN.md (table + directory + counts), CLAUDE.md (table), AGENTS.md (table + protocol list), opencode adapter command file, and build test expected skills list. When modifying a protocol, verify both CLAUDE.md and AGENTS.md protocol lists include it — AGENTS.md drifts silently because the Constitution only mentions CLAUDE.md and DESIGN.md. On `testing-inner-loop`, AGENTS.md was 5 protocols behind CLAUDE.md.
*Source: workflow-commands/sw-sync, sw-review, testing-inner-loop/test-discipline*

**P27: Test for markdown structure, not just content keywords.**
Bash skill tests validate content presence via grep, but miss markdown hierarchy bugs: stale RED-phase comments, orphaned numbered list items, `\s` (GNU-only) vs `[[:space:]]` (POSIX). PR reviewers caught these across all 3 units. When testing markdown skills, include structural guards: list item counts, indentation consistency, POSIX-portable regex.
*Source: workflow-commands (all 3 units)*

## Design

**P28: Challenge stage boundary violations at design time, not build time.**
The architect rejected `sw-verify --fix` during design because it violated the explicit "You NEVER fix code" constraint. The alternative (enriched handoff) was simpler, respected boundaries, and avoided a wasted build cycle. Always run the adversarial critic before approving designs that touch stage boundary constraints.
*Source: workflow-commands/verify-enriched-handoff*

**P29: Prefer context-flow improvements over new tools.**
The verify→"Resolve the warns" two-step was solved not by a new `/sw-fix` skill but by enriching the handoff message so Claude already has fix information in context. When a workflow friction involves "the user has to re-explain what was already computed," the fix is better information flow, not a new command.
*Source: workflow-commands/verify-enriched-handoff*

## Testing

**P30: Compress existing skills before adding content.**
Before adding constraints to a SKILL.md, audit it for duplication, over-specification, and redundant protocol inlining. On `testing-inner-loop`, sw-build was at 1,657 words (near the 1,200-word ceiling). A verbosity audit found 390 words of safe trims — repo map duplication with build-context.md, inline headless branching that protocols/headless.md already defines, verbose stage boundary blocks. Net: added an 80-word inner-loop validation constraint while *reducing* total by 318 words.
*Source: testing-inner-loop/tiered-test-execution*

**P31: PR reviewers consistently catch omissions and ordering — not logic errors.**
Across 15 review threads on 2 PRs, reviewers caught: sequencing issues (TESTING.md created before tier commands captured), over-compression (removed External/Expensive boundary guidance), fragile references ("charter invariant 3" ordinal), noise in unconfigured scenarios, hardcoded language examples. None were logic errors or security bugs. The pattern: reviewers find what you *removed* or *misordered*, not what you *wrote wrong*. Design reviews should specifically check for removed guidance and constraint ordering.
*Source: testing-inner-loop (PR #112 + #113)*

**P32: Document why a command runs in both build and verify.**
sw-build's inner-loop runs `test:integration`, then gate-build runs it again during verify. Both claude and greptile flagged the duplication. The justification (inner-loop catches failures while fixer context is fresh; verify re-validates after post-build review) was accepted once documented inline. When a command intentionally runs at multiple workflow stages, add a note explaining why — otherwise reviewers will flag it as redundant.
*Source: testing-inner-loop/tiered-test-execution*

**P33: Test behavioral constraints, not prompt wording.**
Unit 1 changed execution behavior (tier order, verdicts, word counts) and warranted 90 new bash tests. Unit 2 changed prompt wording (tester obligation, init questions) and had 0 dedicated tests — the spec-gate WARNed but the finding was accepted. Grep-based tests for specific prompt phrases are brittle and break on legitimate rewording. Test what the skill *does* (execution order, file structure, word budgets), not what it *says* (specific phrasing in constraints).
*Source: testing-inner-loop/test-discipline*

**P34: LLM bias labels suppress execution — remove or avoid them.**
Labels like "experimental" and "opt-in" in context-loaded files (DESIGN.md, CLAUDE.md) cause the LLM to deprioritize or skip the labeled feature even when config says `enabled: true`. On `semantic-gate-reliability`, this caused the semantic gate to be silently skipped in 27+ work units across 5 projects. The gate itself worked correctly — the problem was entirely in the calling skill's decision to invoke it. When a feature is shipped and configured, remove hedging language. WARN severity already communicates advisory status.
*Source: semantic-gate-reliability*

**P35: Enforcement constraints need carve-outs for partial-run modes.**
Adding a post-execution validation (e.g., "every enabled gate must have evidence") creates false positives when the tool supports partial execution (e.g., `--gate=<name>`). Both claude[bot] and greptile flagged this as P1 on PR #119. When adding enforcement constraints, enumerate all execution modes and add explicit guards for partial runs. This is a specific instance of P31 (reviewers catch constraint interactions).
*Source: semantic-gate-reliability (PR #119 review)*

**P36: Use `re.DOTALL` for regex patterns matching markdown content.**
Regex patterns that match across lines in markdown files need `re.DOTALL` (or inline `(?s)`). The `.` metacharacter doesn't match `\n` by default, causing proximity checks like `r"green.{0,200}integration.tester"` to fail when the terms are on different lines. On `testing-quality-infrastructure`, this affected all 6 test files (~20 patterns) across 3 WUs, causing false RED failures and requiring per-file fixes.
*Source: testing-quality-infrastructure (WU-01 through WU-03)*

**P37: Agent prompts for mixed-tier delegation must explicitly carve out contract behavior.**
When an agent handles multiple test tiers (integration + contract + e2e), the "real infrastructure, no mocks" philosophy must be explicitly scoped to integration/e2e only. Contract tests mock external services by design — the no-skip rule means the contract *framework* must be available, not live external services. On `testing-quality-infrastructure`, 3 independent reviewers (claude[bot] x2, greptile x1) flagged this as contradictory or misleading. Agent prompts that mix "always real" with "validate contracts" need tier-specific carve-outs in both the intro and the tier strategies section.
*Source: testing-quality-infrastructure (PR #138 review, threads 2+3+4)*

**P38: Non-skill directories under core/skills/ require CI test exclusions.**
The CI build test (`test-claude-code-build.sh`) counts subdirectories under `skills/` and validates each has a `SKILL.md`. Adding reference doc directories (e.g., `lang-building/`) without a SKILL.md triggers two failures: count mismatch and missing SKILL.md. This is the 4th occurrence of the CI count pattern (also hit with agents/). When adding non-skill directories under skills/, update `REFERENCE_DIRS` in the CI test.
*Source: language-building-skills (PR #140, pre-push failure)*

**P39: Orchestrator-level prompt composition is the standard pattern for language-specific agent behavior.**
When agents need language-specific knowledge but dynamic skill injection is unavailable (Task() has no `skills` parameter), the orchestrator reads reference files and includes their content in the delegation prompt. This pattern is proven across two designs: testing tier (TESTING.md + config.json languages in integration-tester delegation) and building skills (lang-building/{language}.md in executor/tester/integration-tester delegation). No agent modification, no build system changes, graceful degradation when files are absent.
*Source: testing-quality-infrastructure (D-2) + language-building-skills (D-1, D-2)*

## Eval Infrastructure

**P40: Protocol schema mismatches are silent eval killers — grep for field names across all protocols.**
When one protocol says `status` and another says `verdict` for the same concept, everything works until a grader reads the wrong field. Two instances in one session: `currentWorkUnit`/`currentWork` (PR #141, context.md vs state.md) and `status`/`verdict` (PR #142, state.md/evidence.md vs gate-verdict.md). After renaming a field in any protocol, grep all protocols and doc files for the old name.
*Source: eval-quality-v2 (WU-01, calibration run 1 → run 2)*

**P41: LLM output parsing must handle the full response distribution, not just the happy path.**
`json.loads` on raw LLM output fails on: markdown code fences (most common), preamble text ("Here is the result: {...}"), and braces inside JSON string values. Multi-strategy extraction (direct → fence-strip → string-aware brace matching) handles the real distribution. The calibration run proved gates worked correctly — only the parser was broken. Score: 0.0 → 1.0 for the same gate output after parser fix.
*Source: eval-quality-v2 (WU-01, _extract_json)*

**P42: Eval fixtures must present symptoms, never diagnoses.**
A `// BUG: Off-by-one` comment in a debug fixture allowed the model to score high by quoting the comment instead of reasoning from test output. Eval discriminative power requires the model to diagnose independently. Remove all comments that name the root cause, describe the fix, or label the planted issue. The symptom (failing test output, error message) is sufficient context.
*Source: eval-quality-v2 (PR #142 review, greptile finding)*

**P43: Use model_grade for LLM-generated evidence, file_contains for structural assertions only.**
`file_contains` with regex on free-text evidence is inherently fragile — agents use descriptive labels where the regex expects CWE IDs. `model_grade` rubrics validate the same content reliably (scored 1.0 while regex scored 0.0 on identical evidence). Reserve `file_contains` for structural assertions (category names, file paths, specific strings) and `model_grade` for quality assessment of prose evidence.
*Source: eval-quality-v2 (WU-01, gate-security CWE regex removal)*
