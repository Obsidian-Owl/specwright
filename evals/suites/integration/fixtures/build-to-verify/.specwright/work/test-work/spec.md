# Rate Limiter Spec

## Acceptance Criteria

**AC-1**: Requests within the rate limit (10 req/s) receive HTTP 200.

**AC-2**: Requests exceeding the rate limit receive HTTP 429 with a `Retry-After` header.

**AC-3**: Rate limit configuration is loaded from environment variables `RATE_LIMIT` and `RATE_BURST`.
