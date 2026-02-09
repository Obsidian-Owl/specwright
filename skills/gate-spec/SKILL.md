---
name: gate-spec
description: >-
  Spec compliance verification. Maps each acceptance criterion from spec.md
  to implementation evidence. Flags unverified criteria as FAIL.
argument-hint: "[epic-id]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Specwright Gate: Spec Compliance

Verifies that every acceptance criterion in the spec has corresponding implementation and test evidence.

Default verdict is FAIL. Evidence must be cited before any verdict. Absence of evidence is evidence of non-compliance.

## Step 1: Read Configuration and State
Read `.specwright/config.json` for `integration.omc` (agent delegation mode).
Read `.specwright/state/workflow.json` to get current epic and specDir.
If no epic active, STOP: "No active epic. Run /specwright:specify first."

## Step 2: Load Spec
Read `.specwright/epics/{specDir}/spec.md` and extract all acceptance criteria.
Parse lines matching `- [ ]` or `- [x]` under "Acceptance Criteria" headings.
Build a numbered list of all criteria.

## Step 3: Map Criteria to Evidence

Delegate to code-reviewer agent for thorough mapping.

**Agent Delegation:**

Read `.specwright/config.json` `integration.omc` to determine delegation mode.

**If OMC is available** (`integration.omc` is true):
Use the Task tool with `subagent_type`:

    subagent_type: "oh-my-claudecode:code-reviewer"
    description: "Map spec to evidence"
    prompt: |
      Map acceptance criteria to implementation evidence.

      Acceptance Criteria:
      {numbered criteria list}

      Project root: {cwd}
      Changed files: {git diff --name-only}

      For EACH criterion, provide:
      1. Status: PASS / FAIL / WARN
      2. Test name and file:line that verifies it
      3. Implementation file:line reference
      4. Reason if FAIL or WARN

      Rules:
      - Criterion with no corresponding test = FAIL
      - Criterion with test that doesn't actually assert the behavior = WARN
      - Criterion with clear test coverage = PASS

**If OMC is NOT available** (standalone mode):
Use the Task tool with `model`:

    prompt: |
      Map acceptance criteria to implementation evidence.

      Acceptance Criteria:
      {numbered criteria list}

      Project root: {cwd}
      Changed files: {git diff --name-only}

      For EACH criterion, provide:
      1. Status: PASS / FAIL / WARN
      2. Test name and file:line that verifies it
      3. Implementation file:line reference
      4. Reason if FAIL or WARN

      Rules:
      - Criterion with no corresponding test = FAIL
      - Criterion with test that doesn't actually assert the behavior = WARN
      - Criterion with clear test coverage = PASS
    model: "opus"
    description: "Map spec to evidence"

## Step 4: Parse Evidence Response
Extract mapping from code-reviewer response.
Count PASS / FAIL / WARN statuses.

## Step 5: Update Gate Status

**Self-critique checkpoint:** Before finalizing — did I accept anything without citing proof? Did I give benefit of the doubt? Would a skeptical auditor agree? Gaps are not future work. TODOs are not addressed. Partial implementations do not match intent. If ambiguous, FAIL.

Update `.specwright/state/workflow.json` `gates.spec`:
```json
{
  "status": "PASS|FAIL",
  "lastRun": "<ISO-timestamp>",
  "evidence": "{specDir}/evidence/spec-compliance.md",
  "verified": {pass_count},
  "unverified": {fail_count}
}
```

## Step 6: Write Evidence Report
Create `{specDir}/evidence/spec-compliance.md`:
```markdown
# Spec Compliance Report
Generated: {timestamp}

## Summary
- Total Criteria: {total}
- Verified (PASS): {pass_count}
- Unverified (FAIL): {fail_count}
- Warnings: {warn_count}

## Criteria Mapping

### Criterion 1: {description}
- Status: PASS
- Test: {test name} ({file}:{line})
- Implementation: {file}:{line}

### Criterion 2: {description}
- Status: FAIL
- Reason: No test found verifying this behavior
```

## Step 7: Output Result
```
SPEC GATE: {PASS|FAIL}
Criteria: {total} total, {verified} verified, {unverified} unverified
Evidence: {specDir}/evidence/spec-compliance.md

{if FAIL: List unverified criteria}
```
