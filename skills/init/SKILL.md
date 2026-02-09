---
name: init
description: >-
  Initialize Specwright in your project. Interactive wizard that configures
  spec-driven development with quality gates, learning, and compaction recovery.
argument-hint: "[--reset]"
---

# Specwright Init: Project Initialization Wizard

Sets up spec-driven development in your project with an interactive configuration wizard.

## Arguments

Parse `$ARGUMENTS` for:
- **Empty**: Initialize new project or detect existing
- `--reset`: Reset configuration (preserves epics and learnings)

## Pre-flight Checks

### Check for Existing Installation
1. Check if `.specwright/config.json` exists
2. If exists AND no `--reset` flag:
   - Read existing config
   - Show current configuration summary
   - Ask user via AskUserQuestion: "Specwright is already initialized. What would you like to do?"
     - Options: "Keep current config", "Reconfigure (preserve data)", "Full reset (preserve epics)"
   - If "Keep current config": exit with summary
   - If "Reconfigure": proceed with wizard, preserve `.specwright/state/`, `.specwright/epics/`, `.specwright/memory/`
   - If "Full reset": delete config.json only, proceed with wizard

### Check for OMC
Detect oh-my-claudecode installation:
1. Check if the `oh-my-claudecode:help` skill is available (try invoking it mentally)
2. Check if `~/.claude/plugins/installed_plugins.json` contains `oh-my-claudecode`
3. Set `omcDetected = true/false` for later config

## Interactive Configuration Wizard

Use `AskUserQuestion` for each configuration section. Group related questions where possible (AskUserQuestion supports up to 4 questions per call).

### Round 1: Project Identity

Use AskUserQuestion with these questions:

**Question 1:** "What is your project name?"
- header: "Project"
- options: [auto-detect from package.json/go.mod/Cargo.toml name, "Enter custom name"]

**Question 2:** "What is your project structure?"
- header: "Structure"
- options: ["Single app", "Multi-service/microservices", "Monorepo"]

### Round 2: Language & Framework

**Question 1:** "What are your primary programming languages?"
- header: "Languages"
- multiSelect: true
- options: ["TypeScript/JavaScript", "Python", "Go", "Rust"]
- (User can select "Other" for additional languages)

**Question 2:** "What is your primary framework?" (adapt options based on language selection)
- header: "Framework"
- options: Dynamic based on language — e.g., for TS: ["Next.js", "Express", "Fastify", "None"]; for Python: ["FastAPI", "Django", "Flask", "None"]; for Go: ["Echo", "Gin", "Standard library", "None"]; for Rust: ["Axum", "Actix", "None"]
- Note: Since AskUserQuestion options are static, provide the most common frameworks and let user pick "Other"
- options: ["Next.js", "FastAPI", "Express/Fastify", "None/Other"]

### Round 3: Build & Test Commands

**Question 1:** "What is your build command?"
- header: "Build"
- options: Detect from project files:
  - package.json → "npm run build" or "pnpm build"
  - go.mod → "go build ./..."
  - Cargo.toml → "cargo build"
  - pyproject.toml → "python -m build"
  - Fallback: "Enter custom command"

**Question 2:** "What is your test command?"
- header: "Tests"
- options: Similar detection logic:
  - package.json → "npm test" or "pnpm test"
  - go.mod → "go test ./..."
  - Cargo.toml → "cargo test"
  - pytest.ini/pyproject.toml → "pytest"
  - Fallback: "Enter custom command"

**Question 3:** "What is your lint command? (optional)"
- header: "Lint"
- options: ["eslint .", "golangci-lint run", "ruff check .", "None"]

### Round 4: Architecture

**Question 1:** "What architecture style does your project follow?"
- header: "Architecture"
- options: ["Layered (controller/service/repository)", "Hexagonal (ports & adapters)", "Modular (feature modules)", "None/Flat"]

**Question 2:** "Name your architecture layers (comma-separated, e.g., 'handler,service,repository'):"
- Only ask if architecture is not "None/Flat"
- header: "Layers"
- options: ["handler,service,repository (Recommended)", "controller,service,dao", "api,domain,infrastructure"]

### Round 5: Git Workflow

**Question 1:** "What is your Git branching strategy?"
- header: "Git"
- options: ["GitHub Flow (feature branches → main)", "GitFlow (develop + release branches)", "Trunk-based (short-lived branches)"]

**Question 2:** "What PR tool do you use?"
- header: "PR Tool"
- options: ["gh (GitHub CLI) (Recommended)", "glab (GitLab CLI)", "None"]

**Question 3:** "What branch prefix do you use?"
- header: "Prefix"
- options: ["feat/", "feature/", "None"]

**Question 4:** "What commit format?"
- header: "Commits"
- options: ["Conventional (feat:, fix:, etc.) (Recommended)", "Freeform"]

