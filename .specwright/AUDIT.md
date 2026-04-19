# Codebase Audit

Snapshot: 2026-04-06T12:00:00Z
Scope: full (prompt engineering, context engineering, eval coverage)
Dimensions: architecture, complexity, consistency, debt
Findings: 20 open (5B, 8W, 7I), 9 resolved

## Summary

The skill and agent corpus is well-structured with strong patterns in gate skills and utility skills. However, a month of rapid development has introduced prompt engineering drift: procedural steps leaking into declarative skills (violating Charter invariant 1), agent scope boundaries that don't match tool access, protocol references to phantom or misnamed infrastructure, and an eval framework that tests scaffolding but not skill quality. The most critical theme is that new capabilities (semantic gates, repo maps, feedback loops, calibration) were shipped without any eval coverage validating they work.

## Findings

### [BLOCKER] F19: Procedural steps in sw-build violate Charter invariant 1

- **Dimension**: consistency
- **Location**: `core/skills/sw-build/SKILL.md:57-67`
- **Description**: The "Branch setup (LOW freedom)" constraint contains 7 bullet points of if/else procedural logic ("If exists: git checkout... If not: checkout baseBranch, pull latest, create branch"). Charter invariant 1 states: "SKILL.md files define goals and constraints. They never contain step-by-step procedures." A declarative version would state the postcondition ("A feature branch matching the naming convention exists and is checked out, up to date with the base branch") and reference the git protocol for mechanics.
- **Impact**: Sets precedent for procedural leakage across skills. The sw-design state mutations block (lines 93-104) shows the same pattern spreading.
- **Recommendation**: Rewrite as postcondition + protocol reference. Apply the same treatment to sw-design's state mutation block.
- **Status**: open

### [BLOCKER] F20: context.md references nonexistent state field `currentWorkUnit`

- **Dimension**: consistency
- **Location**: `core/protocols/context.md:140`
- **Description**: The pre-work-unit check uses `state.currentWorkUnit` but the state protocol schema (`core/protocols/state.md:12`) defines the field as `currentWork`. Any skill following context.md's initialization guard will check an undefined field, silently skipping the precondition that should block work-unit operations when no work is active.
- **Impact**: Skills could proceed without active work, corrupting state. The guard exists to prevent exactly this.
- **Recommendation**: Change `currentWorkUnit` to `currentWork` in context.md line 140.
- **Status**: open

### [BLOCKER] F21: gate-security and gate-semantic have overlapping CWE coverage

- **Dimension**: architecture
- **Location**: `core/skills/gate-security/SKILL.md:55-59`, `core/skills/gate-semantic/SKILL.md:63-64`
- **Description**: gate-security Phase 3 checks "fail-open error handling (CWE-636)" and "error data leakage (CWE-209)." gate-semantic checks the same CWEs at Tier 1+. gate-semantic line 68 states "No overlap with gate-security" but the CWE IDs are identical. Users will see duplicate findings for the same issues.
- **Impact**: Duplicate findings erode trust in gate quality. Users may dismiss valid findings as noise.
- **Recommendation**: Assign each CWE to exactly one gate. Semantic gate should own these (it has tiered tooling); security gate should defer to semantic for code-level CWE analysis and focus on secrets/injection/exposure.
- **Status**: open

### [BLOCKER] F22: Executor and build-fixer agents lack git prohibition

- **Dimension**: architecture
- **Location**: `core/agents/specwright-executor.md:27-33`, `core/agents/specwright-build-fixer.md:27-30`
- **Description**: Both agents have Bash access and "What you never do" sections, but neither prohibits git operations. The executor could commit, push, or create branches. The build-fixer could commit its own fixes. Both would break the atomic commit model governed by the git protocol. The constitution requires "fragile operations must use shared protocols" and git is explicitly protocol-governed.
- **Impact**: A confused model with Bash access and no explicit git prohibition could commit code outside the skill's commit orchestration, breaking traceability.
- **Recommendation**: Add "Never run git commands (commit, push, checkout, branch, reset, etc.)" to both agents' "What you never do" sections.
- **Status**: open

### [BLOCKER] F14: Zero unit tests for hook handlers with security-critical logic

