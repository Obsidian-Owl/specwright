# Test Feature Design

## Overview

Add rate limiting to the API gateway to prevent abuse.

## Approach

Use a token bucket algorithm with configurable rate and burst parameters.

## Integration Points

- `src/middleware/` — new rate limiter middleware
- `src/config.ts` — rate limit configuration
- `tests/` — integration tests for rate limiting behavior
