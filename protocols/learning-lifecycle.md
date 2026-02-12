# Learning Lifecycle Protocol

**Memory tiering.** Raw learning files accumulate over time. This protocol governs compaction into a three-tier structure: hot (INDEX.md), warm (theme files), cold (raw files).

## Tier Definitions

**Hot:** `.specwright/learnings/INDEX.md` — lookup table, max 20 lines content (excluding frontmatter).

**Warm:** `.specwright/learnings/themes/{theme-name}.md` — themed summaries, 300-token soft budget per file.

**Cold:** `.specwright/learnings/{work-id}.json` — raw files, never deleted.

## Compaction Triggers

Execute when **either** condition met:

1. 5+ raw `.json` files exist in `.specwright/learnings/`
2. 3+ new raw files since last compaction (current raw file count minus `rawFilesProcessed` in INDEX.md frontmatter)

Skip silently if neither condition met.

## INDEX.md Format

### Frontmatter
```yaml
---
lastCompaction: "2026-02-12T14:30:00Z"
rawFilesProcessed: 12
---
```

### Content (20-line budget)
One entry per theme:
```
**{theme-name}** — {one-line summary} → themes/{theme-name}.md
```

If INDEX.md exists: update in place. If absent: create.

## Theme File Format

Path: `.specwright/learnings/themes/{theme-name}.md`
Theme names: kebab-case, derived from content (e.g., `build-caching`, `api-error-handling`).

Structure:
```markdown
# {Theme Name}

{Summarized findings grouped by natural affinity, not fixed categories}

## Related Work Units
- {work-id-1}
- {work-id-2}
```

**Budget:** 300 tokens soft limit (approximate — word count / 0.75 as heuristic). If exceeded during compaction: split into subtopics or prune low-signal content.

## Compaction Process

**Goal:** Group raw findings by natural themes, summarize into theme files, update INDEX.md.

**Constraints:**
1. Read all raw `.json` files from `.specwright/learnings/`
2. Identify natural themes from findings (NOT predetermined categories)
3. For each theme:
   - Create or update theme file
   - Enforce 300-token budget
   - Track work-id in "Related Work Units"
4. Update INDEX.md frontmatter:
   - Set `lastCompaction` to current ISO 8601 timestamp
   - Set `rawFilesProcessed` to count of all raw files processed (cumulative)
5. Raw files remain in place (cold tier)

## Validation

**Per-file validation:**
- Required JSON fields: `workId`, `timestamp`, `findings`
- Invalid files: skip silently, continue processing others
- Non-JSON files: skip

**Theme merging:**
- If theme file exists: merge new findings, re-enforce budget
- If theme name collision: suffix with `-2`, `-3`, etc.

## Graceful Degradation

**Silent skip when:**
- Fewer than 5 raw files AND compaction not triggered by work-unit count
- All raw files fail validation
- `.specwright/learnings/` directory missing

**Never:**
- Error on missing data
- Prompt user to run compaction manually