- **Dimension**: debt
- **Location**: `adapters/claude-code/hooks/subagent-context.mjs`, `post-write-diagnostics.mjs`, `session-start.mjs`
- **Description**: Three JavaScript hook handlers have zero unit tests. `subagent-context.mjs` contains security-critical path traversal validation that is never exercised. `post-write-diagnostics.mjs` has subprocess invocation with `execFileSync` and multi-branch platform detection. `session-start.mjs` has regex parsing for correction summary extraction. The `\Z` regex bug (caught by PR review) would have been caught by a unit test.
- **Impact**: Security bugs in path validation, silent failures in regex parsing, and incorrect subprocess handling go undetected.
- **Recommendation**: Create `tests/test-hooks.mjs` covering path traversal inputs, agent-type routing, code/non-code file filtering, and correction summary extraction.
- **Status**: open (carried from prior audit)

### [WARNING] F23: sw-build token bloat at ~1,450 words with 14 constraint blocks

- **Dimension**: complexity
- **Location**: `core/skills/sw-build/SKILL.md`
- **Description**: sw-build is the longest skill by 2x (sw-design ~750, sw-plan ~800, sw-ship ~400). It carries 14 named constraint blocks. The "Context envelope" block (lines 104-119) repeats information in the delegation protocol. The "Behavioral reminder" (line 117) is a vague instruction ("surface confusion, prefer simplicity") with no observable postcondition -- it's an aspirational nudge, not a constraint.
- **Impact**: Every sw-build invocation consumes excessive context tokens. The behavioral reminder cannot be verified by any gate.
- **Recommendation**: Remove the behavioral reminder. Compress the context envelope to reference the delegation protocol rather than restating it. Target 1,000 words.
- **Status**: open

### [WARNING] F24: gate-wiring cross-unit section is a 112-line runbook

- **Dimension**: complexity
- **Location**: `core/skills/gate-wiring/SKILL.md:58-170`
- **Description**: The cross-unit integration section spans 112 lines with shell commands (`git merge-base`, `git diff`), code fences, and detailed algorithmic steps. At ~1,100 words total, gate-wiring is nearly as large as sw-design. This reads as a runbook, not a constraint specification.
- **Impact**: A gate invoked inline by sw-verify should be compact. This is the most procedural content in any skill file.
- **Recommendation**: Extract cross-unit logic to a protocol. The skill should declare the postcondition ("all cross-unit integration points verified") and reference the protocol for mechanics.
- **Status**: open

### [WARNING] F25: Reviewer agent described as READ-ONLY but has Bash

- **Dimension**: consistency
- **Location**: `core/agents/specwright-reviewer.md:12-13`, `core/agents/specwright-reviewer.md:27`
- **Description**: The reviewer's description says "READ-ONLY" and its prompt says "you are READ-ONLY for source files," but its tool list includes Bash. The prompt says to "Run build and test commands to verify," which explains Bash's presence. But the READ-ONLY framing is misleading -- Bash can write files, delete things, or run destructive commands.
- **Impact**: If the model interprets "READ-ONLY" loosely, it might still run destructive commands via Bash.
- **Recommendation**: Change framing to "Read-only for source files. Bash restricted to verification commands (build, test, lint). Never modify, create, or delete files via shell."
- **Status**: open

### [WARNING] F26: Inconsistent freedom level labels ("STRICT" vs LOW/MEDIUM/HIGH)

- **Dimension**: consistency
- **Location**: `core/skills/sw-review/SKILL.md:99`, `core/skills/sw-sync/SKILL.md:99`
- **Description**: Both skills use "STRICT" as a freedom level label. Every other skill uses LOW/MEDIUM/HIGH. "STRICT" is undefined in the freedom taxonomy and creates ambiguity.
- **Impact**: Inconsistent vocabulary undermines the calibration system.
- **Recommendation**: Replace "STRICT" with "LOW" in both skills.
- **Status**: open

### [WARNING] F27: sw-plan failure mode is copy-paste from sw-design

- **Dimension**: consistency
- **Location**: `core/skills/sw-plan/SKILL.md:145`
- **Description**: "Apply DISAMBIGUATION: argument provided -> start new. No argument -> continue." This logic applies to sw-design (which takes an optional problem statement argument). sw-plan always operates on existing design artifacts -- it doesn't have a "start new" path triggered by arguments.
- **Impact**: An LLM following this instruction would attempt disambiguation logic that doesn't apply, potentially confusing the user.
- **Recommendation**: Replace with the correct sw-plan behavior for active work conflicts.
- **Status**: open

### [WARNING] F28: Write-only decision records with no downstream validation

