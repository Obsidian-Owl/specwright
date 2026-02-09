---
name: constitution
description: >-
  View and edit project development principles. Add, modify, or remove
  principles from the constitution with interactive approval.
argument-hint: "[add|edit|remove|view]"
---

# Specwright Constitution: Principles Editor

Interactive editor for the project's development constitution — the non-negotiable principles that guide all development.

## Arguments

Parse `$ARGUMENTS`:
- **Empty or "view"**: Display current constitution
- **"add"**: Add a new principle
- **"edit"**: Edit an existing principle
- **"remove"**: Remove a principle

## Step 1: Load Constitution

Read `.specwright/memory/constitution.md`.
If file doesn't exist: STOP with "No constitution found. Run /specwright:init first."

Parse principles:
- Extract each `## Principle` section
- Count total principles
- Extract statement, testable criteria, and anti-patterns for each

## Step 2: Execute Command

### View Mode (default)
Display all principles in a summary table:

```
=== Project Constitution ===

Principle I: {statement summary}
  Criteria: {count} testable items
  Anti-patterns: {count}

Principle II: {statement summary}
  ...

Total: {N} principles
Last modified: {date}
```

### Add Mode
Guide user through adding a new principle using AskUserQuestion:

**Question 1:** "What is the principle statement? (e.g., 'All public APIs must have integration tests')"
- Free text via "Other" option
- Provide example options: ["Tests prove behavior", "Security by default", "Documentation required"]

**Question 2:** "What are the testable criteria? (How do we verify compliance?)"
- Free text

**Question 3:** "What are the anti-patterns to avoid?"
- Free text

Format the new principle:
```markdown
## Principle {N+1}: {Statement}

**Statement:** {Full statement}

**Testable Criteria:**
- [ ] {Criterion 1}
- [ ] {Criterion 2}

**Anti-Patterns:**
- {Anti-pattern 1}
- {Anti-pattern 2}
```

Show the formatted principle and ask for confirmation:
- "Add this principle to the constitution?"
- Options: "Yes, add it", "Edit before adding", "Cancel"

If confirmed: append to constitution.md

### Edit Mode
Show numbered list of principles. Ask which to edit using AskUserQuestion.

Read the selected principle. Present current content.

Ask what to change:
- Options: "Statement", "Testable criteria", "Anti-patterns", "All of the above"

Collect edits and show diff before applying:
```
BEFORE: {old text}
AFTER: {new text}
```

Confirm with user before writing.

### Remove Mode
Show numbered list of principles. Ask which to remove.

**Safety check**: Require confirmation:
- "Are you sure you want to remove Principle {N}: '{statement}'?"
- Options: "Yes, remove it", "Cancel"

If confirmed: remove the principle section from constitution.md.
Renumber remaining principles.

## Step 3: Update Amendment History

After any add/edit/remove, append to the Amendment History table at the bottom of constitution.md:

```markdown
| {version} | {date} | {Added/Edited/Removed} Principle {N}: {summary} | User requested |
```

Increment version number (patch for edits, minor for adds/removes).

## Step 4: Summary

Output what changed:
```
Constitution updated:
- {Action}: Principle {N} — "{statement}"
- Version: {old} -> {new}
- Total principles: {count}
```
