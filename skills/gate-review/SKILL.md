---
name: gate-review
description: >-
  Behavioral code review gate. Delegates to code-reviewer agent for
  structured review across 7 categories with adversarial evaluation.
argument-hint: "[epic-id]"
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Task
  - mcp__plugin_oh-my-claudecode_omc-tools__ast_grep_search
---

# Specwright Gate: Code Review

Default verdict is FAIL. Evidence must be cited before any verdict. Absence of evidence is evidence of non-compliance.

## Step 1: Read Configuration and State
Read `.specwright/config.json` for `integration.omc`, `commands.build`, `commands.test`.
Read `.specwright/state/workflow.json`. Extract `currentEpic.id`, `currentEpic.specDir`.
If no epic active, STOP: "No active epic. Run /specwright:specify first."

## Step 2: Scope Changed Files
```bash
git diff --name-only main...HEAD
```
Fallback if no upstream: `git diff --name-only HEAD~10`.
If zero changed files: write `gates.review` status `ERROR` with reason "No changed files in scope", STOP.
Filter to source files only (exclude lockfiles, generated output). Target 200-400 LOC review window.

## Step 3: Delegate to Code-Reviewer Agent

Read `{specDir}/spec.md` for acceptance criteria.

Compose delegation brief:

> **Review scope:** {list of changed files from Step 2}
> **Acceptance criteria:** {from spec.md}
> **Evaluate across these 7 categories:**
> 1. **Correctness** — logic errors, off-by-one, race conditions
> 2. **Completeness** — edge cases, error paths, acceptance criteria coverage
> 3. **Security** — input validation, auth checks, injection risks
> 4. **Error handling** — graceful degradation, meaningful messages
> 5. **Complexity/Maintainability** — readability, function length, nesting depth
> 6. **Test quality** — behavioral assertions, meaningful coverage
> 7. **Consistency** — naming conventions, patterns, architecture rules
>
> **Output format:** For each finding: `file:line`, severity (`BLOCK`/`WARN`/`INFO`), category, description. Every category must have at least one finding or explicit "no issues found."

Prefer `ast_grep_search` for structural pattern queries in the brief. If the tool is unavailable, fall back to Grep/Read. MUST NOT fail if ast_grep_search is absent.

**Delegation:**
- If `integration.omc` is true: `subagent_type: "oh-my-claudecode:code-reviewer"`
- Otherwise: native Task with `model: "opus"`

## Step 4: Parse and Evaluate Findings

Collect findings from the code-reviewer response. Every category (all 7) must be represented — if any category is missing from the response, query the reviewer or mark that category as unevaluated (FAIL).

Classify findings by severity:
- `BLOCK` — must fix before merge
- `WARN` — should fix, not blocking
- `INFO` — advisory, no action required

### Anti-Patterns
- **Rubber-stamping:** Must not approve without evidence per category. Every PASS requires a citation.
- **Nitpicking:** Focus on design, logic, and security — not formatting or style preferences.
- **Scope creep:** Review ONLY changed files and their immediate integration points. Do not review unrelated code.

## Step 5: Baseline Check
If `.specwright/baselines/gate-review.json` exists, load it.
- **Matching finding** (same file, line range, category): downgrade BLOCK→WARN, WARN→INFO.
- **Expired baseline** (older than baseline TTL or removed in current diff): retain original severity.
- **Partial match** (same category, different line): use AskUserQuestion to confirm baseline applicability.

## Step 6: Self-Critique Checkpoint
Before finalizing — did I accept anything without citing proof? Did I give benefit of the doubt? Would a skeptical auditor agree? Gaps are not future work. TODOs are not addressed. Partial implementations do not match intent. If ambiguous, FAIL.

## Step 7: Determine Status
- Any `BLOCK` finding remaining after baseline → **FAIL**
- Only `WARN` findings (no BLOCK) → **WARN**
- Only `INFO` or no findings → **PASS**
- Could not complete review (no files, agent failure, missing categories) → **ERROR**

## Step 8: Write Evidence
Write the full review report to `{specDir}/evidence/review-report.md` with:
- Changed files reviewed
- All findings with `file:line` citations, severity, and category
- Baseline adjustments applied (if any)
- Final verdict summary

## Step 9: Update Gate Status
Update `.specwright/state/workflow.json` `gates.review`:
```json
{"status": "<PASS|WARN|FAIL|ERROR>", "lastRun": "<ISO>", "evidence": "{specDir}/evidence/review-report.md"}
```
Update `lastUpdated`.

## Step 10: Output Result
```
REVIEW GATE: <STATUS>
- Files reviewed: N
- Findings: X BLOCK, Y WARN, Z INFO
- Categories evaluated: 7/7
- Baseline adjustments: N applied
- Evidence: {specDir}/evidence/review-report.md
```
