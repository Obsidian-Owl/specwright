---
name: ship
description: >-
  Evidence-based PR creation. Verifies all gates passed, commits remaining
  changes, and creates PR with evidence mapping.
argument-hint: "[epic-id]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Specwright Ship: Evidence-Based PR Creation

Creates a pull request with full evidence mapping and spec compliance verification.

## Step 1: Read Configuration and State

Read `.specwright/config.json` for:
- `git.prTool` — PR creation tool (gh, glab, none)
- `git.commitFormat` — commit message format
- `integration.omc` — OMC agent availability

Read `.specwright/state/workflow.json` for current epic context and gate status.
If no active epic, STOP: "No active epic. Run /specwright:specify first."

## Step 2: Verify All Gates Passed

Check each gate in the `gates` object of workflow.json.
Only check gates that are enabled in `config.json` `gates.enabled` (plus "spec" which is always enabled).

For each enabled gate:
- If status is not "PASS" and not "WARN": add to failed gates list

If any gates failed:
```
Cannot ship: The following gates have not passed:
{list failed gates}

Run /specwright:validate to check all gates.
```
STOP.

## Step 3: Check for Uncommitted Changes

Run `git status --porcelain` to detect changes.

If changes exist:
1. List modified files
2. Stage specific files (NEVER `git add -A`)
3. Commit with format from config:
   ```
   feat({epic-id}): final changes

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

## Step 4: Push Branch

```bash
git push -u origin {branch-name}
```
Get branch name from workflow.json or current git branch.

## Step 5: Generate PR Body

Read the PR template from `.specwright/templates/pr-template.md`.

Populate the template with:
1. **Summary**: Read spec.md for epic description
2. **Changes**: Run `git diff main...HEAD --name-only` and group by directory
3. **Evidence**: Map each enabled gate to its evidence file from workflow.json
4. **Acceptance Criteria**: Read `{specDir}/evidence/spec-compliance.md` for the criteria mapping
5. **Complexity**: Read tasks.md for total complexity score

## Step 6: Create Pull Request

Based on `config.json` `git.prTool`:

**If "gh" (GitHub CLI):**
```bash
gh pr create --title "feat: {epic-name}" --body "{pr-body}" --base main --head {branch}
```

**If "glab" (GitLab CLI):**
```bash
glab mr create --title "feat: {epic-name}" --description "{pr-body}" --target-branch main --source-branch {branch}
```

**If "none":**
- Output the PR body for manual creation
- Skip automated PR creation

Capture PR/MR URL from output.

## Step 7: Update Workflow State

Update `.specwright/state/workflow.json`:
```json
{
  "currentEpic": {
    "...existing",
    "status": "shipped",
    "prUrl": "{pr-url}",
    "shippedAt": "{ISO-timestamp}"
  }
}
```

## Step 8: Summary

```
Epic {epic-name} shipped successfully!

Pull Request: {pr-url}
Branch: {branch-name}
Quality Gates: All PASS

Next steps:
1. Request review from team members
2. Address any feedback
3. Merge when approved

Evidence preserved in {specDir}/evidence/
```

## Compaction Recovery

If compaction occurs:
1. Read workflow.json — if status is "shipped" with prUrl, output summary and stop
2. If status is "tasks-complete" with all gates PASS, resume at Step 3

## Error Handling

| Error | Action |
|-------|--------|
| No workflow state | "No active epic. Run /specwright:specify first." |
| Gates not all PASS | List failed gates, suggest /specwright:validate |
| Git push fails | Show error, suggest checking remote access |
| PR creation fails | Show error, check if PR already exists |
