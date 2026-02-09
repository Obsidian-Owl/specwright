---
name: build
description: >-
  TDD implementation loop. Builds each task from the epic tasks.md
  with test-first discipline, wiring verification, and progress tracking.
argument-hint: "[epic-id] [task-id]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
---

# Specwright Build: TDD Implementation Loop

Builds epic tasks one at a time using test-first discipline, wiring verification,
and progress tracking. Each task goes through Red-Green-Refactor, build verification,
wiring check, state update, and commit before proceeding to the next.

## Arguments

Parse `$ARGUMENTS` for:
- **Empty**: Continue from next incomplete task in current epic
- **Epic ID** (e.g., `user-auth`): Switch to that epic, start from first incomplete task
- **Task ID** (e.g., `T003`): Jump to specific task in current epic

## Step 1: Load Context

### 1a. Read Configuration
Read `.specwright/config.json` for:
- `commands.build` — build verification command
- `commands.test` — test execution command
- `architecture.layers` — architecture layer rules
- `git.commitFormat` — commit message format
- `git.branchPrefix` — branch naming
- `project.languages` — file extension patterns
- `integration.omc` — whether OMC agents are available

### 1b. Read Workflow State
Read `.specwright/state/workflow.json`. Extract:
- `currentEpic.id` — active epic
- `currentEpic.specDir` — path to spec artifacts
- `currentEpic.status` — current status
- `tasksCompleted` — already-done task IDs
- `tasksFailed` — previously failed task IDs
- `currentTasks` — in-progress task IDs

If `$ARGUMENTS` contains an epic ID, verify it matches or update `currentEpic`.
If no epic active and no epic argument: STOP with "No active epic. Run `/specwright:specify <epic-id>` first."

### 1c. Read Spec Artifacts
Read these files (STOP if any missing):
- `{specDir}/tasks.md` — task breakdown with IDs, descriptions, deliverables
- `{specDir}/plan.md` — architecture context
- `.specwright/memory/constitution.md` — project principles

### 1d. Read Module Context (Optional)
If working in a specific module/service, check for CONTEXT.md files:
- Read relevant CONTEXT.md if it exists
- This provides domain-specific patterns and conventions

### 1e. Find Target Task
- If task ID in `$ARGUMENTS`: locate that task in tasks.md
- If no task ID: find the first task NOT in `tasksCompleted` or `tasksFailed`
- If all tasks complete: output "All tasks complete. Run `/specwright:validate` to verify." and STOP

## Step 2: Acquire Pipeline Lock

### 2a. Check Existing Lock
Read `lock` field from workflow.json:
- If `lock` is null: proceed to acquire
- If `lock` exists, calculate age from `lock.since`:
  - Age > 30 minutes: auto-clear stale lock, log "Cleared stale lock from {lock.skill}"
  - Age <= 30 minutes: STOP with "Pipeline locked by {lock.skill} since {lock.since}. Use `/specwright:validate --unlock` to force-clear."

### 2b. Write Lock
Update workflow.json:
```json
{
  "lock": {"skill": "build", "since": "<ISO-timestamp>"},
  "currentTasks": ["<task-id>"]
}
```

## Step 3: TDD Implementation

Delegate to executor agent with the following context envelope.

**Agent Delegation:**

Read `.specwright/config.json` `integration.omc` to determine delegation mode.

**If OMC is available** (`integration.omc` is true):
Use the Task tool with `subagent_type`:

    subagent_type: "oh-my-claudecode:executor"
    description: "Execute TDD task"
    prompt: |
      {context envelope below}

**If OMC is NOT available** (standalone mode):
Use the Task tool with `model`:

    prompt: |
      {context envelope below}
    model: "sonnet"
    description: "Execute TDD task"

### Context Envelope for Executor

```
== TASK ==
ID: {task-id}
Description: {task description from tasks.md}
Deliverable: {deliverable from tasks.md}
Acceptance Criteria: {criteria from tasks.md}

== PROJECT CONFIG ==
Language: {from config.json}
Framework: {from config.json}
Build command: {commands.build}
Test command: {commands.test}
Architecture: {architecture.style} with layers: {architecture.layers}

== ARCHITECTURE ==
{relevant section from plan.md for this task}

== MODULE CONTEXT ==
{contents of CONTEXT.md if available, otherwise "N/A"}

== TDD PROTOCOL (MANDATORY) ==

a. RED: Write failing test FIRST
   - Test must fail before any implementation code
   - Tests verify observable behavior, not implementation details
   - Include both happy path and error cases

b. GREEN: Implement MINIMAL code to make test pass
   - Only enough code to satisfy the failing test
   - No optimization, no extra features
   - If more behavior needed, write more tests first

c. REFACTOR: Clean while tests pass
   - Improve code quality without changing behavior
   - Extract helpers only when pattern repeats 3+ times
   - Run tests after every change — they must still pass

d. VERIFY: Run full build and test suite
   - Build command must succeed with zero errors
   - Test command must pass with zero failures

== CONSTRAINTS ==
- Do NOT stub with TODO comments — implement fully or do not create
- Do NOT guess on ambiguous requirements — report "AMBIGUITY: {question}" and STOP
- Follow architecture layer rules from config
- Stage specific files when committing (never git add -A)
```

