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

**Secret detection (cross-language):**
- `.gitleaks.toml` → gitleaks
- `.secrets.baseline` → detect-secrets

**Semantic analysis (cross-language):**
- `.ast-grep/` directory, `sgconfig.yml` → ast-grep
- `.opengrep/` directory → OpenGrep

Note: `.ast-grep/` or `sgconfig.yml` indicates ast-grep is configured for this
project, but the `sg` binary must also be on PATH for the tool to be available.
Config presence without the binary means the tool is configured but not installed.

**Semantic analysis tools on PATH:**
- `sg` → ast-grep (validate with `which sg`)
- `opengrep` → OpenGrep (validate with `which opengrep`)

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

**Platform LSP:**
- `.lsp.json` in plugin directory → Claude Code LSP plugin
- `.opencode/` configuration with LSP settings → Opencode built-in LSP
- `cli-lsp-client` on PATH (validate with `which cli-lsp-client`) → standalone LSP daemon

When platform LSP (Claude Code or Opencode) is detected alongside `cli-lsp-client`,
emit a conflict warning: running duplicate LSP servers for the same workspace causes
resource doubling (500MB-10GB per duplicate), functional conflicts (Cargo.lock
contention, gopls cache corruption), and inotify exhaustion on Linux.
`cli-lsp-client` should only be used as a standalone fallback when no platform LSP
is available.

Report detected guardrails before recommending. Show delta on re-runs —
what exists vs what would be added.
