# Context Loading Protocol

## Standard Context Documents

### Anchor Documents
Load when needed for alignment/verification:

- `.specwright/CONSTITUTION.md` — Development practices and principles
- `.specwright/CHARTER.md` — Technology vision and project purpose

### Configuration
- `.specwright/config.json` — Project settings, commands, gates, git, integration
  - `backlog.type` / `backlog.label` — backlog target (optional; read before writing backlog items per `protocols/backlog.md`)

### State
- `.specwright/state/workflow.json` — Current progress, gate results, lock status

### Reference Documents
Load on demand when codebase structure knowledge is needed:

- `.specwright/LANDSCAPE.md` — Codebase architecture and module knowledge (optional)
- `.specwright/AUDIT.md` — Codebase health findings and tech debt tracking (optional)
- `.specwright/research/*.md` — External research briefs (loaded by sw-design only; warn if stale per `protocols/research.md`)

## Initialization Checks

**Before any operation:**

```javascript
if (!exists('.specwright/config.json')) {
  error("Run /sw-init first.");
}
if (config.version !== "2.0") {
  warn("Config version mismatch: expected 2.0, found " + config.version);
}
```

**Before work-unit operations:**

```javascript
if (!state.currentWorkUnit && requiresWorkUnit) {
  error("Run /sw-design first.");
}
```

## Loading Strategy

**Always load:**
- config.json (for all operations)
- workflow.json (for state-aware operations)

**Load on demand:**
- CONSTITUTION.md (when verifying practices)
- CHARTER.md (when verifying vision alignment)
- Work unit artifacts (when operating on specific epic/task)

## Error Handling

If required context missing:
1. Stop immediately
2. Provide clear error message
3. Indicate which command should be run first
