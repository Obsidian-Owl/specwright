# Research Brief: Multi-Unit Integration Verification & Agent Harness Evolution

Topic-ID: integration-verification
Created: 2026-03-31
Updated: 2026-03-31
Tracks: 3

## Summary

Research into how independently-built work units can be verified for correct integration, what contract/E2E testing patterns apply, and what agent harness changes in March 2026 Specwright could adopt. Key takeaway: no AI coding tool has a dedicated post-assembly wiring verification step — all rely on the project's own CI. This is a gap Specwright can uniquely fill. Claude Code's new subagent features (agent teams, isolation worktrees, conditional hooks) provide the primitives needed to build it.

## Findings

### Track 1: Multi-Unit Integration Verification Patterns

#### F1: Narrow vs. broad integration tests are distinct categories
- **Claim**: Integration tests split into narrow (cross-module communication code with test doubles) and broad (live services, full code paths). These are "two different things" commonly conflated.
- **Evidence**: Martin Fowler's Integration Test bliki explicitly distinguishes these and warns against treating them as one category.
- **Source**: https://martinfowler.com/bliki/IntegrationTest.html
- **Confidence**: HIGH
- **Potential assumption**: No

#### F2: Interface mismatch is a primary defect class only surfaced by integration testing
- **Claim**: Mismatched data formats, protocol versions, and communication standards between modules are a named defect type that unit tests cannot catch.
- **Evidence**: Integration testing literature consistently identifies interface mismatch and wrong sequencing as primary defect types.
- **Source**: https://www.toolsqa.com/software-testing/integration-testing/
- **Confidence**: MEDIUM
- **Potential assumption**: No

#### F3: TypeScript compiler as cross-module wiring gate
- **Claim**: Running `tsc --noEmit` catches import and interface mismatch errors across all modules without runtime. This is a documented CI gate practice.
- **Evidence**: CircleCI official docs recommend type-checking before merge as the "most critical step."
- **Source**: https://circleci.com/blog/enforce-type-safety-with-typescript-checks-before-deployments/
- **Confidence**: HIGH
- **Potential assumption**: No

#### F4: No AI coding tool has a dedicated post-assembly wiring verification step
- **Claim**: Cursor, Aider, Devin all rely on the project's own tests, type-checker, and CI for integration verification. None document a purpose-built mechanism for detecting missing imports, disconnected interfaces, or unwired components after multi-unit parallel development.
- **Evidence**: Official docs for all three tools confirm tests + CI as sole verification. Cursor uses worktree isolation but has no merge-time wiring check. Devin waits for CI. Aider's repo map is context-only.
- **Source**: https://docs.devin.ai/, https://aider.chat/docs/, https://cursor.com/blog/agent-best-practices
- **Confidence**: HIGH
- **Potential assumption**: No

#### F5: No standardized "wiring gate" tool category exists
- **Claim**: No established tool or category called "wiring gate" or "integration gate" exists as a distinct CI/CD primitive. The concept is implemented through combinations of type-checking, DI verification, contract tests, and integration smoke tests.
- **Evidence**: Multiple searches across CI/CD vendor documentation returned no official tooling using these terms.
- **Source**: Multiple CI/CD vendor docs (none used this terminology)
- **Confidence**: HIGH
- **Potential assumption**: No

#### F6: Vertical slice architecture reduces but doesn't eliminate cross-unit wiring
- **Claim**: VSA makes each feature self-contained, reducing integration surface. But slices that must communicate (shared domain events, shared data) still require integration verification.
- **Evidence**: VSA docs state "new features only add code, you're not changing shared code" — describes intra-slice isolation, not cross-slice guarantees.
- **Source**: https://www.milanjovanovic.tech/blog/vertical-slice-architecture
- **Confidence**: MEDIUM
- **Potential assumption**: Yes — VSA doesn't eliminate integration; it minimizes it

### Track 2: Contract & E2E Testing Patterns

#### F7: Pact is designed for service boundaries, not intra-repo module wiring
- **Claim**: Pact targets inter-service HTTP and message-based boundaries (microservices). It does not address intra-process module wiring such as missing imports or incompatible in-process interfaces.
- **Evidence**: All Pact docs frame consumer/provider at the network level. All examples involve HTTP or async message protocols.
- **Source**: https://docs.pact.io/
- **Confidence**: HIGH
- **Potential assumption**: No

