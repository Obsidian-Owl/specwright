# Git Operations Protocol

All git behavior is driven by `config.json` `git` section. Nothing is hardcoded.

## Branch Lifecycle

**Create** (at build start):
```bash
git checkout config.git.baseBranch
git pull origin config.git.baseBranch
git checkout -b {config.git.branchPrefix}{work-unit-id}
```
If branch already exists (recovery): `git checkout {branch}`.

**Work**: All task commits happen on the feature branch. Never on baseBranch.

**Push** (at ship):
```bash
git push -u origin {branch}
```

**Cleanup** (after merge, if `config.git.cleanupBranch`):
```bash
git checkout config.git.baseBranch && git branch -d {branch}
```

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