### Ambiguity Handling
If the executor reports ambiguous or unclear requirements:
- Do NOT guess or assume
- Present the ambiguity to the user with specific options
- Wait for user decision before proceeding

## Step 4: Build Verification

After executor completes, run verification:

### 4a. Build Check
Run the build command from `config.json` `commands.build`.
- If exit code non-zero: delegate to build-fixer agent with the error output

**Agent Delegation:**

Read `.specwright/config.json` `integration.omc` to determine delegation mode.

**If OMC is available** (`integration.omc` is true):
Use the Task tool with `subagent_type`:

    subagent_type: "oh-my-claudecode:build-fixer"
    description: "Fix build error"
    prompt: |
      Fix the following build error:

      {error output}

      Build command: {commands.build}
      Make minimal changes to fix the error. Run build command to verify.

**If OMC is NOT available** (standalone mode):
Use the Task tool with `model`:

    prompt: |
      Fix the following build error:

      {error output}

      Build command: {commands.build}
      Make minimal changes to fix the error. Run build command to verify.
    model: "sonnet"
    description: "Fix build error"

- After build-fixer: re-run build command to confirm fix
- If still failing after 2 fix attempts: mark task as failed, ask user

### 4b. Test Check
Run the test command from `config.json` `commands.test`.
- Parse output for pass/fail/skip counts (let LLM parse — test output format varies by language)
- All must pass, zero skipped
- If failures: delegate to build-fixer agent with test output
- After fix: re-run tests to confirm
- If still failing after 2 fix attempts: mark task as failed, ask user

## Step 5: Quick Wiring Check

Before marking task complete, verify new code is integrated:

### 5a. New Exports
For each new exported symbol (function, class, type, etc.) created by this task:
- Use Grep to search for the symbol across the codebase
- Must appear in 2+ files (definition + at least one usage)
- If only in 1 file: instruct executor to add proper wiring (import/usage)

### 5b. New Public Interfaces
For each new public API, endpoint, or interface:
- Verify it is referenced or consumed somewhere
- Verify documentation exists if required by config

### 5c. Wiring Failure
If wiring check fails and cannot be auto-fixed:
- Log the unwired symbols
- Do NOT mark task complete
- Ask user whether to proceed or fix

## Step 6: Update Workflow State

Update `.specwright/state/workflow.json`:

### On Task Success
```json
{
  "currentTasks": [],
  "tasksCompleted": ["...existing", "<task-id>"],
  "currentEpic": {"...existing", "status": "in-progress"},
  "lastUpdated": "<ISO-timestamp>"
}
```

### On Task Failure
```json
{
  "currentTasks": [],
  "tasksFailed": ["...existing", "<task-id>"],
  "lastUpdated": "<ISO-timestamp>"
}
```

## Step 7: Commit

### 7a. Stage Files
Stage specific changed files. NEVER use `git add -A` or `git add .`.

### 7b. Commit Message
Read `git.commitFormat` from config.json:
- If "conventional": `feat({scope}): {short description} (Task: {task-id})`
- If "freeform": `{task description} (Task: {task-id})`

Include co-author line:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Step 8: Continue or Complete

### 8a. More Tasks Remaining
If incomplete tasks remain:
- Loop back to Step 1e (find next task)
- Keep pipeline lock active
- Output: "Completed {task-id}. Moving to {next-task-id}. ({N}/{total} done)"

### 8b. All Tasks Complete
If all tasks done:
- Release pipeline lock (`lock: null`)
- Update `currentEpic.status` to `"tasks-complete"`
- Output summary:
```
=== BUILD COMPLETE ===
Epic: {epic-id}
Tasks Completed: {count}/{total}
Tasks Failed: {count} (if any)

Next Steps:
  1. Run /specwright:validate to run quality gates
  2. Run /specwright:ship to create PR
```

### 8c. Task Blocked
If a task cannot proceed:
- Document the blocker
- Release pipeline lock
- Ask user for guidance
- Do NOT skip to next task without user approval

## Compaction Recovery Protocol

After context compaction, IMMEDIATELY:
1. Read `.specwright/state/workflow.json` to recover:
   - Current epic ID and specDir
   - Which tasks are completed, failed, in-progress
   - Lock state
2. Read `.specwright/config.json` for commands and architecture
3. Re-read ALL spec artifacts (tasks.md, plan.md, constitution.md)
4. Resume from the next incomplete task

Do NOT rely on conversation history after compaction. The workflow state file is the single source of truth.

## Anti-Patterns

- **"Done" without test**: Every task must have tests proving behavior
- **Stub with TODO**: Implement fully or do not create the code
- **Skip wiring check**: Leads to orphaned, unused code
- **Proceed after compaction without re-reading**: Summaries lose critical details
- **Guess on ambiguity**: Escalate to user, do not assume
- **`git add -A`**: Always stage specific files
- **Write code before test**: TDD means RED comes first, always

## Error Recovery

### Build Failure Loop
If build fails repeatedly (>2 attempts):
1. Capture full error output
2. Release pipeline lock
3. Ask user: "Build failing after 2 fix attempts. Options: (a) manual fix, (b) skip task, (c) abort epic"

### Test Failure Loop
Same pattern as build failure. Include test names and assertion details.

### Lock Contention
If lock acquired but skill interrupted:
- Lock auto-clears after 30 minutes
- User can force-clear with `/specwright:validate --unlock`
