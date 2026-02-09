# {PROJECT_NAME} Development Constitution

**Version:** 1.0.0
**Status:** Active
**Amendment:** Requires written rationale + maintainer approval

---

## Purpose

This constitution establishes NON-NEGOTIABLE principles for development. All AI agents, automated workflows, and human developers MUST adhere to these principles.

**Override Protocol:** If a principle must be violated, document:
1. Which principle
2. Why violation is necessary
3. Return-to-compliance plan
4. Maintainer approval

---

## Principle I: Working Code Over Done Tasks

**Statement:** A task is NOT complete until the code is integrated, tested, and functional in the system.

**Testable Criteria:**
- [ ] New code is imported/referenced by at least one other module
- [ ] Tests pass covering the change
- [ ] New public interfaces are callable and documented
- [ ] New event handlers/subscribers are registered (if applicable)

**Anti-Patterns:**
- Marking task "done" because file was created
- Stub implementations without TODO tracking
- Tests that pass but don't verify actual behavior

---

## Principle II: Tests Prove Behavior

**Statement:** Tests verify the system works correctly, not just that code exists.

**Testable Criteria:**
- [ ] Tests use realistic fixtures, not hardcoded magic values
- [ ] Tests verify observable behavior (responses, state changes, outputs)
- [ ] Zero skipped tests without documented justification
- [ ] Test names describe the behavior being verified

**Anti-Patterns:**
- Tests that only check "no error returned"
- Mocking away the thing being tested
- Tests that pass with empty implementations

---

## Principle III: Specification Before Implementation

**Statement:** Code changes require documented specification loaded into context before implementation begins.

**Testable Criteria:**
- [ ] Epic has spec.md with user stories and acceptance criteria
- [ ] Epic has plan.md with architecture decisions
- [ ] Agent loads spec artifacts BEFORE writing code
- [ ] After compaction, agent IMMEDIATELY reloads spec context

**Anti-Patterns:**
- Implementing based on chat history alone
- Assuming requirements from function names
- Continuing after compaction without rereading specs

---

## Principle IV: Incremental Value Delivery

**Statement:** Each epic delivers testable, user-visible value. No "infrastructure only" epics.

**Testable Criteria:**
- [ ] Epic completion enables a user action or observable improvement
- [ ] Changes are demonstrable (API response, UI change, measurable metric)
- [ ] Integration tests prove the user story works

**Anti-Patterns:**
- Multi-week "setup" phases with no visible output
- Completing data layer without corresponding interfaces
- Building internal plumbing without user-facing features

---

## Amendment History

| Version | Date | Change | Rationale |
|---------|------|--------|-----------|
| 1.0.0 | {DATE} | Initial constitution | Establish quality-first development principles |

---

> **Customization:** Add your own principles below. Each principle should have:
> 1. A clear statement
> 2. Testable criteria (checkboxes)
> 3. Anti-patterns to avoid
