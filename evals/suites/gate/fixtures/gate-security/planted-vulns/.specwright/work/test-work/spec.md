# Spec: File Server API

## Acceptance Criteria

### AC-01: Server authenticates API requests
All API endpoints require a valid API key in the Authorization header.

### AC-02: Server supports file retrieval
GET /files/:filename returns the requested file from the data directory.

### AC-03: Server supports user search
GET /users?name=:query returns matching users from the database.
