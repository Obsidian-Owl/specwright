# Context Loading Protocol

## Standard Context Documents

### Anchor Documents
Load when needed for alignment/verification:

- `.specwright/CONSTITUTION.md` — Development practices and principles
- `.specwright/CHARTER.md` — Technology vision and project purpose
- `.specwright/TESTING.md` — Testing strategy: boundaries, mock allowances, test infrastructure (optional — if absent, Constitution testing rules are the sole authority. See `protocols/testing-strategy.md` for precedence: Constitution > TESTING.md > patterns.md)

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

## Worktree Detection

Detect whether the current working directory is a linked git worktree before
accessing any `.specwright/` state files. This detection runs on every skill
invocation (recomputed, not cached).

**Detection logic:**

1. Check if `.git` is a file (not a directory).
2. If `.git` is a file, read its content and check the `gitdir:` path:
   - Path contains `/worktrees/` → `worktreeContext = linked` (linked worktree)
   - Path contains `/modules/` → `worktreeContext = primary` (git submodule)
   - Any other content → `worktreeContext = primary` (unknown, conservative)
3. If `.git` is a directory → `worktreeContext = primary` (main worktree)
4. If `.git` is unreadable (permissions) → `worktreeContext = primary` (conservative)
5. If `.git` does not exist → `worktreeContext = primary` (not a git repo; git ops will fail separately)

**Values:**
- `primary` — main worktree, submodule, or unreadable `.git`. Normal behavior.
- `linked` — linked git worktree (Claude Code Desktop, `--worktree` flag, user-created).

Skills reference `worktreeContext` in their pre-condition checks alongside config
and state loading. Detection runs before state file access.

## Linked Worktree Degradation

When `worktreeContext` is `linked` AND `.specwright/config.json` does not exist
(`.specwright/` is gitignored and absent in linked worktrees), skills behave
according to their tier.

When `worktreeContext` is `primary`, no degradation applies — all skills behave
normally regardless of this section.

**Tier A — State-mutating skills (STOP with guidance):**

Cannot function without `.specwright/` state. STOP message:
> Running in a linked git worktree — Specwright state files are not present
> (`.specwright/` is gitignored). To use this skill, switch to the main worktree
> or run `/sw-init` here to create local state.

| Skill | Rationale |
|-------|-----------|
| sw-design | Creates currentWork, writes design artifacts |
| sw-plan | Writes specs, plans, transitions state |
| sw-build | Commits, updates tasksCompleted, transitions state |
| sw-ship | Creates PR, sets shipped status |
| sw-pivot | Modifies plan.md, revises tasks |
| sw-learn | Writes patterns.md, clears currentWork |
| sw-verify | Sets status to verifying, writes gate results and evidence files |

**Tier B — Read-only skills (WARN and continue):**

Can function without `.specwright/` state. These skills either operate on external
data (GitHub, codebase) or produce advisory output. The Initialization Checks
`config.json` gate is suppressed for Tier B skills when `worktreeContext` is `linked`
— the WARN message replaces the init error.

WARN message:
> Running in a linked git worktree — state files may not be present. Results
> may be incomplete.

| Skill | Rationale |
|-------|-----------|
| sw-review | Fetches PR comments from GitHub — no state needed |
| sw-status | Reports state — warns if state missing |
| sw-doctor | Read-only health check |
| sw-debug | Investigation-first — reads codebase |
| sw-research | Outward research — no state mutation |
| sw-audit | Read-only codebase analysis |

**Tier C — Stateless utilities (no change):**

Never touch `.specwright/state/`. No worktree behavior change needed.

| Skill | Rationale |
|-------|-----------|
| sw-sync | Reads config and workflow.json (active branch); never writes state |
| sw-guard | Configures external guardrails, no state |
| sw-init | Creates `.specwright/` — special case* |
| gate-build | Internal gate invoked by verify |
| gate-tests | Internal gate invoked by verify |
| gate-security | Internal gate invoked by verify |
| gate-wiring | Internal gate invoked by verify |
| gate-semantic | Internal gate invoked by verify |
| gate-spec | Internal gate invoked by verify |

*sw-init special case: warns when invoked in a linked worktree (see
`skills/sw-init/SKILL.md`) but allows the user to proceed. Creating
`.specwright/` locally in a linked worktree is a valid use case.

Gate skills are invoked by sw-verify (Tier A). In a linked worktree without state,
sw-verify STOPs before invoking any gates.

## Initialization Checks

**Before any operation:**

```javascript
// Tier B skills in linked worktrees skip this check (WARN was already emitted)
if (worktreeContext === 'linked' && skillTier === 'B') {
  // config.json absence is expected — degradation WARN already shown
} else if (!exists('.specwright/config.json')) {
  error("Run /sw-init first.");
}
if (!config.version) {
  warn("Config missing version field — re-run /sw-init to upgrade to 2.0.");
} else if (config.version !== "2.0") {
  warn("Config version mismatch: expected 2.0, found " + config.version);
}
```

**Before work-unit operations:**

```javascript
if (!state.currentWork && requiresWorkUnit) {
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
- TESTING.md (when writing or auditing tests — if it exists)
- Work unit artifacts (when operating on specific epic/task)

## Error Handling

If required context missing:
1. Stop immediately
2. Provide clear error message
3. Indicate which command should be run first
