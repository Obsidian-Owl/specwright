# Design: Hello World Function

## Approach

Add a single function `hello()` that returns the string `"hello"`. No
inputs, no error paths, no integrations.

## Blast Radius

- Modules touched: one new file `src/hello.md` (a stub doc since this
  fixture has no real language toolchain).
- Failure propagation: local — nothing depends on this.
- Does NOT change: anything else in the fixture.

## Notes for sw-plan

This design is deliberately trivial. The purpose is to drive the
pipeline skill (sw-plan in this case) to a clean handoff so its terminal
output can be checked for the three-line format.
