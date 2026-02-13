# Git Operations Protocol

All git behavior is driven by `config.json` `git` section. Nothing is hardcoded.

## Config Schema

```json
{
  "git": {
    "strategy": "trunk-based",
    "baseBranch": "main",
    "branchPrefix": "feat/",
    "mergeStrategy": "squash",
    "prRequired": true,
    "commitFormat": "conventional",
    "commitTemplate": null,
    "branchPerWorkUnit": true,
    "cleanupBranch": true,
    "prTool": "gh"
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `strategy` | enum | `trunk-based` | `trunk-based`, `github-flow`, `gitflow`, `custom` |
| `baseBranch` | string | `main` | Primary integration branch |
| `branchPrefix` | string | `feat/` | Prefix for feature branches |
| `mergeStrategy` | enum | `squash` | `squash`, `rebase`, `merge` |
| `prRequired` | boolean | `true` | Whether PRs are required for shipping |
| `commitFormat` | enum | `conventional` | `conventional`, `freeform`, `custom` |
| `commitTemplate` | string | `null` | Template for `custom` format. Placeholders: `{type}`, `{scope}`, `{description}` |
| `branchPerWorkUnit` | boolean | `true` | Create a branch per work unit |
| `cleanupBranch` | boolean | `true` | Delete branch after merge |
| `prTool` | string | `gh` | CLI tool for PR creation |

Missing fields fall back to defaults. Old config schemas (e.g., `defaultBranch` instead of `baseBranch`, `conventionalCommits` instead of `commitFormat`) are detected and migrated by sw-init.

## Branch Lifecycle

**Create** (at build start):
```bash
git checkout config.git.baseBranch
git fetch origin
git pull origin config.git.baseBranch
git checkout -b {config.git.branchPrefix}{work-unit-id}
```
If branch already exists (recovery): `git checkout {branch}`.

**Sync check** (at build start, after branch setup):
Compare local baseBranch with origin/baseBranch. If behind, warn the user
with the commit count. Advisory only — let the user decide whether to
rebase. If branch already exists (recovery): also check for upstream drift.

**Work**: All task commits happen on the feature branch. Never on baseBranch.

**Push** (at ship):
```bash
git push -u origin {branch}
```

**Cleanup** (after merge, if `config.git.cleanupBranch`):
- Delete local feature branch: `git branch -d {branch}`
- Delete remote branch if it still exists: `git push origin --delete {branch}`
- Prune stale remote refs: `git fetch --prune`
- Sync base branch: `git checkout {baseBranch} && git pull origin {baseBranch}`

## Strategy: Branch + PR Targets

Read `config.git.strategy`:

| Strategy | Branch from | PR targets | Merge style |
|----------|------------|------------|-------------|
| `trunk-based` | baseBranch | baseBranch | squash (default) |
| `github-flow` | baseBranch | baseBranch | merge or squash |
| `gitflow` | `develop` | `develop` (feature), `main` (release) | merge |
| `custom` | ask user | ask user | ask user |

For `custom` strategy: prompt the user with AskUserQuestion for each git operation that would normally be derived from config. This is the escape hatch.

## Staging Rules

**ALWAYS stage specific files by path:**
```bash
git add src/foo.ts protocols/git.md
```

**NEVER use:** `git add -A`, `git add .`, `git add --all`

## Commit Format

Read `config.git.commitFormat`:

**conventional** (default):
```
{type}({scope}): {description}
```
Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`.
Scope: detect from changed file paths (e.g., `protocols`, `skills`, `gate-*`).

**freeform**: No enforced structure. Descriptive message referencing work unit.

**custom**: Use `config.git.commitTemplate` as the pattern. Substitute `{type}`, `{scope}`, `{description}` placeholders.

**Scope detection:**
```bash
git diff --name-only config.git.baseBranch...HEAD 2>/dev/null || git diff --name-only HEAD~10
```

**Always use HEREDOC for commits:**
```bash
git commit -m "$(cat <<'EOF'
feat(auth): implement OAuth flow

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

The `Co-Authored-By` trailer is always included.

## PR Creation

Read `config.git.prTool` (default: `gh`).
If `config.git.prRequired` is false: ask user preference.

```bash
gh pr create --title "{title}" --base {target} --body "$(cat <<'EOF'
{body}
EOF
)"
```

PR title follows the configured commit format style.
