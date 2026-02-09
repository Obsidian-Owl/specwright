---
name: learn-review
description: >-
  Review captured learnings from the queue. Groups by category, promotes to
  patterns.md or CLAUDE.md Memories, or dismisses to archive.
argument-hint: "[--all]"
---

# Specwright Learn Review

Review and triage captured learnings from the queue, promoting valuable patterns to memory.

## Arguments

Parse `$ARGUMENTS`:
- **Empty**: Process next 10 entries (interactive batch)
- `--all`: Process entire queue

## Step 1: Load Queue

Read `.specwright/state/learning-queue.jsonl`. Parse each line as JSON.

**Error Handling**:
- Skip malformed JSONL lines (invalid JSON syntax)
- Track count of malformed entries to report at end
- If queue is empty or all entries malformed, output "No learnings to review." and STOP

**Expected Fields per Entry**: `type` (error/correction/discovery), `timestamp`, `command`, `exitCode`, `context` (optional), `resolution` (optional).

## Step 2: Group by Category

Organize entries into three buckets:

| Category | Entries With | Examples |
|----------|-------------|----------|
| `error` | `type: "error"` | Build failures, test failures, runtime errors |
| `correction` | `type: "correction"` | SDK patterns discovered, framework workarounds |
| `discovery` | `type: "discovery"` | Architectural insights, performance patterns |

Present category summary: "Found N errors, N corrections, N discoveries."

## Step 3: Load Existing Knowledge

Read `.specwright/memory/patterns.md`:
- Extract existing pattern titles from `##` headings
- Store for similarity and contradiction detection

Read `CLAUDE.md`:
- Extract bullet points from `## Memories` section (if exists)
- Store for duplicate detection

## Step 4: Present for Review

For each entry (grouped by category), present:

- **Category**: error/correction/discovery
- **Timestamp**: When captured
- **Command**: The failed command or context
- **Exit Code**: If available
- **Resolution**: Solution if present

**Similarity Detection**:
- If entry resembles existing pattern title: flag "Similar to existing pattern: {name}"
- If entry contradicts existing pattern: warn "CONTRADICTS existing pattern: {name}"
- If entry matches existing memory: note "Already memorized: {text}"

**User Decision** (use AskUserQuestion with 4 options):
1. **Promote** — Append formatted entry to `.specwright/memory/patterns.md`
2. **Memorize** — Append one-liner to `CLAUDE.md` under `## Memories` section
3. **Dismiss** — Archive to `.specwright/state/learning-dismissed.jsonl`
4. **Skip** — Leave in queue for future review

## Step 5: Apply Decisions

### Promote to patterns.md
Append to `.specwright/memory/patterns.md`:
```markdown
## {Generated Title}

**Category**: {error/correction/discovery}
**Discovered**: {timestamp}

{Context description}

**Resolution**:
{Solution steps or pattern}
```

### Memorize to CLAUDE.md
Append one-liner to `CLAUDE.md` under `## Memories`:
```markdown
- **{Short Title}**: {Concise pattern description}
```
If `## Memories` section doesn't exist, create it.

### Dismiss to archive
Append to `.specwright/state/learning-dismissed.jsonl`:
```json
{"original_entry":{...},"dismissed_at":"{ISO}","reason":"user_dismissed"}
```

### Skip
Leave entry in queue unchanged.

## Step 6: Clean Queue

Rewrite `.specwright/state/learning-queue.jsonl` with only skipped entries.

Report summary:
```
Learning Review Complete:
- N promoted to patterns.md
- N memorized in CLAUDE.md
- N dismissed to archive
- N skipped (remain in queue)
- N malformed entries ignored
```

## File Locations

| File | Purpose |
|------|---------|
| `.specwright/state/learning-queue.jsonl` | Pending learnings (input) |
| `.specwright/memory/patterns.md` | Promoted patterns (project-level) |
| `CLAUDE.md` | Quick-reference memories |
| `.specwright/state/learning-dismissed.jsonl` | Archived dismissed learnings |

## Notes

- Contradictions require user awareness, not automatic blocking
- Promote complex patterns; memorize simple one-liners
- Malformed entries never block the review workflow
- Queue persists between sessions for incremental review
- NEVER auto-promote without human confirmation
