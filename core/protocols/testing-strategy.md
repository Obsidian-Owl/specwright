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
| `sw-plan` | Spec review includes test type dimension; architect annotates each AC with expected test type |
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
The architect's testability proof for each AC states the expected test type:
`[unit test]`, `[integration test]`, or `[E2E test]`.

### sw-build reads strategy
The tester agent reads TESTING.md alongside the Constitution. For each test:
- Check if the code under test crosses a boundary
- Look up the boundary classification in TESTING.md
- Choose test type accordingly (real component for internal, mock for external/expensive)
- Report the rationale in test output

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
| Unit | `go test ./...` | Internal logic, isolated functions |
| Integration | `go test ./... -tags=integration` | Internal boundaries: database, message queue, cache |
| Smoke | `make test-eval-smoke` | Application starts, critical paths respond |
```

This section is omitted when no tiered commands are configured. The table connects
"TESTING.md says database is an internal boundary" to "which command actually tests that."

## When TESTING.md Does Not Exist

Skills proceed without it. The Constitution's testing rules remain the sole
authority. TESTING.md is recommended but not required — projects that don't
run sw-init (or decline TESTING.md generation) still have the Constitution.
