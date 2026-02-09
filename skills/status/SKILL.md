---
name: status
description: >-
  Show current Specwright workflow status. Displays active epic,
  task progress, gate results, and learning queue size.
---

# Specwright Status: Workflow Dashboard

Displays current project status at a glance. No arguments needed.

## Step 1: Check Initialization

Check if `.specwright/config.json` exists.
If not: output "Specwright not initialized. Run /specwright:init first." and STOP.

## Step 2: Read Configuration

Read `.specwright/config.json` for project name and enabled gates.

## Step 3: Read Workflow State

Read `.specwright/state/workflow.json`.

## Step 4: Gather Status Information

### Active Epic
If `currentEpic` exists and status is not "complete":
- Epic ID and name
- Current status (specified, in-progress, tasks-complete, shipped)
- Branch name
- Spec directory path

If no active epic: "No active epic."

### Task Progress
If an active epic exists, read `{specDir}/tasks.md`:
- Count total tasks (T### pattern)
- Count completed from `tasksCompleted` in workflow.json
- Count failed from `tasksFailed`
- Show progress: "X/Y tasks complete (Z failed)"

### Gate Results
For each enabled gate in config:
- Read status from workflow.json gates object
- Show PASS/FAIL/PENDING with last run timestamp

### Learning Queue
Read `.specwright/state/learning-queue.jsonl`:
- Count lines (entries)
- Show count and suggest review if >= 5

### Constitution
Read `.specwright/memory/constitution.md`:
- Count principles (## Principle headings)
- Show last modified date

### Recent Git Activity
```bash
git log --oneline -5
```
Show last 5 commits on current branch.

## Step 5: Display Dashboard

```
=== Specwright Status ===

Project: {name}
Languages: {from config}
Architecture: {style}

--- Active Epic ---
{epic-id}: {epic-name}
Status: {status}
Branch: {branch}
Progress: {completed}/{total} tasks ({failed} failed)

--- Quality Gates ---
Build:    {PASS/FAIL/PENDING}  {last run or "not run"}
Tests:    {PASS/FAIL/PENDING}  {last run or "not run"}
Wiring:   {PASS/FAIL/PENDING}  {last run or "not run"}
Security: {PASS/FAIL/PENDING}  {last run or "not run"}
Spec:     {PASS/FAIL/PENDING}  {last run or "not run"}

--- Learning ---
Queue: {N} entries pending
{if >= 5: "Run /specwright:learn-review to process"}

--- Constitution ---
{N} principles defined
Last updated: {date}

--- Recent Commits ---
{last 5 commits}
```

If no active epic, simplify the output to show only project info, learning queue, and constitution status.
