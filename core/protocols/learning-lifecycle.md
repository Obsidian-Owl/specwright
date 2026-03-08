# Learning Lifecycle Protocol

**Promotion targets.** Learnings captured by sw-learn are promoted to surfaces with different durability and visibility. This protocol governs what goes where.

## Promotion Targets

Three targets, ordered by durability:

| Target | When to use | Loaded |
|--------|------------|--------|
| **Constitution** | Hard rules: "always do X", "never do Y" | Every session (via CLAUDE.md reference) |
| **Auto-memory** | Project-specific patterns, common gotchas | Every session (first 200 lines of MEMORY.md) |
| **patterns.md** | Detailed patterns with source and rationale | On demand (sw-design, sw-plan read it) |

**Constitution** (`.specwright/CONSTITUTION.md`): Most durable. Add a practice with an ID (e.g., S6, Q5). User approves exact wording. Referenced by CLAUDE.md, loaded by skills, validated by gates.

**Auto-memory** (MEMORY.md in Claude Code's auto-memory directory): Loaded automatically every session. Write compact entries under a `## Specwright Patterns` section. Fire-and-forget — patterns.md is the canonical record.

**patterns.md** (`.specwright/patterns.md`): Full pattern library. Detailed descriptions with source and rationale. Create if missing on first promotion. Grouped by theme, not fixed categories.

## Dual-Write Rule

When promoting to patterns.md, also write a compact one-liner to auto-memory. This ensures the pattern is visible in every session without requiring an explicit file read. Auto-memory acts as an index for the full patterns.md library.

## Auto-Memory Format

**Section header:** `## Specwright Patterns`

**Entry format:** `- **P{n}: {title}** — {one-line summary}`

**Section management:**
1. Before appending, check if `## Specwright Patterns` section exists in MEMORY.md
2. If missing (Claude may have reorganized during auto-memory maintenance): recreate the section
3. Append the new entry to the section

**Line count check:** Before adding, check MEMORY.md total line count. First 200 lines are loaded at session start; entries beyond that are invisible. If approaching the limit, skip the auto-memory write (patterns.md is the canonical record).

## Raw File Retention

`.specwright/learnings/{work-id}.json` — raw learning files. Archive only, never deleted. Schema: `{ workId, timestamp, findings: [{ category, source, description, proposedRule, disposition }] }`. Only written when at least one finding is promoted (not all dismissed).

## Graceful Degradation

**Auto-memory unavailable:** If the auto-memory directory doesn't exist or the system prompt doesn't mention auto-memory, silently fall back to patterns.md only. Never error on missing auto-memory. Never prompt the user about it.

**learnings/ directory missing:** Create on first write.

**Raw file validation:** Required JSON fields: `workId`, `timestamp`, `findings`. Invalid files: skip silently. Non-JSON files: skip.
