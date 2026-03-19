# Guardrails Detection Protocol

Stack detection and existing guardrail discovery for sw-guard.

## Three-Step Detection

### Step 1: Manifest Scan

Read dependency manifests at the project root (or workspace roots for monorepos):

| Manifest | Language | Tool signals |
|----------|----------|-------------|
| `package.json` | JS/TS | `scripts` keys (`test`, `lint`, `format`), `devDependencies` package names |
| `pyproject.toml` | Python | `[tool.*]` sections directly identify configured tools (PEP 518) |
| `Cargo.toml` | Rust | Presence → `cargo test`, `cargo clippy`, `cargo fmt` built into toolchain |
| `go.mod` | Go | Presence → `go test`, `gofmt`/`goimports` built into toolchain |
| `pom.xml` | Java | `<artifactId>` under `<plugins>` identifies Maven plugins |

If `.specwright/config.json` exists, read `commands.*` fields as authoritative
overrides — they take precedence over detected tools.

### Step 2: Config File Scan

Check for known config filenames. Presence maps to a specific tool:

**JavaScript / TypeScript:**
- `eslint.config.js`, `.eslintrc.*` → ESLint
- `biome.json`, `biome.jsonc` → Biome (linter + formatter)
- `.prettierrc*` → Prettier
- `tsconfig.json` → TypeScript
- `vitest.config.*`, `jest.config.*` → test runner

**Python:**
- `ruff.toml`, `.ruff.toml`, `[tool.ruff]` in pyproject.toml → Ruff (linter + formatter)
- `mypy.ini`, `[tool.mypy]` in pyproject.toml → mypy
- `pyrightconfig.json` → Pyright
- `pytest.ini`, `[tool.pytest.ini_options]` → pytest

**Rust:**
- `clippy.toml`, `.clippy.toml` → Clippy
- `rustfmt.toml`, `.rustfmt.toml` → rustfmt
- `deny.toml` → cargo-deny (dependency policy)

**Go:**
- `.golangci.yml`, `.golangci.yaml`, `.golangci.toml` → golangci-lint

For unfamiliar stacks or tools not in these mappings, use WebSearch to identify
the project's tooling conventions.

### Step 3: Existing Guardrail Scan

Check for already-configured guardrails at each enforcement layer:

**Agent session hooks:**
- `.claude/settings.json` → Claude Code hooks (check `hooks` key)
- `.claude/settings.local.json` → Claude Code local hooks
- `.opencode/plugins/` → Opencode plugin hooks

**Commit hooks:**
- `.husky/` directory → Husky
- `lefthook.yml`, `lefthook-local.yml` → Lefthook
- `.pre-commit-config.yaml` → pre-commit

**CI workflows:**
- `.github/workflows/*.yml` → GitHub Actions
- `.gitlab-ci.yml` → GitLab CI
- `.circleci/config.yml` → CircleCI

**Git hooks (manual):**
- `.git/hooks/pre-commit`, `.git/hooks/pre-push` (non-sample files)

Report detected guardrails before recommending. Show delta on re-runs —
what exists vs what would be added.
