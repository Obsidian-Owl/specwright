# Repo Map Protocol

Lightweight codebase context map for build-time agent delegation.

## Format

Markdown with file paths as H3 headers and indented symbol signatures as list items:

```markdown
### src/handlers/auth.ts
- `export function authenticate(req: Request): Promise<User>`
- `export function validateToken(token: string): boolean`
- `export class AuthMiddleware`

### src/models/user.ts (dependent)
- `export interface User`
- `export function findById(id: string): Promise<User | null>`
```

Changed files appear first (no label). Direct dependents are labeled `(dependent)`.

## Generation Method

Use ast-grep `kind` rules to match definition nodes per language:

**JavaScript / TypeScript:**
- `kind: function_declaration`, `kind: class_declaration`, `kind: export_statement`
- `kind: interface_declaration`, `kind: type_alias_declaration`

**Python:**
- `kind: function_definition`, `kind: class_definition`

**Go:**
- `kind: function_declaration`, `kind: type_declaration`, `kind: method_declaration`

**Rust:**
- `kind: function_item`, `kind: impl_item`, `kind: struct_item`, `kind: trait_item`

**Extraction commands:**
- When a project-level `sgconfig.yml` exists: `sg scan --json` operates on the
  project directory using configured rules. Extract `text` field truncated to the
  first line (signature only, not body).
- For per-file extraction without sgconfig: `sg run --pattern '...' --lang <lang> <file> --json`.
  This is the primary command for repo map generation.

Note: `sg scan` does NOT accept individual file arguments — it operates on
directories with a config file. Use `sg run` for targeted per-file extraction.

## Scope

1. **Changed files**: read from the plan's file change map (`plan.md` File Change Map
   table). These are the files the current work unit will modify.
2. **Direct dependents**: files that import/require/use the changed files. Detected by
   grepping the codebase for import patterns referencing changed file paths.

**Import patterns per language:**
- ES6: `import ... from '<path>'` or `import '<path>'`
- CommonJS: `require('<path>')`
- Python: `import <module>` or `from <module> import ...`
- Go: `import "<path>"`
- Rust: `use <path>`

Dependency detection is heuristic — dynamic imports, re-exports, and aliased paths
may be missed. A missed dependent makes the map incomplete but not incorrect.

## Token Budget

Default: 1024 tokens. Configurable via `config.context.repoMapTokens`.

Token estimation: `Math.ceil(wordCount * 1.3)`.

## Truncation

When the map exceeds the token budget:
1. Remove symbols from dependent files first (before changed-file symbols).
2. Within dependents, remove deeper-nested symbols before top-level symbols.
3. If still over budget after removing all dependents, truncate changed-file symbols
   starting from the file with the fewest imports from other changed files (least
   coupled to the changeset). Tie-break: alphabetical order. The ordering is a
   heuristic — some information loss is acceptable since file path headers are
   always preserved.
4. Always preserve at least the file path headers — a list of paths with no symbols
   is still useful context.

## Failure Modes

| Condition | Action |
|-----------|--------|
| ast-grep (`sg`) absent | Degrade to file listing (paths only, no signatures) |
| ast-grep exits with nonzero code | Treat as absent — degrade to file listing, log WARN |
| No changed files in plan | Produce empty map (empty file or header only) |
| Dependency detection misses a file | Map is incomplete but not incorrect — no error |
| Token budget exceeded after truncation | Truncate to budget strictly; never exceed |

## Lifecycle

- Generated once per build (before the first task in sw-build).
- Stored at `{currentWork.workDir}/repo-map.md`.
- Ephemeral — not persisted across builds.
- Consumed by: context envelope (prompt injection), SubagentStart hook (backup).
