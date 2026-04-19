# Plugin Architecture Patterns

Recurring decisions about where behavior belongs and how to structure reusable components.

Key findings: agent behavior in agent prompts not protocols (P8), consumer-agnostic protocols (P4), persistent artifacts need skill-level synthesis since agents are READ-ONLY (P10), reference documents follow a reusable template — optional, timestamped, freshness-checked (P11), config-driven strategy enums for protocol variation.

External audit lenses (P5) and existing-rule audits (P6) prevent rule bloat when extending the system.

## Related Work Units
- karpathy-alignment
- pilot-inspired-resilience
- codebase-audit
- git-operations-overhaul
