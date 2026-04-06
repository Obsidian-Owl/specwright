# Testing Strategy Protocol

How testing decisions flow through the Specwright pipeline. The testing strategy
is captured in `.specwright/TESTING.md` and consumed by skills and agents
throughout the workflow.

## Precedence

Three documents govern testing decisions, in descending authority:

1. **Constitution** (`CONSTITUTION.md`) — Mandatory rules. Always wins on conflict.
2. **Testing Strategy** (`TESTING.md`) — Project-specific approach. Refines Constitution rules for this project's domain, boundaries, and infrastructure.
3. **Patterns** (`patterns.md`) — Reference library. Informational, not authoritative.

If TESTING.md says "mock the payment gateway" but Constitution says "mock only at
system boundaries," Constitution prevails. TESTING.md may document the rationale
for why a specific boundary is treated as external (making it consistent with
Constitution), but it cannot override Constitution rules.

## Consuming Skills

| Skill | How it uses TESTING.md |
|-------|----------------------|
| `sw-init` | **Creates** TESTING.md from stack detection + user conversation |
| `sw-design` | May reference TESTING.md when identifying integration boundaries in context.md (no SKILL.md change required — design already scans anchor docs) |
| `sw-plan` | Spec review includes test type dimension; architect annotates each AC with a tier tag (`[tier: unit]`, `[tier: integration]`, `[tier: contract]`, `[tier: e2e]`) |
| `sw-build` | Tester reads TESTING.md to decide mock vs. integration for each test |
| `sw-verify` | gate-tests validates that test approach matches TESTING.md strategy |
| `sw-learn` | Testing patterns promoted to TESTING.md (not just patterns.md) |

## Boundary Classifications

Three categories for classifying dependencies and integration points:

### Internal

Dependencies you own and control. Test with real components, no mocks.

**Description**: Code paths within your project that cross module or layer boundaries. The dependency is your own source code, running in the same process or a test harness you control.

**Example**: A service layer calling a repository layer → integration test imports the real repository module and operates on a real (test) database. No mock repository.

### External

Dependencies you do not own or control. Mock with contracts or recorded responses.

**Description**: Third-party APIs, vendor services, or partner systems whose behavior you cannot guarantee. Mocking is appropriate because the real service may be unavailable, rate-limited, or non-deterministic.

**Example**: A Stripe payment API → mock with recorded responses or contract tests (Pact). The real Stripe API is not called during tests, but the contract verifies your code matches Stripe's published interface.

### Expensive

Dependencies you could test live but choose not to for cost, time, or resource reasons. Mock with explicit rationale documented in TESTING.md.

**Description**: Services that are technically available but prohibitively expensive to call per test run — metered APIs, slow external services, or resource-intensive operations. Must be explicitly justified in TESTING.md's Mock Allowances section.

**Example**: An OpenAI API call at $0.01/request → mock with recorded responses for unit tests, but include one scheduled integration test that validates the real API contract weekly. TESTING.md documents: "OpenAI API: mocked in CI (cost), live in weekly integration suite."

## Tier Classification

Four tiers classify how acceptance criteria (ACs) are tested. The architect annotates each AC with a `[tier: X]` tag during sw-plan. Untagged ACs default to unit tier.

### Tiers

| Tier | Classification Rule |
|------|---------------------|
| **unit** | Tests a single unit in isolation — no external dependencies, no boundary crossings, no process calls. Pure functions and self-contained logic qualify. |
| **integration** | Tests code that crosses an internal boundary (service → repository, module → database, layer → cache). Uses real components; no mocks of internal dependencies. |
| **contract** | Validates your code against an external API or third-party interface schema. Tests the wire format and response contract without calling the live service. |
| **e2e** | Exercises a complete user flow or critical system path from entry point to outcome. Validates the full system behaves correctly end-to-end. |

### Boundary-to-Tier Mapping

TESTING.md boundary classifications map to tier tags as follows:

