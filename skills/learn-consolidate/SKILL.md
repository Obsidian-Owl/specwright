---
name: learn-consolidate
description: >-
  Consolidate learning queue into reusable patterns. Groups similar entries,
  scores by frequency and recency, promotes top candidates to patterns.md.
argument-hint: "[--dry-run] [--force]"
---

# Specwright Learn Consolidate

Analyzes the learning queue, groups similar entries, scores them, and promotes high-value patterns to the project's pattern library with human approval.

## Arguments

Parse `$ARGUMENTS`:
- **Empty**: Auto-consolidate if queue has 10+ entries
- `--force`: Consolidate regardless of queue size
- `--dry-run`: Show what would be consolidated without applying changes

## Step 1: Load and Parse Queue

Read `.specwright/state/learning-queue.jsonl`. Parse each line as JSON.

**Error Handling**:
- Skip malformed lines and track count
- If queue is empty or below threshold (10 entries) and `--force` not specified, output count and STOP

**Expected Fields per Entry**: `command`, `pattern` (optional), `context` (optional), `resolution` (optional), `timestamp`, `type` (error/correction/discovery).

## Step 2: Group Similar Entries

Group entries by similar `command` or `pattern` field using keyword-based similarity.

**Grouping Logic**:
1. Extract keywords from command/pattern (split on whitespace and special chars)
2. Compare keyword sets between entries
3. Entries with >60% keyword overlap are grouped together
4. Count occurrences per group

## Step 3: Score Candidates

For each group, calculate score:

```
score = (count * 2 + recency_bonus) * type_multiplier
```

**Scoring Rules:**
- `count`: Number of entries in the group
- `recency_bonus`: +3 if most recent entry is within last 24 hours, +1 if within last week, 0 otherwise
- `type_multiplier`: error = 1.0, correction = 1.5, discovery = 2.0

**Filtering**:
- Keep only groups with 3+ occurrences
- Sort by score descending
- Take top 5 candidates

## Step 4: Deduplicate Against Existing

Read `.specwright/memory/patterns.md` to avoid duplicates.

1. Extract all existing pattern titles (## headings)
2. For each candidate, compare title keywords to existing patterns
3. Skip candidates with >60% keyword overlap with existing patterns

## Step 5: Present Candidates

For each candidate (up to 5), present to user:

```
Pattern: {Derived pattern name}
Occurrences: {count}
Score: {calculated score}

Representative Examples:
1. {command/error from first occurrence}
   Context: {what was being attempted}
   Resolution: {how it was fixed}

2. {command/error from second occurrence}
   Context: {what was being attempted}
```

**User Decision** (use AskUserQuestion):
- **Promote**: Add to patterns.md
- **Dismiss**: Mark as noise
- **Skip**: Leave in queue

**CRITICAL**: NEVER auto-promote patterns without human approval.

## Step 6: Apply Changes

Skip entirely if `--dry-run`.

### For Promoted Patterns
Append to `.specwright/memory/patterns.md`:
```markdown
## {Pattern Name}

**Observed**: {count} times (score: {score})
**Type**: {error|correction|discovery}

**Context**: {Common context across occurrences}

**Solution**:
- {Step 1}
- {Step 2}

**Example Commands**:
```bash
{representative command 1}
{representative command 2}
```
```

### For Dismissed Patterns
Append to `.specwright/state/learning-dismissed.jsonl` with `dismissed_at` timestamp.

### Archive and Clean Queue
1. Archive processed entries to `.specwright/state/learning-archive-{timestamp}.jsonl`
2. Rewrite `.specwright/state/learning-queue.jsonl` with only unprocessed entries

## Step 7: Report Summary

```
Learning Consolidation Complete

Entries processed: {total}
Patterns promoted: {count}
Patterns dismissed: {count}
Already documented: {count}
Malformed entries skipped: {count}
Remaining in queue: {count}
```

## File Locations

| File | Purpose |
|------|---------|
| `.specwright/state/learning-queue.jsonl` | Active learning queue (input) |
| `.specwright/memory/patterns.md` | Project pattern library (output) |
| `.specwright/state/learning-dismissed.jsonl` | Dismissed noise patterns |
| `.specwright/state/learning-archive-{ts}.jsonl` | Archived processed entries |
