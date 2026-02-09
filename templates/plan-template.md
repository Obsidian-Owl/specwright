# Implementation Plan: {EPIC_ID} {EPIC_NAME}

---

## Constitution Compliance Check

| Principle | Status | Evidence |
|-----------|--------|----------|
{CONSTITUTION_TABLE}

> This table is populated from your project's constitution principles.
> Each principle should have a status (pending/verified) and evidence of compliance.

---

## Architecture Decisions

### AD-001: {DECISION_TITLE}
**Context:** {WHY_THIS_DECISION_MATTERS}
**Decision:** {WHAT_WE_ARE_DOING}
**Alternatives Considered:** {OTHER_OPTIONS}
**Consequences:**
- Benefit: {BENEFIT}
- Tradeoff: {TRADEOFF}

---

## File Structure

```
{PROPOSED_FILE_STRUCTURE}
```

> Align with architecture layers defined in `.specwright/config.json`.

---

## Dependencies

### Required Before Starting
- [ ] {PREREQUISITE_1}
- [ ] {PREREQUISITE_2}

### External
- {EXTERNAL_DEPENDENCY_OR_NONE}

---

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| {RISK} | Low/Med/High | Low/Med/High | {MITIGATION} |

---

## Verification Plan

### During Implementation
- After each file: Run build command
- After each feature: Run test command
- Continuously: Verify wiring (new code is referenced)

### Epic Completion
- [ ] Build succeeds with zero errors
- [ ] All tests pass
- [ ] `/specwright:validate` all gates pass
- [ ] Integration proof documented
- [ ] Architect review APPROVED
