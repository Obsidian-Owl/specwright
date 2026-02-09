---
name: specify
description: >-
  Epic specification. Produces spec.md, plan.md, and tasks.md for one epic
  with user stories, architecture decisions, and complexity-scored task breakdown.
argument-hint: "<epic-id>"
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Specwright Specify: Epic Specification Workflow

Creates comprehensive specification artifacts for a single epic.

## Arguments

- `$ARGUMENTS`: Epic ID (e.g., "user-auth", "payment-integration", "dashboard-v2")

## Prerequisites

- `.specwright/config.json` exists (run `/specwright:init` first)
- `.specwright/memory/constitution.md` exists

## Workflow

### Phase 1: Context Loading

Read all relevant context before specification begins:

1. **Project Configuration**
   - Read `.specwright/config.json` for language, framework, architecture rules, commands

2. **Core Memory**
   - Read `.specwright/memory/constitution.md` (non-negotiable principles)
   - Read `.specwright/memory/patterns.md` (cross-epic learnings)

3. **Domain Context**
   - If `.specwright/domains/` contains relevant roadmaps, read them
   - Search for existing module/service CONTEXT.md files relevant to this epic

4. **Related Epics**
   - Search `.specwright/epics/` for completed epics with similar scope
   - Read their spec/plan/tasks for pattern reuse

5. **Architecture Context**
   - Use Grep/Glob to understand existing project structure
   - Identify modules, services, packages relevant to this epic
   - Read config.json `architecture.layers` for layer rules

### Phase 2: Epic Directory Setup

Create the epic directory:
```bash
mkdir -p ".specwright/epics/${EPIC_ID}/"
mkdir -p ".specwright/epics/${EPIC_ID}/evidence/"
```

### Phase 3: Produce spec.md (User Stories)

**Delegate to architect agent** for spec generation.

**Agent Delegation:**

Read `.specwright/config.json` `integration.omc` to determine delegation mode.

**If OMC is available** (`integration.omc` is true):
Use the Task tool with `subagent_type` to delegate to the OMC architect agent:

    subagent_type: "oh-my-claudecode:architect"
    description: "Generate spec for epic"
    prompt: |
      {the full prompt content below}

**If OMC is NOT available** (standalone mode):
Use the Task tool with `model` to delegate directly:

    prompt: |
      {same full prompt content below}
    model: "opus"
    description: "Generate spec for epic"

**Prompt for architect:**
```
Produce a user story specification for epic ${EPIC_ID}.

Context loaded:
- Constitution principles: {summary of principles from constitution.md}
- Established patterns: {summary from patterns.md}
- Project config: {language, framework, architecture from config.json}
- Related epics: {list of similar completed epics}

Follow the template at .specwright/templates/spec-template.md.

Requirements:
1. Epic title and clear scope boundary
2. User stories in format: "As a [user], I want [feature], so that [benefit]"
3. Acceptance criteria per story (measurable, testable)
4. Out-of-scope items (explicitly excluded)
5. References to existing patterns in the codebase

Output spec.md content.
```

**Validation:**
- Verify spec.md contains at least 2 user stories
- Verify each story has acceptance criteria
- Verify out-of-scope section exists

Write spec.md to `.specwright/epics/${EPIC_ID}/spec.md`

### Phase 4: User Approval Gate

Present spec.md summary to user:

```
Specification ready for epic ${EPIC_ID}:

{display spec.md summary -- story count, scope, estimate}

Review: .specwright/epics/${EPIC_ID}/spec.md

Approve to continue to architectural planning?
```

Use AskUserQuestion:
- "Is this specification ready for implementation planning?"
- Options: "Approved -- proceed to planning", "Needs revision -- I'll provide feedback"

**If revision requested:**
- Capture feedback from user
- Re-delegate to architect with feedback
- Repeat Phase 3

**If approved:**
- Proceed to Phase 5

### Phase 5: Produce plan.md (Architecture)

**Delegate to architect agent** for plan generation.

**Agent Delegation:**

Read `.specwright/config.json` `integration.omc` to determine delegation mode.

**If OMC is available** (`integration.omc` is true):
Use the Task tool with `subagent_type` to delegate to the OMC architect agent:

    subagent_type: "oh-my-claudecode:architect"
    description: "Generate plan for epic"
    prompt: |
      {the full prompt content below}

**If OMC is NOT available** (standalone mode):
Use the Task tool with `model` to delegate directly:

    prompt: |
      {same full prompt content below}
    model: "opus"
    description: "Generate plan for epic"

**Prompt for architect:**
```
Produce an implementation plan for epic ${EPIC_ID}.

Approved spec: {spec.md content}

Context:
- Project: {from config.json -- language, framework, architecture style}
- Architecture layers: {from config.json architecture.layers}
- Constitution: {principles from constitution.md}
- Build command: {from config.json commands.build}
- Test command: {from config.json commands.test}

Follow the template at .specwright/templates/plan-template.md.

Requirements:
1. Constitution compliance check -- one row per principle from constitution.md
2. Architecture decisions with context/decision/consequences
3. File structure showing exact deliverables
4. Dependencies (internal and external)
5. Risks and mitigations
6. Verification plan referencing /specwright:validate gates

Output plan.md content.
```

