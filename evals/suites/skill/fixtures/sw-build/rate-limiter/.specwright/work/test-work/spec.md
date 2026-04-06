# Spec: Token Bucket Rate Limiter

## Acceptance Criteria

### AC-01: Consume succeeds when tokens available
`consume(tokens)` returns `true` when the bucket has sufficient tokens. After consuming, the available token count decreases by the requested amount.

### AC-02: Consume fails when bucket exhausted
`consume(tokens)` returns `false` when the bucket does not have enough tokens. The bucket state is unchanged (no partial consumption).

### AC-03: Bucket refills over time
The bucket refills at `refillRate` tokens per `refillInterval` milliseconds. After waiting the refill interval, previously exhausted tokens become available again. The bucket never exceeds its configured `capacity`.

### AC-04: Invalid configuration throws
Creating a rate limiter with `capacity <= 0`, `refillRate <= 0`, or `refillInterval <= 0` throws an error with a descriptive message.

### AC-05: Consume with zero or negative tokens throws
`consume(0)` and `consume(-1)` throw an error. Only positive integer token amounts are accepted.

### AC-06: Bucket state is queryable
`getAvailableTokens()` returns the current number of available tokens. `getCapacity()` returns the configured capacity.