### Round 6: Quality Gates

**Question 1:** "Which quality gates do you want to enable?"
- header: "Gates"
- multiSelect: true
- options: ["Build gate (build + test pass)", "Test quality gate (coverage, assertions)", "Wiring gate (integration verification)", "Security gate (secrets, vulnerabilities)"]
- Note: Spec compliance gate is always enabled

**Question 2:** "Any sensitive file patterns to protect? (e.g., .env, secrets/)"
- header: "Security"
- options: [".env, .pem, .key, credentials (Recommended defaults)", "Custom patterns", "None"]

## Generate Configuration

After collecting all answers, generate `.specwright/config.json`:

```json
{
  "project": {
    "name": "{collected_name}",
    "structure": "{single-app|multi-service|monorepo}",
    "languages": ["{collected_languages}"],
    "frameworks": {"{language}": "{framework}"}
  },
  "commands": {
    "build": "{collected_build_cmd}",
    "test": "{collected_test_cmd}",
    "lint": "{collected_lint_cmd_or_null}",
    "format": null
  },
  "architecture": {
    "style": "{layered|hexagonal|modular|none}",
    "layers": ["{collected_layers}"],
    "communication": null
  },
  "gates": {
    "enabled": ["{collected_gates}"],
    "wiring": {
      "checkImports": true,
      "checkEndpoints": true,
      "checkEvents": false
    },
    "security": {
      "sensitiveFiles": ["{collected_patterns}"],
      "secretPatterns": ["API_KEY", "SECRET", "PASSWORD", "TOKEN", "PRIVATE_KEY"]
    }
  },
  "git": {
    "workflow": "{github-flow|gitflow|trunk-based}",
    "prTool": "{gh|glab|none}",
    "branchPrefix": "{feat/|feature/|}",
    "commitFormat": "{conventional|freeform}"
  },
  "integration": {
    "omc": "{omcDetected}",
    "omcAgents": {
      "architect": "opus",
      "executor": "sonnet",
      "code-reviewer": "opus",
      "build-fixer": "sonnet",
      "researcher": "sonnet"
    }
  }
}
```

## Create Directory Structure

```bash
mkdir -p .specwright/state
mkdir -p .specwright/memory
mkdir -p .specwright/epics
mkdir -p .specwright/templates
mkdir -p .specwright/domains
```

## Copy and Customize Templates

Read the following template files from the specwright plugin's `templates/` directory
(this is the `templates/` directory at the root of the specwright plugin, adjacent to the `skills/` directory):

| Source (plugin root) | Destination (project) |
|---------------------|-----------------------|
| `templates/spec-template.md` | `.specwright/templates/spec-template.md` |
| `templates/plan-template.md` | `.specwright/templates/plan-template.md` |
| `templates/tasks-template.md` | `.specwright/templates/tasks-template.md` |
| `templates/context-template.md` | `.specwright/templates/context-template.md` |
| `templates/pr-template.md` | `.specwright/templates/pr-template.md` |

For each row: Read the source file, then Write its contents to the destination path.

## Create Initial Constitution

Read `templates/constitution-template.md` from the specwright plugin's `templates/` directory (same location as above: the plugin root `templates/` directory).
Replace `{PROJECT_NAME}` with the collected project name.
Replace `{DATE}` with current date.
Write to `.specwright/memory/constitution.md`.

## Create Initial State Files

### `.specwright/memory/patterns.md`
```markdown
# {PROJECT_NAME} Patterns

> Cross-epic learnings and established patterns.
> Updated by /specwright:learn-review and /specwright:learn-consolidate.

---

_No patterns established yet. Patterns will be captured as you build epics._
```

### `.specwright/state/workflow.json`
```json
{
  "version": "1.0",
  "currentEpic": null,
  "gates": {},
  "lock": null,
  "lastUpdated": "{ISO_TIMESTAMP}"
}
```

## Output Summary

Display the initialization summary:

```
Specwright initialized successfully!

Project: {name}
Languages: {languages}
Architecture: {style}
Quality Gates: {enabled gates}
OMC Integration: {yes/no}

Directory structure created at .specwright/
  config.json     — Project configuration
  memory/         — Constitution and patterns
  state/          — Workflow state
  epics/          — Epic specifications
  templates/      — Customizable templates
  domains/        — Domain roadmaps

Next steps:
1. Review .specwright/memory/constitution.md — add your project principles
2. Run /specwright:roadmap {domain} — plan your first domain
3. Run /specwright:specify {epic-id} — specify your first epic
```

## Compaction Recovery

If this skill is interrupted by compaction:
1. Check if `.specwright/config.json` already exists (partial init)
2. Check which directories exist
3. Resume from the point of interruption
4. Don't re-ask questions if config.json has the answers
