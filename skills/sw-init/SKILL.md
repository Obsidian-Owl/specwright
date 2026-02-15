---
name: sw-init
description: >-
  Initializes Specwright in a project. Detects stack, asks about practices,
  creates constitution and charter, configures quality gates and hooks.
argument-hint: ""
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
  - AskUserQuestion
---

# Specwright Init

## Goal

Set up Specwright in this project by understanding how the user works,
what they're building, and what quality standards they expect. Produce
configuration and anchor documents that will guide all future work.

## Inputs

- The codebase (scan for language, framework, dependencies, test runner)
- The user (ask about practices, vision, quality expectations)

## Outputs

When complete, ALL of the following exist:

- `.specwright/config.json` -- detected + configured project settings
- `.specwright/CONSTITUTION.md` -- development practices the AI must follow
- `.specwright/CHARTER.md` -- technology vision and project identity
- `.specwright/state/workflow.json` -- initialized empty state
- Quality gates configured in config based on user preferences
- Hooks set up if the user wants them

## Constraints

**Detection (MEDIUM freedom):**
- Scan codebase: language(s), framework(s), package manager, test runner, linting/formatting, git workflow, CI/CD. Read dependency manifests. Don't guess what you can detect.

**Survey (MEDIUM freedom):**
- After detection, survey the codebase using Glob/Grep/Read: directory structure, entry points, module dependencies, conventions, integration points, gotchas.
- Produce `.specwright/LANDSCAPE.md` per `protocols/landscape.md` format. User approves before saving.
- Optional — if user declines, skip. LANDSCAPE.md is never required.

**User conversation (HIGH freedom):**
- Ask the user about things you CANNOT detect from the codebase:
  - What is this project? Who uses it? (→ CHARTER.md)
  - Testing philosophy and coverage expectations? (→ CONSTITUTION.md)
  - Security requirements? (→ gate config)
  - Code review standards? (→ CONSTITUTION.md)
  - Any practices or patterns they insist on? (→ CONSTITUTION.md)
- Use AskUserQuestion with concrete options based on what you detected.
- Batch related questions. Maximum 3-4 questions per interaction.
- Don't ask about things the codebase already answers.

**Constitution creation (HIGH freedom):**
- The constitution captures the user's development practices as clear rules.
- Rules should be specific and actionable, not vague aspirations.
- Bad: "Write clean code." Good: "All public functions must have error handling."
- The user must approve the constitution before it's saved.

**Charter creation (HIGH freedom):**
- The charter captures the project's identity and vision.
- What is this project? What problem does it solve? Who are the consumers?
- What are the architectural invariants (things that won't change)?
- What technologies are foundational (not up for debate)?
- Keep it concise -- one page, not a business plan.
- The user must approve the charter before it's saved.

**Git workflow configuration (MEDIUM freedom):**
- Detect workflow by scanning branch names, remotes, CI files. Present detected strategy with confidence.
- Confirm via AskUserQuestion: strategy (trunk-based/github-flow/gitflow/custom), branch prefix, merge strategy, PR required, commit format.
- Store in `config.json` `git` section per `protocols/git.md`.
- If old git schema detected: offer migration with sensible defaults.

**Configuration (LOW freedom):**
- Write `.specwright/config.json` with detected and configured values.
- Create `.specwright/state/workflow.json` with empty initial state.
- Create directory structure: `.specwright/state/`, `.specwright/work/`, `.specwright/baselines/`, `.specwright/learnings/`. If survey produced LANDSCAPE.md, include it (optional).
- Follow `protocols/state.md` for state file format.

**Gate configuration (MEDIUM freedom):**
- Ask user which quality checks matter. Defaults: build, security, spec-compliance.
- Enable test/lint gates if detected. Configure thresholds per user expectations.

## Protocol References

- `protocols/state.md` -- workflow.json initialization
- `protocols/context.md` -- config.json format
- `protocols/git.md` -- git config field reference and strategy definitions
- `protocols/landscape.md` -- codebase reference document format

## Failure Modes

| Condition | Action |
|-----------|--------|
| .specwright/ already exists | Ask user: reconfigure, or abort |
| No dependency manifest found | Ask user about language and framework directly |
| User unsure about practices | Suggest sensible defaults based on detected stack, let them adjust |
| Old config.json git schema detected | Show diff of old vs new fields. Offer migration with AskUserQuestion. Preserve existing values, add new fields with defaults. |
| Compaction during init | Check which files exist, resume from next missing artifact |