- **Dimension**: debt
- **Location**: `core/protocols/decision.md:76-112`
- **Description**: The decision protocol defines a decision record format and a gate handoff template that skills should produce. No downstream skill or gate checks for the presence, format, or content of these artifacts. The format is write-only with no verification path.
- **Impact**: Compliance is honor-system. Decision records may never be written and no gate would catch the gap.
- **Recommendation**: Either add decision record checks to gate-spec's evidence mapping, or acknowledge the advisory nature in the protocol.
- **Status**: open

### ~~[WARNING] F15: No eval coverage for semantic gate, repo map, or feedback loops~~

- **Status**: resolved (eval-quality-v2)
- **Resolution**: Gate-semantic eval fixture with 3 planted bugs (CWE-636, CWE-209, resource lifecycle) created in PR #141. Calibrated in run-20260406T090613: 100% pass rate. Gate-security and gate-tests fixtures also added. Repo map and feedback loop evals remain uncovered (deferred).

### ~~[WARNING] F29: Eval framework tests scaffolding, not skill quality~~

- **Status**: resolved (eval-quality-v2)
- **Resolution**: 8 skill evals (was 5), 3 gate evals (was 0 working), 4 subagent quality rubrics, per-expectation model_grade thresholds, negative eval (malformed spec). model_grade used in 10+ expectations across suites. Grading infrastructure fixed (verdict/status, robust JSON extraction). Workflow evals still PENDING (separate work).

### [INFO] F30: Single-consumer protocols should be inlining candidates

- **Dimension**: complexity
- **Location**: `core/protocols/build-context.md` (sw-build only), `core/protocols/convergence.md` (sw-design only), `core/protocols/learning-lifecycle.md` (sw-learn only), `core/protocols/repo-map.md` (sw-build only), `core/protocols/spec-review.md` (sw-plan only)
- **Description**: Five protocols serve a single consumer skill each. The Charter states protocols exist for shared fragile operations. These add indirection without reuse benefit. Total: ~500 lines of single-consumer protocol content.
- **Impact**: Cognitive overhead. Context tokens consumed for indirection.
- **Recommendation**: In the next design cycle, evaluate consolidating back into skill constraints or merging related protocols (e.g., repo-map.md into build-context.md).
- **Status**: open (supersedes F12, F18)

### [INFO] F10: Config languages field incomplete

- **Dimension**: consistency
- **Location**: `.specwright/config.json:6`
- **Description**: Now declares `["markdown", "javascript", "python", "shell", "typescript"]` -- this was fixed since the last audit.
- **Status**: resolved

### [INFO] F11: Orphaned .orphaned_at file in repo root

- **Dimension**: debt
- **Location**: `.orphaned_at`
- **Description**: Untracked file containing a timestamp. Not referenced by any code.
- **Status**: open (carried)

### [INFO] F31: Lang-building patterns are high quality but untested

- **Dimension**: consistency
- **Location**: `core/skills/lang-building/*.md`
- **Description**: The five language pattern files (Go, Java, Python, Rust, TypeScript) are well-structured with idioms, type patterns, framework conventions, and anti-patterns. They are loaded by sw-build into agent context. No eval verifies that loading these patterns improves build quality for the target language.
- **Impact**: Unknown whether these patterns measurably improve output vs. the LLM's baseline knowledge.
- **Recommendation**: Add a comparative eval: same build task, with and without lang-building context, graded by model_grade for language idiom compliance.
- **Status**: open

### [INFO] F32: Workflow evals are all PENDING with no seed repos

- **Dimension**: debt
- **Location**: `evals/suites/workflow/evals.json`
- **Description**: All 5 workflow evals reference `seed_id` values ending in `-PENDING`. No seed repos have been verified or made available. The SWE-bench-style test structure (PASS_TO_PASS/FAIL_TO_PASS) is designed but not operational.
- **Impact**: Layer 3 (end-to-end workflow) evaluation is completely non-functional.
- **Recommendation**: See Eval Strategy section below.
- **Status**: open

### [INFO] F33: Protocol suite is well-designed in pockets

- **Dimension**: architecture
- **Location**: `core/protocols/semi-formal-reasoning.md`, `core/protocols/headless.md`, `core/protocols/stage-boundary.md`
- **Description**: Three protocols stand out for quality: semi-formal-reasoning.md has explicit graceful degradation (lines 64-72). headless.md has complete policy tables for non-interactive fallbacks. stage-boundary.md honestly states "This is strong guidance backed by state validation, not hard enforcement" (line 39). These represent the target quality bar.
- **Impact**: Positive. These should be the template for new protocols.
- **Status**: open (informational)

