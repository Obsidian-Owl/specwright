# Assumptions

Status: 5/5 resolved

## Blocking

(none)

## Accepted

### A5: Protocol references in SKILL.md files are sufficient to trigger behavior
- **Category**: technical
- **Resolution**: clarify
- **Status**: ACCEPTED
- **Rationale**: User acknowledges this is a risk. Protocol references sometimes get skipped. Accepted as a known risk — the pattern is how Specwright already works, and adding inline behavior would violate the token budget.

## Verified

### A1: Separate architect invocations for scoring are cost-effective
- **Category**: technical
- **Resolution**: clarify
- **Status**: VERIFIED
- **Evidence**: User confirmed 2-3 architect invocations per complex design is acceptable. Simple designs exit on first pass with zero added cost.

### A2: Pre-build + post-task timing for late assumption detection
- **Category**: behavioral
- **Resolution**: clarify
- **Status**: VERIFIED
- **Evidence**: User chose pre-build + post-task (two checkpoint types) over post-task only. Design updated: check assumptions at build start AND after each task commit.

### A3: Narrow criticality rule is sufficient
- **Category**: behavioral
- **Resolution**: clarify
- **Status**: VERIFIED
- **Evidence**: User confirmed narrow-but-precise: only pause when an assumption directly contradicts an acceptance criterion. Fewer pauses preferred over broader coverage.

### A4: Structured mutation analysis is valuable
- **Category**: behavioral
- **Resolution**: clarify
- **Status**: VERIFIED
- **Evidence**: User confirmed that structured output (3 classes with test references) is the key differentiator from the informal self-check, worth the formalization.
