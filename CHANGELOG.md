# Changelog

All notable changes to Specwright will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).



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
