# Changelog

All notable changes to Specwright will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


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
