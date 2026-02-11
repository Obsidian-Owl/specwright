# Insights Protocol

**System boundary crossing.** Claude Code writes session insights to `~/.claude/usage-data/`. This protocol governs reading that data for sw-learn enrichment.

## Data Location

```
~/.claude/usage-data/
  facets/{session-id}.json
  session-meta/{session-id}.json
```

## Required Schemas

### Facet Files
Required fields:
- `session_id` (string)
- `friction_counts` (object: string keys, numeric values)
- `friction_detail` (string)

Privacy-sensitive fields (NEVER surface):
- `brief_summary`
- `underlying_goal`

### Session-Meta Files
Required fields:
- `session_id` (string)
- `project_path` (string, absolute path)
- `start_time` (ISO 8601 string)

## Validation

**Per-file validation:**
- Required fields must exist and match type
- Invalid files: skip silently, continue processing others
- Non-JSON files: skip

**Cross-file validation:**
- Facets without matching session-meta: skip

## Project Filtering

1. Join facets to session-meta by `session_id`
2. Filter where `project_path` matches current project (exact string match)
3. Only normalize trailing slashes before comparison (no case, symlink, or other normalization)
4. No partial matching — `/myapp-v2` does NOT match `/myapp`

## Aggregation

**Friction counts:**
- Sum `friction_counts` across matching sessions by category
- Surface top 3 categories by total count

**Detail text:**
- Include `friction_detail` from the most recent session (by `start_time`)

## Staleness

**Threshold:** 14 days from newest matching facet's `start_time`

If stale:
- Show info note: "Session pattern data is older than 14 days. Run /insights to refresh."
- Skip enrichment

## Graceful Degradation

**Silent skip when:**
- Facets directory missing or empty
- No matching project sessions
- All files fail validation

**Never:**
- Prompt user to run `/insights` (except staleness note)
- Error on missing data

## Presentation

**Source tag:**
```json
{ "source": "insights" }
```

**Section label:**
"Session Patterns"

**Visually separate** from other sw-learn findings.

## Privacy

**Only surface:**
- Aggregated `friction_counts`
- `friction_detail` text

**Never surface:**
- `brief_summary`
- `underlying_goal`
- Individual session identifiers
