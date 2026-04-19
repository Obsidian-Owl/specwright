# Research Brief: Guardrails Strategy for sw-guard

Topic-ID: guardrails-strategy
Created: 2026-03-20
Updated: 2026-03-20
Tracks: 4

## Summary

Researched how to make sw-guard produce deeper, wider, deterministic guardrails across agent hooks and traditional software quality tools. Evidence from the Strands Agents steering paper shows 100% accuracy with deterministic hook-based steering vs 82.5% with prompt instructions (600 eval runs). A four-layer enforcement model (agent session, pre-commit, pre-push, CI) is well-established, with each layer catching violations the others cannot. Both Claude Code (21+ hook events in settings.json) and Opencode (TypeScript plugin system with tool.execute.before/after) support generation-time enforcement. Stack detection and gap analysis are solvable via manifest + config file scanning without hardcoding.

## Findings

### Track 1: Steering via Hooks

#### F1: Deterministic steering achieves 100% accuracy vs 82.5% for prompt instructions
- **Claim**: Hook-based steering that intercepts tool calls at decision moments achieves 100% accuracy across 600 evaluation runs, compared to 82.5% for prompt-based instructions and 80.8% for graph-based workflows.
- **Evidence**: "100% accuracy pass rate across 600 evaluation runs, compared to 82.5% for simple prompt-based instructions and 80.8% for graph-based workflows."
- **Source**: https://strandsagents.com/blog/steering-accuracy-beats-prompts-workflows/
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F2: Claude Code supports 21+ hook events with PreToolUse blocking capability
- **Claim**: Claude Code hooks support 21+ events including PreToolUse (can block via exit code 2 or permissionDecision deny), PostToolUse (feedback only), SessionStart/End, Stop, SubagentStart/Stop, TaskCompleted, TeammateIdle, PreCompact/PostCompact, and more. Hooks can be command, http, prompt, or agent type.
- **Evidence**: Official hooks reference lists PreToolUse, PostToolUse, PostToolUseFailure, UserPromptSubmit, SessionStart, SessionEnd, Stop, StopFailure, Notification, SubagentStart, SubagentStop, PermissionRequest, TeammateIdle, TaskCompleted, ConfigChange, WorktreeCreate, WorktreeRemove, PreCompact, PostCompact, Elicitation, ElicitationResult, InstructionsLoaded.
- **Source**: https://code.claude.com/docs/en/hooks
- **Confidence**: HIGH
- **Version/Date**: 2026-03
- **Potential assumption**: no

#### F3: PreToolUse hooks can rewrite tool parameters before execution
- **Claim**: The hookSpecificOutput.updatedInput field allows a PreToolUse hook to modify tool call parameters before execution (e.g., replacing "git add -A" with "git add src/").
- **Evidence**: "updatedInput in hookSpecificOutput allows a PreToolUse hook to rewrite the tool's parameters before execution."
- **Source**: https://code.claude.com/docs/en/hooks
- **Confidence**: HIGH
- **Version/Date**: 2026-03
- **Potential assumption**: no

