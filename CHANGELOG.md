# Changelog

All notable changes to Specwright will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).






































## [0.32.0] - 2026-04-22

### Changed

- Revive shared operator surface cutover (#208)
- test(runtime): harden true-bare root fallback coverage (#207)
- docs(workflow): align verify scheduling and workflow policy (#206)
- feat(freshness): automate lifecycle-owned recovery (#204)
- feat(operator-surface): add shared status card contract (#203)
- fix(ownership): require explicit worktree adoption (#202)
- docs(pivot): cut over docs and prompt guidance (#201)
- fix(pivot): align remaining-work regeneration (#199)
- feat(pivot): broaden rebaselining contract (#198)
- test(evals): isolate nested git env in pre-push fixtures (#197)
- fix(sync): guard gone-branch cleanup and operator workflow proof (#194)
- feat(operator-surface): cut over shared operator surfaces (#192)
- feat(runtime): add project-visible runtime roots (#191)
- feat(closeout): add approval and handoff foundations (#190)

## [0.31.0] - 2026-04-20

### Changed

- feat(verify): add accepted-mutant lineage proof surfaces (#186)
- feat(mutation): add tiered mutation analysis (#185)
- feat(mutation-contract): add mutation contract foundation (#184)

## [0.30.0] - 2026-04-16

### Changed

- docs(audit-chain): prove workflow and finish migration (#181)
- docs(audit-chain): cut support surfaces to audit chain (#180)
- docs(audit-chain): add rationale and review packet workflow (#179)
- feat(audit-chain): add durable approval lifecycle (#178)
- feat(audit-chain): establish tracked artifact root model (#177)
- test(workflow-proof): prove branch freshness lifecycle coverage (#176)
- docs(04-config-validation-and-visibility): ship unit 04 config validation and visibility (#175)
- docs(03-lifecycle-checkpoint-cutover): ship unit 03 lifecycle checkpoint cutover (#174)
- feat(02-git-freshness-engine): ship unit 02 git freshness engine (#173)
- feat(01-target-model-foundation): ship unit 01 target model foundation (#172)
- ci(release): stabilize npm publish in release-finalize (#171)

## [0.29.0] - 2026-04-14

### Changed

- feat(state): add multi-worktree runtime proof (#169)
- fix(codex): align installer contract and hook context (#168)
- feat(04-pipeline-skill-cutover): ship unit 04 pipeline skill cutover (#167)
- feat(03-init-and-migration-surfaces): ship unit 03 init and migration surfaces (#166)
- fix(codex): align command contract and nested git state (#165)
- feat(02-work-and-session-state-model): ship unit 02 work and session state model (#164)
- feat(01-root-resolution-foundation): ship unit 01 root resolution foundation (#163)
- test(recovery): add closeout runtime proof for the final IC-B criteria (#161)
- feat(evals): add snapshot-based integration assertions (#159)

## [0.28.0] - 2026-04-08

### Changed

- refactor(protocols): merge decision protocols (#157)
- refactor(protocols): delete orphan protocols (#156)
- feat(evals): add structural smoke evals and seed smoke baseline (#155)
- feat(codex): add release bundle installer (#154)
- feat(evals): CI integration for baseline comparison + weekly full runs (unit 02b-2 of legibility recovery) (#152)
- feat(codex): add Codex CLI adapter (#153)
- feat(evals): baseline schema, loader, comparison logic + smoke filter (unit 02b-1 of legibility recovery) (#151)
- fix(state): relax enforcement of optional skills in core pipeline (unit 02 of legibility recovery) (#150)
- refactor(protocols): strip gate handoff template to three lines (unit 01 of legibility recovery) (#149)

## [0.27.2] - 2026-04-07

### Changed

- docs: clarify "autonomous" vs background execution (#146)

## [0.27.1] - 2026-04-07

### Changed

- feat: stage enforcement — shipping state, PreToolUse hook, evidence integrity (#144)

## [0.27.0] - 2026-04-06

### Changed

- feat: eval quality v2 — fix grading infrastructure, expand coverage, subagent quality (#142)
- feat: audit remediation — prompt quality, agent scope, eval infrastructure (#141) (#141)
- feat: add language-aligned building pattern files (#140)
- feat: add deliverable verification and tier distribution (WU-03) (#139)
- feat: add tier-aware delegation to sw-build (WU-02) (#138)
- feat: add testing tier framework (WU-01) (#137)

## [0.26.2] - 2026-04-02

### Changed

- fix(ci): pin npm@11 for provenance publish compatibility (#134)

## [0.26.1] - 2026-04-02

### Changed

- fix(ci): pin npm@10 to avoid MODULE_NOT_FOUND on Node 22.22.2 (#132)

## [0.26.0] - 2026-04-02

### Changed

- feat(protocols): integrate semi-formal reasoning into quality gates (#130)

## [0.25.3] - 2026-04-02

### Changed

- fix(ci): configure OIDC trusted publishing for npm (#128)

## [0.25.2] - 2026-04-02

### Changed

- fix(ci): remove registry-url from setup-node to enable OIDC publish (#126)

## [0.25.1] - 2026-04-02

### Changed

- fix(ci): use OIDC trusted publishing for npm instead of token auth (#124)

## [0.25.0] - 2026-03-31

### Changed

- feat(protocols): worktree safety hardening — detection, protection, degradation (#122)
- feat(gate-wiring): cross-unit integration verification for multi-unit designs (#121) (#121)

## [0.24.0] - 2026-03-27

### Changed

- fix(verify): semantic gate reliability — dual-format detection + evidence validation (#119)

## [0.23.0] - 2026-03-26

### Changed

- feat(skills): support skills fully artifact-driven — 24 interventions → 0 prompts, -492 words (#116)
- feat(skills): core pipeline autonomous operation — 30 interventions → 5 gates, -1370 words (#115)
- feat(protocol): autonomous decision framework — Type 1/2, CCR, gate handoffs (#114)
- feat(testing): tester integration discipline, tiered init, learn gaps, AGENTS.md sync (#113)
- feat(testing): tiered test execution — gate-build tiers, sw-build inner-loop, build-fixer infra awareness (#112)

## [0.22.0] - 2026-03-23

### Changed

- feat(sw-verify): enriched handoff with actionable findings table (#110)
- feat(sw-review): add PR comment review utility skill (#109)
- feat(sw-sync): add git housekeeping utility skill (#108)

## [0.21.0] - 2026-03-23

### Changed

- test(quality): hook behavioral tests, semantic gate eval fixture, and correction bridge E2E (#106) (#106)
- feat(feedback): PostToolUse diagnostics, per-task micro-checks, and compaction correction bridge (#101) (#105)
- feat(build): repo map protocol, SubagentStart context injection, and context envelope (#101) (#104)
- feat(gate-semantic): tiered extraction, new categories, and calibration constraint (#101) (#103)
- feat(foundation): semantic context enhancements — charter, detection, patterns, health checks (#102)

## [0.20.0] - 2026-03-22

### Changed

- feat(gate): add gate-semantic — experimental neuro-symbolic semantic analysis (#100)
- feat(quality): retro-driven refinements — security gate Phase 3, executor grounding, mandatory calibration (#99)

## [0.19.0] - 2026-03-20

### Changed

- feat(guard): redesign sw-guard with four-layer enforcement (#97)
- feat(protocols): headless execution protocol for non-interactive skills (#95)

## [0.18.0] - 2026-03-19

### Changed

- feat(testing): TESTING.md anchor document + spec review test-type dimension (#92)

## [0.17.0] - 2026-03-19

### Changed

- feat(evals): subagent-based eval runner + grading CLI + tech debt cleanup (#90)
- fix(ci): make release workflow idempotent on re-runs (#89)
- feat(workflow): harden all skills with adversarial challenge and strategic alignment (#88)
- fix(evals): model grader --verbose + execution telemetry in grading.json (#87)
- refactor(evals): remove unnecessary plugin_dir threading (#86)
- feat(evals): schema validator + integration smoke tests (#85)
- feat(evals): CLI orchestrator with plugin-dir, repo seeds, and first real run (#84)
- feat(evals): aggregation, model grading, viewer, and Layer 2/3 eval suites (#83)
- feat(evals): eval framework core — runner, graders, chainer, fixtures (#82)
- docs: address remaining audit WARNING findings (F2, F4, F7, F8) (#81)
- feat(lifecycle): state cleanup transition and work directory cleanup (#80)
- test(claude-code): comprehensive build output test suite (#79)
- feat(build): conditional platform markers for core/adapter layering (#78)

## [0.16.0] - 2026-03-13

### Changed

- Claude/review specwright enhancements tgv0v (#76)
- design: quality enhancements across all Specwright phases (#75)
- docs: fix opencode package name to scoped @obsidian-owl/opencode-specwright (#74)

## [0.15.0] - 2026-03-09

### Changed

- feat(opencode): unified release process with npm publishing (#72)
- docs: multi-platform README with Opencode installation (#71)
- docs: update stale docs for cross-platform architecture (#70)
- feat(opencode): add opencode adapter for cross-platform distribution (#68)
- Add Claude Code GitHub Workflow (#69)
- feat(build): add build pipeline for cross-platform distribution (#67)
- refactor: restructure repo into core/ + adapters/ for cross-platform distribution (#66)
- docs: document experimental agent teams feature in README and DESIGN (#65)

## [Unreleased]

### Added

- **Cross-platform distribution** — Restructured into universal `core/` + per-platform `adapters/` architecture with build pipeline producing platform-specific packages (#66, #67, #68)
- **Opencode adapter** — Full adapter for Opencode: mapping file, package.json, plugin entry point with lifecycle events, 14 command files, skill overrides for sw-guard and sw-build (#68)
- **Build pipeline** (`build/build.sh`) — Builds platform-specific packages from core + adapters to `dist/`. Supports tool name transforms, tool stripping, protocol path rewrites, agent translation, and skill overrides with post-override re-transformation (#67)
- **Platform mapping files** (`build/mappings/`) — Per-platform JSON configs defining tool mappings, strip lists, event mappings, model IDs, and skill overrides (#67, #68)
- **Claude Code GitHub Actions** — Workflows for `@claude` mentions and automated PR code review (#69)

### Changed

- Skills, protocols, and agents moved from root to `core/` directory (#66)
- Claude Code-specific files moved to `adapters/claude-code/` (#66)
- Root-level `skills/`, `protocols/`, `agents/` are now symlinks to `core/` for backwards compatibility (#66)
- CONTRIBUTING.md updated with new architecture layout, correct file counts, and token targets (#70)
- AGENTS.md protocols list corrected (added missing `insights.md`) (#70)
- AGENTS.md protocols list corrected (added missing `insights.md`)

## [0.14.0] - 2026-03-07

### Changed

- feat(agent-teams): add experimental parallel build with agent teams (#63)
- docs: update README, DESIGN, and CLAUDE for sw-research and missing skills (#62)

## [0.13.0] - 2026-03-06

### Changed

- feat(skills): add sw-research skill for deep outward-facing research (#60)
- docs: update skills tables and file counts for sw-effectiveness additions (#59)

## [0.12.0] - 2026-03-04

### Changed

- feat(experience): add build status cards and backlog routing across skills (#57)
- feat(quality): add spec pre-review to sw-plan and sw-doctor health check (#56)
- feat(skills): add sw-debug and sw-pivot investigation skills (#55)
- feat(protocols): add backlog tracking and spec-review protocols (#54)

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
