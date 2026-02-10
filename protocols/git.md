# Git Operations Protocol

## Trunk-Based Development

**Branch creation:**
```bash
git checkout -b {prefix}{id}
```
Use `config.json` `git.branchPrefix` (default: "feat/").

**Main branch:**
Read from `config.json` `git.mainBranch` (default: "main").

## Staging Rules

**ALWAYS stage specific files by path:**
```bash
git add src/foo.ts src/bar.ts
```

**NEVER use:**
- `git add -A`
- `git add .`
- `git add --all`

## Commit Format

Read `config.json` `git.commitFormat`:

**conventional format:**
```
{type}({scope}): {description}

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Use HEREDOC for multi-line messages:**
```bash
git commit -m "$(cat <<'EOF'
feat(auth): implement OAuth flow

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

## Diff for Scope Detection

```bash
git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~10
```

## Ship (Trunk-Based)

1. Squash commits on feature branch (if configured)
2. Merge to main branch
3. Delete feature branch after merge

**Push:**
```bash
git push -u origin {branch}
```
