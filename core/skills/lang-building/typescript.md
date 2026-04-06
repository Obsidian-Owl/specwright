# TypeScript Implementation Patterns

Language-specific patterns for TypeScript projects. Loaded by sw-build into agent context.

## Idioms

### Strict Mode
- Always enable `strict: true` in tsconfig.json. Never use `// @ts-ignore` without a comment explaining why.
- Use `unknown` instead of `any`. Narrow with type guards before use.
- Enable `noUncheckedIndexedAccess` for arrays and records — forces undefined checks on bracket access.

### Type Narrowing
- Use discriminated unions with a literal `type` or `kind` field for tagged unions.
- Use `in` operator for structural narrowing: `if ("error" in result)`.
- Use custom type guards (`function isUser(x: unknown): x is User`) for complex narrowing.
- Prefer `satisfies` operator over type assertions when validating object shapes.

### Generics
- Use generics for reusable utilities, not for single-use functions.
- Constrain generics with `extends` to provide useful autocompletion and error messages.
- Use `Record<K, V>` for mapped types. Use `Partial<T>`, `Required<T>`, `Pick<T, K>` for transformations.
- Prefer conditional types over overloads when return type depends on input type.

### Error Handling
- Use `Result<T, E>` pattern (custom or from a library) for expected failures. Reserve exceptions for unexpected errors.
- Always type catch clause variables as `unknown`, then narrow: `catch (e) { if (e instanceof Error) ... }`.
- Use `never` return type for functions that always throw.
- At API boundaries, validate external data with Zod or similar — never trust `as` assertions on external input.

## Type Patterns

- Use `interface` for public API shapes (extendable). Use `type` for unions, intersections, and computed types.
- Use `readonly` arrays and properties by default. Mutate only in clearly scoped functions.
- Use branded types for domain identifiers: `type UserId = string & { readonly __brand: "UserId" }`.
- Use `const` assertions for literal types: `as const` on object/array literals.

## Framework Conventions

### Next.js (App Router)
- Server Components are the default. Use `"use client"` only for interactivity (state, effects, event handlers).
- Use `generateMetadata()` for SEO. Use `loading.tsx` and `error.tsx` for Suspense boundaries.
- Data fetching happens in Server Components via `async` functions, not `useEffect`.
- Use Route Handlers (`route.ts`) for API endpoints. Use Server Actions for form mutations.

### React
- Use hooks for state and effects. Never call hooks conditionally.
- Use `useMemo` and `useCallback` only when you have measured a performance problem. Premature memoization adds complexity.
- Lift state to the lowest common ancestor. Use context for truly global state (theme, auth), not for component communication.
- Use `React.forwardRef` and `useImperativeHandle` sparingly — prefer declarative APIs.

### Node.js
- Use `async/await` consistently. Never mix callbacks and promises.
- Use `AbortController` for cancellation. Pass `signal` to fetch, streams, and long-running operations.
- Use `node:` protocol for built-in imports: `import { readFile } from "node:fs/promises"`.

## Anti-Patterns

- **`any` escape hatch**: Never use `any` to bypass type errors. Use `unknown` and narrow.
- **Type assertion chains**: `(value as Foo as Bar)` is a code smell. Restructure the types.
- **Enum misuse**: Prefer union types (`type Status = "active" | "inactive"`) over enums for most cases. Enums have runtime overhead and surprising behavior with reverse mapping.
- **Non-null assertion abuse**: `value!.property` suppresses null checks. Use optional chaining (`value?.property`) or explicit guards.
- **Barrel file bloat**: `index.ts` re-exports slow down bundlers and create circular dependency risk. Export directly from source files.
- **useEffect for data fetching**: In Next.js App Router, fetch in Server Components. In client-only apps, use SWR/React Query, not raw useEffect.
