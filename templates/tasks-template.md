# Tasks: {EPIC_ID} {EPIC_NAME}

**Total Tasks:** {TASK_COUNT}
**Parallel Opportunities:** {PARALLEL_NOTES}

---

## Foundational (Sequential - Must complete first)

### T001: {TASK_DESCRIPTION}
**Deliverable:** {FILE_PATH_OR_BEHAVIOR}
**Wiring:** {WHAT_IMPORTS_OR_USES_THIS}
**Verification:** {HOW_TO_TEST}

### T002: {TASK_DESCRIPTION}
**Deliverable:** {FILE_PATH_OR_BEHAVIOR}
**Wiring:** {WHAT_IMPORTS_OR_USES_THIS}
**Verification:** {HOW_TO_TEST}

---

## US-001: {STORY_TITLE} (After foundational)

### T003: {TASK_DESCRIPTION}
**Deliverable:** {FILE_PATH_OR_BEHAVIOR}
**Wiring:** {WHAT_IMPORTS_OR_USES_THIS}
**Verification:** {HOW_TO_TEST}

### T003-WIRE: Verify T003 integrated
**Check:** {VERIFICATION_COMMAND_OR_SEARCH}
**Pass:** {EXPECTED_RESULT}

---

## Wiring Verification (Final gate before epic complete)

### T-WIRE-001: All new exports are imported
**Check:** Search for each new exported symbol across codebase
**Pass:** Each export has at least one import/usage

### T-WIRE-002: All tests pass
**Check:** Run test command from config.json
**Pass:** Zero failures, zero skipped

---

## Completion Checklist

```
Build & Test:
- [ ] Build succeeds with zero errors
- [ ] All tests pass
- [ ] Zero skipped tests

Wiring:
- [ ] All new exports imported/used
- [ ] All new public interfaces consumed
- [ ] Integration points verified

Spec Compliance:
- [ ] US-001 acceptance criteria met
- [ ] US-002 acceptance criteria met
```

---

## Notes for Agent

1. **Read spec.md and plan.md FIRST** — Don't start without full context
2. **One task at a time** — Complete fully before starting next
3. **Wiring is mandatory** — Every deliverable must be imported/used
4. **Test proves behavior** — Not just "no error"
5. **After compaction** — Re-read ALL spec artifacts immediately