| Boundary | Tier | Notes |
|----------|------|-------|
| Internal boundary | `[tier: integration]` | Own code crossing module/layer lines — test with real components |
| External boundary | `[tier: contract]` | Third-party API or vendor interface — validate contract, mock the live call |
| Expensive boundary | `[tier: unit]` (default) | Mocked per TESTING.md Mock Allowances. The regular tester handles these with documented mock rationale. If the user reclassifies an expensive boundary as internal in TESTING.md, it becomes `[tier: integration]` and the integration tester takes over — the user accepts the cost/infra requirement explicitly. |

Expensive boundaries default to `unit` tier (mocked) because the integration tester enforces a strict no-mock, no-skip policy. Routing expensive dependencies to the integration tester would produce guaranteed failures in CI where the service is unavailable. The user can override this by reclassifying a boundary as internal in TESTING.md — a conscious decision to accept the cost.

### Annotation Format

Annotate each AC with `[tier: unit]`, `[tier: integration]`, `[tier: contract]`, or `[tier: e2e]` inline:

```
AC-1: Parser rejects malformed input [tier: unit]
AC-2: Repository saves record to database [tier: integration]
AC-3: Client handles Stripe error responses [tier: contract]
AC-4: User can complete checkout flow [tier: e2e]
```

Acceptance criteria without a tier annotation default to unit tier. When the architect has evidence that an AC crosses a boundary, they must tag it explicitly.

## Pipeline Flow

### sw-init creates TESTING.md
After detecting the stack, sw-init asks the user about:
- External services the project calls (payment, email, auth providers)
- Test database strategy (in-memory, testcontainers, shared test DB, none)
- Rate-limited or cost-attached APIs
- Any other expensive dependencies

Generates `.specwright/TESTING.md` with three required sections:
- **Boundaries**: Internal, external, and expensive classifications
- **Test Infrastructure**: Available test databases, containers, fixtures
- **Mock Allowances**: Which dependencies may be mocked and documented rationale

### sw-design identifies boundaries
During design research, the designer identifies integration boundaries in
context.md and classifies each using TESTING.md's three categories.

### sw-plan annotates test types
The spec review protocol includes a "Test Type Appropriateness" dimension.
The architect annotates each AC with a tier tag using the `[tier: X]` format:
`[tier: unit]`, `[tier: integration]`, `[tier: contract]`, or `[tier: e2e]`.
Untagged ACs default to unit tier.

### sw-build reads strategy
sw-build uses tier-aware delegation: ACs tagged `[tier: unit]` (or untagged) go to
the tester agent; ACs tagged `[tier: integration]`, `[tier: contract]`, or `[tier: e2e]`
go to the integration-tester agent. Both agents read TESTING.md for boundary context.
The tester agent mocks external and expensive boundaries per TESTING.md allowances.
The integration-tester agent uses real infrastructure with no skip conditions.

### sw-verify validates approach
gate-tests checks that the test approach matches TESTING.md:
- Boundaries classified as `internal` should have integration tests (not mocked)
- Violations are WARN findings
- If TESTING.md does not exist, boundary validation is skipped (INFO)

### sw-learn updates strategy
When testing patterns are discovered during build (e.g., "mocking the cache layer
hid a serialization bug"), sw-learn offers to promote the insight to TESTING.md.
The "testing" category in sw-learn maps to TESTING.md as a promotion target.

## Test Commands Section

When tiered test commands are configured in `config.json` (`commands.test:integration`,
`commands.test:smoke`), TESTING.md should include a Test Commands section mapping
boundary classifications to executable test tiers:

```markdown
## Test Commands

| Tier | Command | What It Validates |
|------|---------|-------------------|
| Unit | {commands.test} | Internal logic, isolated functions |
| Integration | {commands.test:integration} | Internal boundaries: database, message queue, cache |
| Smoke | {commands.test:smoke} | Application starts, critical paths respond |
```

Replace `{commands.*}` placeholders with actual commands from config.json.

This section is omitted when no tiered commands are configured. The table connects
"TESTING.md says database is an internal boundary" to "which command actually tests that."

## When TESTING.md Does Not Exist

Skills proceed without it. The Constitution's testing rules remain the sole
authority. TESTING.md is recommended but not required — projects that don't
run sw-init (or decline TESTING.md generation) still have the Constitution.
