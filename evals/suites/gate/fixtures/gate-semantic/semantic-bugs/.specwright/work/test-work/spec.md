# Spec: Order Handler

## Acceptance Criteria

### AC-01: Create order persists to database
POST /orders creates a new order record in the database.

### AC-02: Error responses do not leak internal details
All error responses return a generic message, never stack traces or internal paths.

### AC-03: Database connections are released on all paths
Database connections acquired during request handling are released whether the request succeeds or fails.