#### F8: Pact's `can-i-deploy` is a binary CI gate for cross-service contracts
- **Claim**: The Pact Broker's `can-i-deploy` CLI exits 0 (safe) or 1 (blocked) based on whether all contracts for the target environment are verified. Primary mechanism for blocking merges on broken cross-service wiring.
- **Evidence**: Official Pact Broker documentation describes the exit code semantics.
- **Source**: https://docs.pact.io/pact_broker/can_i_deploy
- **Confidence**: HIGH
- **Potential assumption**: No

#### F9: Schema-based contracts sacrifice guarantees for simplicity
- **Claim**: Schema-based contract tests (OpenAPI validation) are faster to set up but "sacrifice a level of guarantees" compared to code-executed Pact contracts. Schemas "can't fully capture HTTP semantics" and introduce ambiguity.
- **Evidence**: PactFlow official blog explicitly describes this tradeoff.
- **Source**: https://pactflow.io/blog/contract-testing-using-json-schemas-and-open-api-part-1/
- **Confidence**: HIGH
- **Potential assumption**: No

#### F10: Specmatic converts API specs into executable contract tests without code
- **Claim**: Specmatic takes OpenAPI, AsyncAPI, gRPC proto, and GraphQL schemas and auto-generates test combinations. Also generates service stubs for dependency isolation. Closest existing tool to "synthetic integration tests from interface definitions."
- **Evidence**: Official Specmatic documentation describes the generation and stub mechanism.
- **Source**: https://docs.specmatic.io/contract_driven_development/contract_testing.html
- **Confidence**: HIGH
- **Potential assumption**: No

#### F11: Playwright v1.58 — component testing still experimental
- **Claim**: As of v1.58 (January 30, 2026), Playwright component testing remains "experimental." Supports React, Vue, Svelte. Complex live objects cannot be passed to components due to the Node.js/browser boundary.
- **Source**: https://playwright.dev/docs/test-components
- **Confidence**: HIGH
- **Potential assumption**: No

#### F12: Testcontainers Docker Compose module for multi-service wiring verification
- **Claim**: Testcontainers' `ComposeContainer` launches all services from a `docker-compose.yml`, provides service discovery, and supports per-service wait strategies. Verification is behavioral — no static analysis, but real containerized services exercised through test code.
- **Source**: https://java.testcontainers.org/modules/docker_compose/
- **Confidence**: HIGH
- **Potential assumption**: No

#### F13: TypeScript JSON Schema derivation for contract drift detection
- **Claim**: Pattern: generate JSON Schema from TypeScript interfaces via `typescript-json-schema`, commit schemas, run `json-schema-diff` in CI. Detects structural drift without runtime tests. Low-maintenance but doesn't generate runtime integration tests.
- **Source**: https://pactflow.io/blog/contract-testing-using-json-schemas-and-open-api-part-1/
- **Confidence**: MEDIUM
- **Potential assumption**: No

#### F14: Neither Turborepo nor Nx generates cross-package integration tests
- **Claim**: Both are task orchestrators that run whatever tests packages define. Cross-package contract verification must be implemented separately. Nx has "task sandboxing" that detects undeclared dependencies — Turborepo doesn't.
- **Source**: https://turborepo.dev/docs/crafting-your-repository/configuring-tasks, https://nx.dev/docs/guides/adopting-nx/nx-vs-turborepo
- **Confidence**: HIGH
- **Potential assumption**: No

### Track 3: Agent Harness Evolution — March 2026

#### F15: Claude Code agent teams shipped (February 6, 2026)
- **Claim**: `TeammateTool` enables multiple Claude Code instances to coordinate across separate sessions, each with independent context and isolated git worktree. Distinct from subagents (which work within a single session).
- **Source**: https://claudefa.st/blog/guide/agents/agent-teams
- **Confidence**: HIGH
- **Potential assumption**: No

#### F16: Claude Code subagent system fully documented
- **Claim**: Custom subagents defined in Markdown with YAML frontmatter in `.claude/agents/`. Support `isolation: worktree`, `memory: user|project|local`, model overrides, tool restrictions, and `maxTurns`. Subagents cannot spawn other subagents.
- **Source**: https://code.claude.com/docs/en/sub-agents
- **Confidence**: HIGH
- **Potential assumption**: No

