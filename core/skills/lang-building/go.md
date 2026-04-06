# Go Implementation Patterns

Language-specific patterns for Go projects. Loaded by sw-build into agent context.

## Idioms

### Error Handling
- Always check errors immediately: `if err != nil { return fmt.Errorf("context: %w", err) }`.
- Wrap errors with context using `%w` for unwrapping, `%v` when wrapping would leak internals.
- Never ignore errors silently. If intentionally discarding, assign to `_` with a comment.
- Use sentinel errors (`var ErrNotFound = errors.New(...)`) for expected conditions. Use `errors.Is()` and `errors.As()` for checks.
- Return early on error. Avoid deep nesting.

### Interface Patterns
- Define interfaces where they are consumed, not where they are implemented. Small interfaces (1-3 methods) compose better.
- Accept interfaces, return structs. This keeps implementations concrete and testable.
- Use `io.Reader`, `io.Writer`, `context.Context` from the standard library before creating custom interfaces.

### Naming and Structure
- Package names are lowercase, single-word. No underscores, no camelCase.
- Exported names start with uppercase. Keep unexported by default; export only what consumers need.
- Use `internal/` packages to prevent cross-boundary imports.
- Group related types in the same file. One file per major concept, not one file per type.

### Concurrency
- Prefer channels for coordination, mutexes for state protection.
- Always pass `context.Context` as the first parameter for cancellation and timeouts.
- Use `sync.WaitGroup` for fan-out/fan-in. Use `errgroup.Group` when errors matter.
- Never start a goroutine without a plan for how it stops.

## Type Patterns

- Use struct embedding for composition, not inheritance simulation.
- Define custom types for domain concepts: `type UserID string` prevents accidental mixing.
- Use `time.Duration` not `int` for time values. Use `time.Time` not `int64` for timestamps.
- Prefer value receivers for immutable methods, pointer receivers for mutation.

## Framework Conventions

### Encore
- Use `encore.dev` service annotations for automatic infrastructure provisioning.
- `et.NewTestDatabase()` provides ephemeral test databases — always use for DB tests.
- PubSub topics are declared as package-level vars with `pubsub.NewTopic[T]()`.
- API endpoints use `//encore:api` annotations with typed request/response structs.

### Standard Library
- Use `net/http` with `http.Handler` interface for HTTP services.
- Use `database/sql` with prepared statements. Never interpolate SQL strings.
- Use `encoding/json` struct tags for serialization. `omitempty` for optional fields.

## Anti-Patterns

- **Naked returns**: Never use naked returns in functions longer than 5 lines. They obscure what is returned.
- **Init functions**: Avoid `init()` — it makes testing harder and ordering implicit. Use explicit initialization.
- **Global state**: Avoid package-level mutable variables. Pass dependencies explicitly.
- **Panic in libraries**: Libraries should return errors, never panic. Panics are for truly unrecoverable states in main packages.
- **Empty interface abuse**: `interface{}` / `any` loses type safety. Use generics or concrete types instead.
- **Ignoring context cancellation**: Always check `ctx.Err()` in long-running operations and `select` on `ctx.Done()` in loops.
