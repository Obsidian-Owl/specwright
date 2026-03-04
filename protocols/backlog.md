# Backlog Protocol

A unified tracking target for tech debt, debug findings, deferred assumptions,
audit items, and patterns not yet promoted. Skills write backlog items consistently
regardless of the user's chosen target.

## Configuration

Read from `config.json` before writing any backlog item:

```json
"backlog": {
  "type": "markdown",      // "markdown" or "github-issues"
  "label": "specwright-backlog"  // used only for github-issues
}
```

If `backlog` is absent from `config.json`, default to `markdown`.

## Write Targets

### markdown

Writes to `.specwright/BACKLOG.md`. Creates the file if it doesn't exist.

### github-issues

Creates a GitHub Issue via `gh` CLI:

```
gh issue create --title "{BL-n} {title}" --body "{detail}" --label "{backlog.label}"
```

**Fallback:** Before writing, check:
1. `gh` is on PATH (`which gh`)
2. Auth is active (`gh auth status`)

If either check fails: emit one warning ("GitHub Issues unavailable — writing to
BACKLOG.md instead"), then write to markdown. Never silently drop items.

## ID Generation

IDs are `BL-{n}` where `n` is a zero-padded three-digit integer (BL-001, BL-002, …).

**For markdown target:** Read `.specwright/BACKLOG.md`, find the highest existing
`BL-{n}` ID, increment by 1. If BACKLOG.md is missing or has no IDs, start at BL-001.

**For github-issues target:** List open issues with the backlog label (`gh issue list
--label "{backlog.label}" --json number --jq '.[].number'`), find highest BL-{n}
in issue titles, increment. If none, start at BL-001.

## BACKLOG.md Format

```markdown
# Specwright Backlog

## Open

### BL-001 [debug] Root cause: N+1 query in user listing
Added: 2026-03-04 | Source: sw-debug | Work: debug-n1-query
Fix: Add eager loading for user.roles relation

---

### BL-002 [defer] Parallel build support
Added: 2026-03-04 | Source: sw-design | Work: sw-effectiveness

---

## Resolved

### BL-003 [debt] gofmt not running in pre-commit hooks
Added: 2026-02-20 | Source: sw-audit | Work: ci-guardrails
Resolved: 2026-03-01 | Resolution: Added pre-commit hook in .claude/settings.json

---
```

## Tag Vocabulary

| Tag | When to use |
|-----|-------------|
| `debug` | Root causes identified by sw-debug but not fixed |
| `defer` | Assumptions or decisions deferred from sw-design |
| `debt` | Technical debt found during sw-audit or build |
| `finding` | Audit findings exported for action tracking |
| `pattern` | Learnings tracked for later promotion by sw-learn |

## Item Format

```
### BL-{n} [{tag}] {title}
Added: {YYYY-MM-DD} | Source: {skill-name} | Work: {work-id}
{optional one-line detail}
```

Fields:
- `{title}` — concise, actionable noun phrase (e.g., "Fix N+1 query in user listing")
- `{skill-name}` — the skill that created the item (e.g., `sw-debug`, `sw-design`)
- `{work-id}` — the active `currentWork.id` when the item was created

## Resolution

**Markdown:** Move the entry from `## Open` to `## Resolved`. Add:
```
Resolved: {YYYY-MM-DD} | Resolution: {one-line description}
```

**GitHub Issues:** Close the issue (`gh issue close {number} --comment "{resolution}"`).
