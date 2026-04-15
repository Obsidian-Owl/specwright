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

- `{repoStateRoot}/config.json` -- detected + configured project settings
- `{repoStateRoot}/CONSTITUTION.md` -- development practices the AI must follow
- `{repoStateRoot}/CHARTER.md` -- technology vision and project identity
- `{repoStateRoot}/work/` -- shared work root, initialized and empty
- `{worktreeStateRoot}/session.json` -- initialized detached top-level session for
  the current worktree

Optional (created if the user opts in):
- `{repoStateRoot}/TESTING.md` -- testing strategy: boundaries,
  infrastructure, mock allowances
- Hooks set up if the user wants them

Quality gates are configured in config (all six default to enabled; user may disable).

## Constraints

**Worktree context (LOW freedom):**
- Check `worktreeContext` per `protocols/context.md`.
- If `linked`, explain that shared Specwright state lives under `{repoStateRoot}` and that a linked worktree can bootstrap its local session root against shared repo state.
- If the shared layout already exists, reuse it and create or repair only this
  worktree's `{worktreeStateRoot}/session.json`.
- If the shared layout does not exist yet, say that `/sw-init` will create the
  repo-level state under the Git common dir plus a session root for the current
  worktree. This is a warning, not a block.

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

**Testing strategy creation (HIGH freedom):**
- After constitution and charter are approved, generate `.specwright/TESTING.md`.
- Follow `protocols/testing-strategy.md` for document structure and boundary classifications.
- Ask the user about testing boundaries using AskUserQuestion:
  - "What external services does this project call?" (payment APIs, email, auth providers, etc.)
  - "What's your test database strategy?" (in-memory, testcontainers, shared test DB, none)
  - "Are there any rate-limited or cost-attached APIs?" (metered APIs, slow services)
  - "Any other expensive or unreliable dependencies?"
- Batch these into 1-2 questions based on what stack detection reveals.
  Don't ask about services the codebase doesn't use.
- Generate TESTING.md with required sections:
  - **Boundaries**: Classify each detected dependency as `internal` (test with real
    components), `external` (mock with contracts), or `expensive` (mock with rationale)
  - **Test Infrastructure**: What test database, fixtures, containers, or test servers
    are available based on detected stack and user answers
  - **Mock Allowances**: Which dependencies may be mocked, with explicit rationale
  - **Test Commands** (added after gate configuration): If tiered commands were captured
    during gate config, append this section to TESTING.md with the actual commands.
    See `protocols/testing-strategy.md` Test Commands section. Omit if no tiers configured.
- The user must approve TESTING.md before it's saved.
- If the user declines or skips: do not create TESTING.md. Constitution testing rules
  remain the sole authority. TESTING.md is recommended but not required.

**Git workflow configuration (MEDIUM freedom):**
- Detect workflow by scanning branch names, remotes, CI files. Present detected strategy with confidence.
- Confirm via AskUserQuestion: strategy (trunk-based/github-flow/gitflow/custom), target-role defaults and freshness checkpoints, branch prefix, merge strategy, PR required, commit format.
- Ask whether optional auditable work artifacts stay clone-local or are published under a tracked work-artifact root. Project-level anchor docs remain project artifacts and runtime session state stays local-only.
- Store `git.targets` and `git.freshness` in `config.json`, seeding branch-role defaults and freshness checkpoints from the detected workflow strategy while preserving `baseBranch` as a compatibility alias and without requiring users to define a custom branch DSL.
- Store the resulting settings in the `config.json` `git` section per `protocols/git.md`. Record any optional work-artifact publication choice in config instead of inferring it from `.git/` paths or symlinks.
- If old git schema detected: offer migration with sensible defaults.

**Configuration (LOW freedom):**
- Write `{repoStateRoot}/config.json` with detected and configured values.
- Create `{repoStateRoot}/work/`, `{repoStateRoot}/research/`, and
  `{repoStateRoot}/learnings/`. If survey produced LANDSCAPE.md, write it
  under `{repoStateRoot}`.
- Create `{worktreeStateRoot}/session.json` as a detached top-level session for
  the current worktree. Initialize `attachedWorkId: null`, current branch when
  available, `mode: "top-level"`, and fresh `lastSeenAt`.
- If a legacy checkout-local `.specwright/` install exists, treat it as
  migration input only: import the shared docs/config the user keeps, then
  write all repaired state to `{repoStateRoot}` and `{worktreeStateRoot}` only.
- Follow `protocols/state.md` for state file format.

**Gate configuration (MEDIUM freedom):**
- All six gates default to enabled: build, tests, security, wiring, semantic, spec.
  Semantic is WARN-only with graceful degradation (no tools required). The user may
  disable any gate. Write gates as object format in config.json:
  `{ "gates": { "build": { "enabled": true }, ... } }`.
  Configure thresholds per user expectations.
- If a test runner is detected, batch these additional questions:
  - "Do you have integration tests against real infrastructure? What command runs them?"
    → Populate `commands.test:integration` in config.json. Skip if user answers none.
  - "Do you have smoke or E2E tests? What command?"
    → Populate `commands.test:smoke`. Skip if user answers none.
  Empty or declined answers are not written to config (tiers are optional).

**Backlog configuration (MEDIUM freedom):**
- Batch with gate configuration question (both are quality infrastructure).
- Ask: "Where should Specwright track tech debt, deferred work, debug findings, and audit items?"
  - `markdown` — writes to `.specwright/BACKLOG.md` (default, always available)
  - `github-issues` — creates GitHub Issues via `gh` CLI (requires `gh auth login`)
- If `github-issues` selected: ask for label name (default: `specwright-backlog`).
- Store as `backlog.type` and `backlog.label` in `config.json`.
- If user skips or is unsure: default to `markdown`. Backlog config is always optional.

**Experimental features (LOW freedom):**
- If user indicates interest in experimental features: add `experimental` section to config.json.
- Schema: `{ "experimental": { "agentTeams": { "enabled": false, "maxTeammates": 3, "requirePlanApproval": true } } }`
- All experimental features default to disabled. Don't prompt unless the user asks.

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