#### F4: Opencode uses TypeScript plugins instead of JSON hooks
- **Claim**: Opencode chose a plugin system over hooks. Plugins are TypeScript modules in .opencode/plugins/ that return hooks keyed by event name (tool.execute.before, tool.execute.after, session.*, message.*, file.edited, permission.*, lsp.*, command.executed). Blocking is via throwing in tool.execute.before.
- **Evidence**: Opencode maintainer closed hooks request as "completed via plugins" (GitHub issue #1473). Plugin docs at opencode.ai/docs/plugins/.
- **Source**: https://opencode.ai/docs/plugins/
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F5: Session-level steering causes declining violation rates within a session
- **Claim**: When hooks block violations mid-session, the agent's violation rate declines because blocked-then-fixed examples accumulate in the context window, creating in-context learning. In one observed 50-file session, hooks blocked 12 times in the first 20 writes and twice in the last 30.
- **Evidence**: "In a recent 50-file session, the hook blocked 12 times in the first 20 writes and twice in the last 30."
- **Source**: https://www.paulmduvall.com/claude-code-hooks-code-quality-guardrails/
- **Confidence**: MEDIUM
- **Version/Date**: 2026
- **Potential assumption**: yes — observational data from single implementation, not controlled study

### Track 2: Traditional Guard Patterns

#### F6: pre-commit (Python tool) is most generalisable for multi-language repos
- **Claim**: The pre-commit framework manages isolated per-hook language environments automatically for 17+ language handlers (Python, Node, Go, Rust, Ruby, Perl, R, Lua, Julia, etc.) and has the largest community hook registry. Lefthook is most generalisable for teams wanting speed and no Python dependency (single Go binary). Husky is JS/TS only.
- **Evidence**: pre-commit.com lists native handlers for Python, Node, Go, Rust, Ruby, Perl, R, Lua, Julia, Haskell, Swift, Dotnet, Conda, Coursier, Dart, Docker.
- **Source**: https://pre-commit.com/
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F7: Zero-config tools exist for most ecosystems
- **Claim**: Several tools work with zero or near-zero configuration: Ruff (Python lint+format), Oxlint (JS/TS, 520+ rules), Biome (JS/TS lint+format), Clippy+rustfmt (Rust, built into toolchain), golangci-lint (Go, 5 default linters). Java has no zero-config equivalent.
- **Evidence**: "golangci-lint can be used with zero configuration." (golangci-lint.run). "Oxlint runs at approximately 10,000 files per second" with 520+ rules enabled by default (voidzero.dev). Ruff defaults: line-length 88, Pyflakes + pycodestyle rules.
- **Source**: https://golangci-lint.run/, https://voidzero.dev/posts/announcing-oxlint-1-stable, https://docs.astral.sh/ruff/configuration/
- **Confidence**: HIGH
- **Version/Date**: 2025-2026
- **Potential assumption**: no

#### F8: No universal cross-language architectural guardrail tool exists
- **Claim**: Architectural boundary enforcement is language-specific: dependency-cruiser (JS/TS), ArchUnit (Java bytecode), PyTestArch (Python imports), Depguard (Go via golangci-lint), Nx module boundaries (Nx monorepos). No tool spans multiple language ecosystems.
- **Evidence**: Each tool's documentation specifies language scope. No cross-language equivalent found in search.
- **Source**: https://github.com/sverweij/dependency-cruiser, https://www.archunit.org/, https://zyskarch.github.io/pytestarch/latest/
- **Confidence**: HIGH
- **Version/Date**: 2025-2026
- **Potential assumption**: no

### Track 3: Hook + Guard Integration

#### F9: Four-layer model with distinct catch domains is well-established
- **Claim**: Agent session hooks catch spec drift mid-session, dangerous ops before execution, and real-time pattern steering. Pre-commit catches anything that slipped through across sessions with deterministic enforcement. Pre-push catches aggregate quality properties (coverage). CI provides clean-room reproducibility, history scanning, and deployment validation.
- **Evidence**: "The pre-commit hook is essential because, unlike a Claude Code skill, it is deterministic." (microservices.io). "Prompts are suggestions. Claude can be convinced to ignore them. Hooks are different...Exit code 2 = blocked. No negotiation." (paddo.dev).
- **Source**: https://microservices.io/post/architecture/2026/03/09/genai-development-platform-part-1-development-guardrails.html, https://paddo.dev/blog/claude-code-hooks-guardrails/
- **Confidence**: HIGH
- **Version/Date**: 2026-03
- **Potential assumption**: no

#### F10: Secret scanning is the exception to "don't triplicate"
- **Claim**: Secret scanning at PreToolUse (catches before filesystem), pre-commit (catches in staged diff), and CI (catches in full history) is genuinely additive because each layer covers a different attack surface. Most other checks should not be triplicated.
- **Evidence**: GitGuardian article identifies history scanning as CI-only capability. Multiple sources identify PreToolUse as only place to catch secrets before filesystem write.
- **Source**: https://blog.gitguardian.com/automated-guard-rails-for-vibe-coding/
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F11: Hooks >300ms per file write cause developers to disable them
- **Claim**: Agent session hooks that take more than ~300ms per file write noticeably slow the session and lead to developers disabling hooks. Fast fixers (formatters) should run as PostToolUse (auto-correct, no blocking penalty). Full lint runs belong at pre-commit.
- **Evidence**: "100-300ms overhead per hook invocation" observed in paulmduvall.com implementation. Pixelmojo: "Reserve deep verification for CI/CD; keep local hooks fast."
- **Source**: https://www.paulmduvall.com/claude-code-hooks-code-quality-guardrails/, https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns
- **Confidence**: MEDIUM
- **Version/Date**: 2026
- **Potential assumption**: yes — threshold is from single implementation

#### F12: Hook security CVEs exist — project-level hooks are an attack surface
- **Claim**: In February 2026, Check Point Research disclosed CVEs (CVE-2025-59536, CVE-2026-21852, CVE-2026-24887) showing hooks in .claude/settings.json as attack vectors when malicious project files defined auto-executing hooks without user confirmation.
- **Evidence**: paddo.dev references the CVE disclosures and discusses implications for project-level hook trust.
- **Source**: https://paddo.dev/blog/claude-code-hooks-guardrails/
- **Confidence**: HIGH
- **Version/Date**: 2026-02
- **Potential assumption**: no

### Track 4: Generalisable Detection

#### F13: Config file presence is the most reliable single-signal detection method
- **Claim**: A mapping of ~50 config filenames to tools provides the most reliable stack detection. Examples: biome.json → Biome, ruff.toml → Ruff, .golangci.yml → golangci-lint, clippy.toml → Clippy, .prettierrc → Prettier, jest.config.ts → Jest, vitest.config.ts → Vitest.
- **Evidence**: MegaLinter's descriptor model uses active_only_if_file_found for conditional activation. Nx plugins register glob patterns per tool. Both validate this approach at scale.
- **Source**: https://megalinter.io/latest/json-schemas/descriptor.html, https://nx.dev/docs/concepts/inferred-tasks
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F14: Manifest [tool.*] sections in pyproject.toml directly identify configured tools
- **Claim**: PEP 518 reserves the [tool.*] namespace in pyproject.toml for third-party tools. Any key under [tool.*] directly identifies a configured tool (e.g., [tool.ruff], [tool.mypy], [tool.pytest.ini_options]).
- **Evidence**: PEP 518 specification. Ruff, mypy, pytest documentation all reference pyproject.toml [tool.*] configuration.
- **Source**: https://docs.astral.sh/ruff/configuration/, https://pydevtools.com/handbook/reference/pyproject/
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F15: Existing guardrail detection requires checking 6+ locations
- **Claim**: Detecting existing guardrails requires checking: .husky/ directory, lefthook.yml, .pre-commit-config.yaml, .claude/settings.json hooks key, .opencode/plugins/, .github/workflows/*.yml (plus GitLab, CircleCI, Jenkins equivalents), and .git/hooks/ for manually installed hooks.
- **Evidence**: Each framework's documentation specifies its config location. Claude Code hooks reference specifies settings file locations.
- **Source**: https://code.claude.com/docs/en/hooks, https://pre-commit.com/, https://github.com/evilmartians/lefthook
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

#### F16: Gap analysis maps detected stack against 9 enforcement dimensions
- **Claim**: Quality enforcement can be assessed against 9 dimensions: formatting, linting, type checking, testing, test coverage, security scanning, secret detection, commit enforcement, CI gate. No authoritative published standard defines this model — it is synthesized from MegaLinter categories and OWASP DevSecOps Guideline.
- **Evidence**: MegaLinter descriptor taxonomy covers formatting, linting, type checking, security. OWASP DevSecOps Guideline covers SAST, DAST, SCA, secret detection.
- **Source**: https://megalinter.io/latest/supported-linters/, https://owasp.org/www-project-devsecops-guideline/
- **Confidence**: MEDIUM
- **Version/Date**: 2026
- **Potential assumption**: yes — synthesized model, not published standard

#### F17: Polyglot monorepos require directory-tree walking, not root-only detection
- **Claim**: Polyglot monorepos may have manifests at different directory levels (e.g., package.json at frontend/, Cargo.toml at backend/). Root-only scanning misses these. Nx and Bazel handle this via per-directory config scanning.
- **Evidence**: Nx inferred tasks documentation: "The plugin will search the workspace for configuration files of the tool. For each configuration file found, the plugin will infer tasks."
- **Source**: https://nx.dev/docs/concepts/inferred-tasks
- **Confidence**: HIGH
- **Version/Date**: 2026
- **Potential assumption**: no

## Conflicts & Agreements

**Agreement**: All sources agree that deterministic enforcement (hooks, git hooks, CI) beats probabilistic guidance (prompt instructions, CLAUDE.md rules) for quality enforcement. The Strands data (100% vs 82.5%), microservices.io ("deterministic"), Knostic ("no system to block output that violates a rule"), and paddo.dev ("exit code 2 = blocked, no negotiation") all converge.

**Agreement**: Multiple sources (paulmduvall.com, Pixelmojo, DEV Community) converge on the four-layer model with distinct purposes per layer.

**Conflict**: Hook event count varies across sources (12 in claudefa.st, 21+ in official docs). Official docs are authoritative; third-party articles reference older versions.

**Conflict**: The "shift-left cost multiplier" (10x-100x) is widely cited but poorly sourced. The Boehm 1976 data shows escalating costs but precise multipliers are contested. The practical argument for generation-time enforcement holds regardless: same-turn fixes are near-zero cost vs 30-60min CI failure cycles.

**Agreement**: No universal architectural guardrail tool exists. All sources are language-specific. This is a genuine gap that sw-guard cannot fill generically.

## Open Questions

1. **What is the real-world performance impact of PostToolUse hooks?** Only one observational report (paulmduvall.com, 100-300ms) exists. No systematic benchmarking across different hook implementations.
2. **How do Opencode plugins handle blocking semantics in practice?** The documentation says throw in tool.execute.before, but no published examples show quality enforcement patterns equivalent to Claude Code hook recipes.
3. **What is the optimal hook set per ecosystem?** No research found comparing different hook configurations for effectiveness. The recommended hooks are synthesized from multiple sources, not empirically validated.
4. **How should sw-guard handle the hook security CVEs?** The CVEs show project-level hooks as attack vectors. Should sw-guard default to .claude/settings.local.json (gitignored) or .claude/settings.json (committable)? The tradeoff is shareability vs security.
5. **Can the 9-dimension coverage model be validated?** It is synthesized from MegaLinter + OWASP, not published as a standard. Real-world validation is needed.
