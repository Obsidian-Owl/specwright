# Specwright Constitution

Development practices the AI must follow. These are rules, not suggestions.

## Testing

- Tests MUST be written BEFORE implementation. No exceptions.
- Every public function or behavior must have corresponding test coverage.
- Tests must assert behavior, not implementation details.
- Test names must describe the expected behavior, not the method being tested.
- Mock only at system boundaries (external APIs, filesystem, network). Never mock internal modules.
- Test resources (API clients, database records, sandbox instances) must be registered for cleanup at the point of acquisition, not in a separate teardown step. Shared mutable state across subtests is prohibited; read-only fixtures shared for efficiency are acceptable.

## Code Quality

- All public functions must have explicit error handling. No silent failures.
- No `any` types in TypeScript projects. Use proper typing or `unknown` with narrowing.
- Functions must do one thing. If a function needs a comment explaining a section, extract it.
- No magic numbers or strings. Use named constants.
- Prefer immutability. Use `const` by default; mutate only when necessary.

## Git & Commits

- All commits must use conventional commit format: `type(scope): description`.
- Valid types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `ci`, `perf`.
- Each commit must be atomic -- one logical change per commit.
- Never use `git add -A` or `git add .`. Stage specific files only.
- Never force-push to main.

## Architecture

- SKILL.md files define goals and constraints, never procedures.
- Fragile operations (git, state management, agent delegation) must use shared protocols.
- No inline implementation of protocol-governed behavior.
- New skills must follow the existing skill structure: `skills/{name}/SKILL.md`.
- Agent definitions live in `agents/`. Protocols live in `protocols/`.
- When modifying a protocol or skill, check CLAUDE.md and DESIGN.md for stale descriptions of that component.

## Security

- Never hardcode secrets, tokens, or credentials.
- Validate all inputs at system boundaries.
- Scan for secret patterns (API keys, tokens, passwords) before committing.
- Check for injection vulnerabilities in any user-facing content.
- Never expose file paths or internal state to end users without sanitization.
- Skill constraints involving destructive filesystem operations (`rm -rf`, file deletion) must require explicit `realpath` canonicalization and parent-path validation before execution. "Resolves to" without specifying filesystem resolution is insufficient.

## Pull Requests

- PRs must be small and focused on a single concern.
- PR descriptions must reference the spec or work unit being implemented.
- All quality gates must pass before a PR is eligible for merge.
- Follow the git strategy configured in `config.json`. Default to short-lived branches with frequent integration.