**Validation:**
- Verify plan.md contains constitution compliance table
- Verify architecture decisions documented
- Verify file structure section exists

Write plan.md to `.specwright/epics/${EPIC_ID}/plan.md`

### Phase 6: Produce tasks.md (Task Breakdown)

Generate tasks.md using this algorithm:

1. **Parse Spec** -- Extract user stories, group by priority
2. **Generate Task List:**
   - Foundational tasks (models, interfaces, schemas)
   - Tasks per user story
   - Wiring verification tasks
3. **Complexity Scoring:**
   - Simple (1-2 files, clear pattern): 1-3 points
   - Moderate (multi-file, some unknowns): 4-7 points
   - Complex (multi-module, new patterns): 8-15 points
4. **Task Format:**
   ```
   ### T###: {description}
   **Deliverable:** {file path or behavior}
   **Wiring:** {what imports/uses this}
   **Verification:** {how to test}
   **Complexity:** {1-15}
   ```
5. **Wiring Tasks** -- Add T-WIRE-### tasks after deliverables
6. **Completion Checklist** -- Build, test, wiring, spec compliance

Follow template at `.specwright/templates/tasks-template.md`.

Write tasks.md to `.specwright/epics/${EPIC_ID}/tasks.md`

### Phase 7: Create Feature Branch

Read branch prefix from `.specwright/config.json` `git.branchPrefix`:

```bash
git checkout -b "${branchPrefix}${EPIC_ID}"
```

### Phase 8: Update Workflow State

Read and update `.specwright/state/workflow.json`:

```json
{
  "version": "1.0",
  "currentEpic": {
    "id": "${EPIC_ID}",
    "name": "${EPIC_NAME}",
    "branch": "${branchPrefix}${EPIC_ID}",
    "specDir": ".specwright/epics/${EPIC_ID}",
    "status": "specified",
    "createdAt": "{ISO_TIMESTAMP}"
  },
  "tasksCompleted": [],
  "tasksFailed": [],
  "currentTasks": [],
  "gates": {
    "build": {"status": "pending", "lastRun": null, "evidence": null},
    "tests": {"status": "pending", "lastRun": null, "evidence": null},
    "wiring": {"status": "pending", "lastRun": null, "evidence": null},
    "security": {"status": "pending", "lastRun": null, "evidence": null},
    "spec": {"status": "pending", "lastRun": null, "evidence": null}
  },
  "lock": null,
  "lastUpdated": "{ISO_TIMESTAMP}"
}
```

Note: Only populate gates that are enabled in `config.json` `gates.enabled`.

### Phase 9: Commit Spec Artifacts

Read commit format from `.specwright/config.json` `git.commitFormat`:

```bash
git add ".specwright/epics/${EPIC_ID}/spec.md"
git add ".specwright/epics/${EPIC_ID}/plan.md"
git add ".specwright/epics/${EPIC_ID}/tasks.md"
git add ".specwright/state/workflow.json"

git commit -m "spec(${EPIC_ID}): epic specification complete

- User stories with acceptance criteria
- Architecture plan with constitution compliance
- Task breakdown with complexity scoring

Next: /specwright:build to begin implementation

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Phase 10: Completion Summary

```
Epic specification complete: ${EPIC_ID}

Artifacts:
- spec.md:  {story count} user stories
- plan.md:  {decision count} architecture decisions
- tasks.md: {task count} tasks, complexity score {total}

Branch: ${branchPrefix}${EPIC_ID}
Next: /specwright:build to begin implementation

Files:
- .specwright/epics/${EPIC_ID}/spec.md
- .specwright/epics/${EPIC_ID}/plan.md
- .specwright/epics/${EPIC_ID}/tasks.md
```

## Compaction Recovery Protocol

If context compaction occurs during specification:

1. Read `.specwright/state/workflow.json` -> check `currentEpic`
2. If status is "specified" or has spec artifacts:
   - Re-read constitution and patterns
   - Check which artifacts exist in the epic directory
   - Resume from the point of interruption:
     - spec.md exists -> Resume at Phase 4 (user approval) or Phase 5 (plan)
     - plan.md exists -> Resume at Phase 6 (tasks)
     - tasks.md exists -> Resume at Phase 7 (branch creation)

## Error Handling

| Error | Recovery |
|-------|----------|
| Missing config.json | Error: "Run /specwright:init first" |
| Missing constitution.md | Error: "Run /specwright:init first" |
| Domain roadmap not found | Warning: Continue without domain context |
| Architect delegation fails | Retry with simplified prompt |
| User rejects spec | Iterate with feedback |
| Git branch exists | Checkout existing branch, continue |
