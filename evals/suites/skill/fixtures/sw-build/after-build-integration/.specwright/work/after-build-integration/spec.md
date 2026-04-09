# After-Build Integration Spec

## Acceptance Criteria

**AC-1**: `normalizeName("  aLIce  ")` returns `"Alice"`.

**AC-2**: `renderGreeting("  aLIce  ")` returns `"Hello, Alice!"`.

**AC-3**: `renderGreeting()` uses `normalizeName()` rather than duplicating normalization logic inline.
