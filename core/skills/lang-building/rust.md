# Rust Implementation Patterns

Language-specific patterns for Rust projects. Loaded by sw-build into agent context.

## Idioms

### Ownership and Borrowing
- Pass by reference (`&T`) by default. Transfer ownership only when the function needs to store the value.
- Use `&str` for string parameters, `String` for owned storage. Same pattern: `&[T]` for slices, `Vec<T>` for owned collections.
- Prefer borrowing over cloning. Use `.clone()` only when ownership semantics require it or the cost is negligible.
- Use lifetime annotations only when the compiler requires them. Let elision handle the common cases.

### Result and Option
- Use `Result<T, E>` for operations that can fail. Use `Option<T>` for values that may be absent.
- Use the `?` operator for error propagation. Chain with `.map_err()` to add context.
- Use `anyhow::Result` for application code, custom error enums for library code.
- Use `thiserror` for deriving `Error` implementations on custom error types.
- Prefer `.map()`, `.and_then()`, `.unwrap_or_default()` over `match` for simple transformations.
- Never `.unwrap()` in library code. Use `.expect("reason")` only in tests or provably safe contexts.

### Trait Implementations
- Implement `Display` for user-facing output, `Debug` for developer debugging (derive `Debug` on all types).
- Implement `From<T>` for infallible conversions. Use `TryFrom<T>` for fallible ones. These enable `?` and `.into()`.
- Use `impl Trait` in argument position for simple generics. Use named generics when the type is referenced multiple times.
- Derive standard traits liberally: `Clone`, `Debug`, `PartialEq`, `Eq`, `Hash` when semantically appropriate.

### Pattern Matching
- Use `match` for exhaustive enumeration. The compiler enforces all variants are handled.
- Use `if let` for single-variant extraction. Use `while let` for iterator-like patterns.
- Use `_` for ignored bindings, `..` for ignored struct fields.

## Type Patterns

- Use newtypes for domain concepts: `struct UserId(String)`. This prevents accidental mixing at zero runtime cost.
- Use `enum` for state machines and tagged unions. Each variant can carry its own data.
- Use `Box<dyn Trait>` for trait objects when dynamic dispatch is needed. Prefer static dispatch (`impl Trait` or generics) when possible.
- Use `Cow<'_, str>` when a function may or may not need to allocate.

## Error Handling Patterns

- Define a crate-level error enum that implements `std::error::Error`.
- Use `#[from]` attribute (via `thiserror`) for automatic `From` implementations.
- Add context with `.context("what was being done")` (via `anyhow`) or custom `.map_err()`.
- At binary/API boundaries, convert errors to user-facing messages. Never expose internal error details.

## Testing Patterns

- Use `#[cfg(test)]` modules in the same file for unit tests.
- Use `#[ignore]` for tests requiring external infrastructure (mark integration tests).
- Use `proptest` or `quickcheck` for property-based testing at boundary functions.
- Use `assert_matches!` macro for pattern-matching assertions.
- Use `tokio::test` for async test functions.

## Anti-Patterns

- **Unwrap in production code**: `.unwrap()` panics on `None`/`Err`. Use `?`, `.unwrap_or()`, or `match`.
- **Stringly typed APIs**: Use enums and newtypes, not raw strings, for domain values.
- **Excessive cloning**: Clone hides ownership issues. If you're cloning frequently, reconsider the data flow.
- **Mutex poisoning ignorance**: Always handle `PoisonError` from `Mutex::lock()`. Use `.lock().expect("reason")` with an actual reason.
- **Blocking in async context**: Never call blocking I/O inside `async fn`. Use `tokio::task::spawn_blocking()`.
- **Overly complex lifetimes**: If lifetime annotations make the code unreadable, restructure to use owned types or `Arc`.