#### F17: Claude Code hooks expansion — conditional filtering and new events
- **Claim**: New hook events: `TaskCreated`, `CwdChanged`, `FileChanged`, `StopFailure`, `SubagentStart`, `SubagentStop`, `SessionStart`. Conditional `if` field using permission rule syntax. HTTP hooks (POST JSON, receive JSON). `PreToolUse` hooks can satisfy `AskUserQuestion`.
- **Source**: https://releasebot.io/updates/anthropic/claude-code
- **Confidence**: HIGH
- **Potential assumption**: No

#### F18: Plugin subagent security restrictions
- **Claim**: Plugin subagents cannot define `hooks`, `mcpServers`, or `permissionMode` in frontmatter — these fields are silently ignored. Users must copy subagent files to `.claude/agents/` for full capability.
- **Source**: https://releasebot.io/updates/anthropic/claude-code
- **Confidence**: HIGH
- **Potential assumption**: No

#### F19: GitHub Copilot Coding Agent — only harness with built-in verification gates
- **Claim**: Copilot Coding Agent automatically runs project tests, linter, CodeQL, dependency scanning, and secret scanning. If problems found, it attempts self-correction before requesting human review. Configurable from Settings > Copilot > Coding agent (March 18, 2026).
- **Source**: https://github.blog/changelog/2026-03-18-configure-copilot-coding-agents-validation-tools/
- **Confidence**: HIGH
- **Potential assumption**: No

#### F20: A2A protocol complements MCP for agent-to-agent communication
- **Claim**: Google's A2A protocol handles agent-to-agent delegation across organizational boundaries. MCP handles agent-to-resource (tool/data access). Both are gaining industry adoption. AAIF has 146 members including Anthropic.
- **Source**: https://developers.googleblog.com/en/a2a-a-new-era-of-agent-interoperability/
- **Confidence**: HIGH
- **Potential assumption**: No

## Conflicts & Agreements

**Agreement — AI tools rely on external CI for integration**: All researched tools (Cursor, Aider, Devin, Copilot) converge on the same pattern: integration verification is outsourced to the project's CI. No tool has an internal post-assembly wiring verification layer. Copilot goes furthest with built-in gates but these are standard CI checks (tests, lint, CodeQL), not spec-level or wiring-level verification.

**Agreement — type-checking as primary cross-module gate**: Multiple sources independently identify `tsc --noEmit` or equivalent compiler checks as the primary automated mechanism for catching interface mismatches.

**Conflict — contract testing applicability**: Pact targets service-level HTTP/message boundaries. This is not directly applicable to intra-process module wiring within a single application. Different tools needed for different boundary types.

**Conflict — schema vs. code-based contracts**: PactFlow explicitly documents that schema-based approaches "sacrifice guarantees" vs. code-executed contracts. Teams must choose based on their boundary type and risk tolerance.

**Agreement — worktrees as isolation primitive**: Claude Code, Cursor, and Devin all converge on git worktrees as the isolation mechanism for parallel agent work. The merge-time verification gap is the common unsolved problem.

## Open Questions

1. **Intra-process wiring verification for dynamic languages**: No tools found for detecting missing imports or disconnected module wiring in JavaScript/Python outside of compiler-based checking (TypeScript). Whether such tools exist was not resolved.

2. **Cross-slice VSA integration testing**: When two vertical slices must interact via shared events or data, no documentation describes how to verify the connection after both are built independently.

3. **Agent teams for verification**: Claude Code's agent teams are documented for parallel work, but not for post-assembly verification coordination. Whether team members can inspect each other's worktree changes before merge is undocumented.

4. **MCP for wiring verification**: No MCP server was found that specifically addresses code wiring verification (import resolution, interface matching). The 50+ servers in Claude Code's directory are primarily for external service integration.

5. **Specwright's unique position**: No competitor implements spec-level verification. GitHub Copilot's gates are standard CI checks. Specwright's gate system (build, tests, security, wiring, semantic, spec) is architecturally unique — the question is how to extend the wiring and spec gates to cover multi-unit integration.
