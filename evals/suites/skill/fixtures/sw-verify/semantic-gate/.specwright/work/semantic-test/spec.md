# Spec: Semantic Test

## Acceptance Criteria

### AC-1: Database connection is properly managed
- The service acquires a database connection and releases it on all paths.

### AC-2: Error responses do not leak internal state
- Error responses return user-friendly messages, not stack traces or internal paths.