## Eval Strategy Assessment

The current eval framework tests **plumbing** (do files end up in the right places?) but not **quality** (does Specwright produce better software engineering outcomes than raw LLM usage?). This is the fundamental gap.

### Current State

| Layer | Evals | Status |
|-------|-------|--------|
| Skill (unit) | 1 (sw-build) | Minimal: tests file creation only |
| Integration (handoff) | 3 | Functional: tests state transitions and artifact references |
| Workflow (E2E) | 5 | Non-functional: all PENDING |
| Gate | 0 | No gate-specific evals at all |
| Quality (model-graded) | 1 expectation | Single `model_grade` check in design-to-plan |

### What's Missing

1. **Gate evals**: No eval tests whether gates catch known bugs, flag real security issues, or produce accurate verdicts. This is the highest-priority gap -- gates are Specwright's core value proposition.
2. **Quality evals**: Only 1 of 11 expectation types uses LLM-as-judge (`model_grade`). The rest are deterministic checks that can't assess output quality.
3. **Negative evals**: No eval presents a known-bad input and asserts the correct failure mode fires. All evals test the happy path.
4. **Comparative evals**: No eval compares Specwright-guided output vs. raw LLM output on the same task.

### External Benchmark Assessment

| Benchmark | Measures | Relevance | Maturity | Integration Effort |
|-----------|----------|-----------|----------|-------------------|
| **FeatureBench** | Feature implementation in real codebases | HIGH -- tests exactly what Specwright aims to improve | LOW -- 45 stars, ICLR 2026, v0.1 | Separate CLI harness, Docker required, wrapper needed |
| **SWE-bench Verified** | Bug resolution in Python repos | MEDIUM -- tests fix quality, not feature development | HIGH -- industry standard, well-documented | Separate Python harness, Docker 3-layer isolation |
| **SWE-bench Pro** | Bug resolution across 41 repos | MEDIUM -- multi-language, but still bug-fix scoped | MEDIUM -- partially proprietary | Same as SWE-bench |
| **Terminal-bench** | Multi-step terminal tasks | LOW -- tests CLI proficiency, not software engineering | LOW -- Anthropic-internal | Not publicly available |

**Recommendation**: FeatureBench is the right conceptual fit (feature development > bug fixing) but too immature to adopt now. SWE-bench Verified is the pragmatic choice for an external benchmark -- it's stable, well-documented, and has Claude Code agent adapters. Neither replaces the need for Specwright-specific quality evals.

### Proposed Eval Roadmap

1. **Immediate**: Add gate evals -- fixtures with known bugs/security issues, assert gates catch them
2. **Near-term**: Expand `model_grade` usage across all skill evals for output quality assessment
3. **Near-term**: Add negative evals (known-bad inputs, assert correct failure modes)
4. **Medium-term**: Activate workflow evals with real seed repos (start with 1, not 5)
5. **Medium-term**: Integrate SWE-bench Verified as an external benchmark via wrapper harness
6. **Monitor**: Revisit FeatureBench when it reaches v1.0 or 200+ stars

## Resolved

- **F1** (BLOCKER -> resolved): Core sw-build platform-specific tools -> platform markers. *audit-remediation/platform-markers*
- **F3** (WARNING -> resolved, partial): Adapter skill divergence -> sw-build override removed, sw-guard remains. *audit-remediation/platform-markers*
- **F5** (WARNING -> resolved): Stale work artifacts -> sw-status --cleanup + sw-learn clear. *audit-remediation/work-lifecycle*
- **F6** (WARNING -> resolved): Zero claude-code test coverage -> 152-assertion test suite + CI. *audit-remediation/claude-code-tests*
- **F9** (WARNING -> resolved): Stale workflow state -> shipped -> (none) transition via sw-learn. *audit-remediation/work-lifecycle*
- **F2** (WARNING -> resolved): Undocumented convergence.md -> added to all doc indexes. *audit-cleanup*
- **F4** (WARNING -> resolved): sw-build size ceiling -> Context management extracted to protocol, body under 1,200 words. *audit-cleanup*
- **F7** (WARNING -> resolved): Missing opencode adapter docs -> added to DESIGN.md directory structure. *audit-cleanup*
- **F8** (WARNING -> resolved): Config version mismatch -> bumped to 2.0, version check in context.md. *audit-cleanup*
- **F10** (INFO -> resolved): Config languages field updated to include python, shell, typescript.
- **F12/F18** (INFO -> superseded by F30): Protocol count tracking consolidated.
