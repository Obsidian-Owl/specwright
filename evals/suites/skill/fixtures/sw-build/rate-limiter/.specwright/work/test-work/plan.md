# Plan: Token Bucket Rate Limiter

## Task 1: Implement rate limiter module

Implement a `RateLimiter` class (or equivalent) in `src/rate-limiter.ts`:

**Constructor**: `new RateLimiter({ capacity, refillRate, refillInterval })`
- Validates all config values are positive integers
- Initializes bucket to full capacity
- Stores config for refill calculations

**Methods**:
- `consume(tokens: number): boolean` — attempts to consume tokens, returns success
- `getAvailableTokens(): number` — returns current available tokens
- `getCapacity(): number` — returns configured capacity

**Refill logic**: On each `consume` or `getAvailableTokens` call, calculate elapsed time since last refill and add proportional tokens (capped at capacity).

## File Change Map

| File | Change | Task |
|------|--------|------|
| `src/rate-limiter.ts` | Create | T1 |
| `src/rate-limiter.test.ts` | Create (by tester) | T1 |
