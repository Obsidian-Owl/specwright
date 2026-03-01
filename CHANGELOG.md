# Changelog

All notable changes to Specwright will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).










## [0.11.0] - 2026-03-01

### Changed

- feat(learning): close capture-to-context gap with auto-memory integration (#52)

## [0.10.0] - 2026-02-26

### Changed

- docs: fix stale protocol count in README (12 → 14) (#50)
- feat(quality-depth): add build depth & documentation guidance (#49)
- feat(quality-depth): add research & build discipline guidance (#48)
- feat(skills): add code budget and completion criteria to sw-plan and sw-design (#47)

## [0.9.1] - 2026-02-24

### Changed

- fix(audit): resolve WARN findings AUD-001 through AUD-005 (#45)

## [0.9.0] - 2026-02-24

### Changed

- feat: update downstream skills, hook, and docs for per-unit specs (#43)
- feat(sw-build,sw-ship): workDir paths, branch naming, unit advancement (#42)
- feat(sw-plan): rewrite for per-unit specs with individual review (#41)
- feat(protocols): add per-unit spec support to state protocol (#40)

## [0.8.0] - 2026-02-19

### Changed

- feat(design): add assumption surfacing and resolution to design workflow (#38)
- fix(docs): correct inaccurate comparison claims against other plugins (#37)
- fix: correct broken links in comparison table (#36)

## [0.7.1] - 2026-02-16

### Changed

- fix(hooks): use plugin root path and deterministic stop script (#34)
- docs: polish README and add contributor scaffolding (#30)

## [0.7.0] - 2026-02-15

### Added

- **Codebase Landscape** (`LANDSCAPE.md`) — Persistent codebase knowledge document covering architecture, modules, conventions, and gotchas. Created during `/sw-init` (optional survey phase), loaded by `/sw-design` with automatic staleness refresh, incrementally updated by `/sw-learn` after shipping. New `protocols/landscape.md` defines format, size targets (500-3000 words), and freshness rules (7-day default, configurable). (#26)
- **Codebase Audit** (`/sw-audit`) — Periodic health check skill that finds systemic issues per-change gates miss. Four dimensions: architecture, complexity, consistency, debt. Delegates to architect and reviewer agents, synthesizes findings into persistent `AUDIT.md` with stable finding IDs across re-runs. Adaptive intensity: focused (path), standard (small projects), full (large projects, parallel agents). New `protocols/audit.md` defines finding format, ID matching, lifecycle, and freshness. (#27)
- **Audit integration with design** — `/sw-design` now loads `AUDIT.md` during research and surfaces relevant findings for the area being designed
- **Audit integration with learn** — `/sw-learn` checks if shipped work addresses open audit findings and marks them resolved

### Changed

- `protocols/context.md` — Reference Documents section now includes both `LANDSCAPE.md` and `AUDIT.md` (optional, load on demand)
- Skill count: 14 → 15 (10 user-facing + 5 gates)
- Protocol count: 11 → 12
- README updated with Codebase Knowledge and Health section, version footer corrected
- DESIGN.md Reference Documents section documents both LANDSCAPE.md and AUDIT.md lifecycles

## [0.6.0] - 2026-02-15

### Added

- **Adaptive intensity** — `/sw-design` triages requests as Full, Lite, or Quick based on complexity. Lite skips design.md, Quick skips straight to build
- **Session hooks** — `hooks/session-start.md` loads recovery protocol on compaction detection
- **Stop guard** — `/sw-guard` can now configure stop-on-error hooks for CI/CD layers
- **Compaction recovery** — All stateful skills check for compaction and resume from last completed step

## [0.5.2] - 2026-02-13

### Changed

- feat(skills): insights-driven refinements from usage analysis (#21)

## [0.5.1] - 2026-02-13

### Changed

- feat(skills): add native task tracking to sw-build (#19)
- feat(ci): split release into PR + finalize workflows (#18)
- fix(docs): correct README workflow description and diagram
- fix(assets): loop feedback arc from learn back to build
- fix(assets): add design node to banner SVG pipeline

## [0.5.0] - 2026-02-12

### Added

- **sw-design skill** — Interactive solution architecture with research, adversarial critic, and user approval. Produces `design.md`, `context.md`, and conditional artifacts (`decisions.md`, `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`)
- **`designing` workflow status** — New state in `currentWork.status` with transitions: `(none) → designing` (sw-design) and `designing → planning` (sw-plan)
- **Change request support** — Re-run `/sw-design <changes>` to modify an existing design through the change request flow

### Changed

- **sw-plan rewritten** — Removed research, design, triage, and critic phases (now in sw-design). Focused on decomposition and testable specs. Reads design artifacts as input. 108 lines (down from 154)
- **sw-build** — Includes `design.md` in inputs and context envelope for agent delegation
- **sw-verify** — Failure mode references updated to include `/sw-design`
- **sw-status** — Suggests `/sw-design` when no active work
- **Stage boundary protocol** — Added sw-design handoff and anti-advancement rules
- **Context protocol** — Entry point references `/sw-design` instead of `/sw-plan`
- Workflow: `/sw-init → /sw-design → /sw-plan → /sw-build → /sw-verify → /sw-ship`
- Skill count: 13 → 14 (9 user-facing + 5 gates)

## [0.4.0] - 2026-02-12

### Added

- **Strategy-aware git protocol** (`protocols/git.md`) — supports trunk-based, github-flow, gitflow, and custom strategies with full branch lifecycle (create → work → push → cleanup)
- **Git config schema** — 10 configurable fields (strategy, baseBranch, branchPrefix, mergeStrategy, prRequired, commitFormat, commitTemplate, branchPerWorkUnit, cleanupBranch, prTool) with documented defaults
- **Git workflow detection in sw-init** — scans branch names, remotes, and CI files to detect strategy; confirms via AskUserQuestion
- **Work unit queue** (`workUnits` array in workflow.json) — multi-unit decomposition tracking with per-unit status
- **State transition validation** — 6 valid transitions documented with enforcement rules; invalid transitions produce clear error messages
- **Work unit queue display** in sw-status — shows full queue with status indicators and current marker

### Changed

- sw-build creates feature branch as FIRST action before coding (reads config, handles recovery)
- sw-ship creates strategy-aware PRs (config-driven target, prRequired toggle, commitFormat-styled titles)
- sw-ship advances to next work unit after shipping when workUnits queue exists
- sw-plan populates workUnits array during decomposition with per-unit work directories
- Commit formatting supports conventional, freeform, and custom templates with scope detection
- Protocol token total updated to ~1850 (from ~1450)
- CLAUDE.md and DESIGN.md descriptions updated for strategy-aware git and state enhancements

### Fixed

- CLAUDE.md stale descriptions (git.md and sw-ship were still "trunk-based")
- sw-init missing AskUserQuestion in allowed-tools frontmatter
- Old config.json schema detection and migration path added to sw-init

## [0.3.0] - 2026-02-12

### Added

- **Stage boundary protocol** (`protocols/stage-boundary.md`) — defines scope declaration, anti-advancement rules, termination handoffs, and handoff map to prevent skills from auto-advancing between workflow stages
- **Learning lifecycle protocol** (`protocols/learning-lifecycle.md`) — compaction triggers, tiered memory with themes for long-running projects
- **Insights protocol** (`protocols/insights.md`) — external Claude Code session data access for pattern enrichment
- **sw-learn persistence** — learnings saved to `.specwright/learnings/` with structured JSON schema, retrospective across units, and compaction into themed summaries
- **Decomposition cycle output** — sw-plan now shows the expected build → verify → ship cycle per work unit during decomposition

### Changed

- All 5 workflow skills (sw-plan, sw-build, sw-verify, sw-ship, sw-learn) now include stage boundary enforcement with LOW-freedom constraints, scope declarations, and termination handoffs
- sw-learn enhanced with discovery, presentation, promotion, retrospective, enrichment, and compaction phases
- Protocol table in DESIGN.md updated (10 protocols, ~1450 tokens total)
- CLAUDE.md protocol list updated with stage-boundary, insights, and learning-lifecycle entries
- README redesigned with banner, mermaid workflow diagram, and verification-focused messaging

### Fixed

- Protocol naming de-coupled from sw-learn skill name for reusability

## [0.2.0] - 2026-02-11

### Changed

- fix(skills): add Task tool and update docs for sw-guard
- feat(skills): add sw-guard skill for interactive guardrail configuration

## [0.1.2] - 2026-02-10

### Changed

- ci: add automated release and PR validation workflows

## [0.1.1] - 2026-02-11

### Fixed
- Plugin source path in marketplace.json (`"."` → `"./"`) — was preventing installation
- Installation command in README — now shows both steps (marketplace add + plugin install)
- Removed `bash` language tag from slash command code blocks in README

### Added
- `$schema` reference in marketplace.json for validation
- `strict: false` in marketplace.json to prevent manifest merge conflicts

### Removed
- `displayName` field from plugin.json (not in official schema)

## [0.1.0] - 2026-02-10

### Added
- Complete spec-driven workflow: init → plan → build → verify → ship → learn
- 7 user-facing skills and 5 quality gate skills
- 6 specialized agents (architect, tester, executor, reviewer, build-fixer, researcher)
- 7 shared protocols for fragile operations
- Anchor documents (Constitution + Charter)
- Session recovery via hooks
- Evidence-based quality gates with adversarial testing
