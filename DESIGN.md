# Specwright v2: Design

## Vision

Specwright is a Claude Code plugin for spec-driven app development. It ensures the user gets what they asked for through quality gates that verify implementation against requirements.

**Scope:** Application development (backend, agentic systems, data pipelines). Configurable git workflow (trunk-based, github-flow, gitflow, custom).

**Unique value:** The full loop -- understand deeply, plan with adversarial review, build with discipline, verify against requirements, ship cleanly. No other meta-prompting framework closes this loop.

## Principles

1. **Goals over procedures** -- Skills state what to achieve, not how to do it step by step. Claude is smart. Tell it the destination and the guardrails, not the route.

2. **Freedom calibrated to fragility** -- HIGH freedom for creative work (analysis, design, code review). LOW freedom for fragile operations (state mutations, git commands, file paths). The inverse of v1.

3. **Progressive disclosure** -- SKILL.md files stay under 800 tokens. Detail lives in protocols (loaded on demand), not inlined.

4. **Visible verification** -- Quality gates show their work. Findings, not badges. Users see problems and discuss them.

5. **Context at the right time** -- The right information available to the right agent at the right moment. Anchor documents (constitution, charter) provide persistent context. Research phase provides implementation context.

6. **Adversarial quality** -- Every design gets challenged by a critic. Every implementation gets verified against requirements. Default stance is "prove it works," not "assume it works."

7. **Behavioral discipline** -- Agents follow Karpathy-aligned rules: surface confusion instead of guessing, prefer simplicity over speculation, make surgical changes, state success criteria before starting. Each agent prompt includes a tailored "Behavioral discipline" section.

## Anchor Documents

Two persistent documents created during init, referenced throughout:

**CONSTITUTION.md** -- Development Practices
How the user wants code written. Testing standards, coding conventions, security requirements, error handling patterns. The AI MUST follow these. Validated by verify.

**CHARTER.md** -- Technology Vision
What is this repo? What are we building? Who are the consumers? Architectural invariants. The things that don't change. Referenced by plan to ensure alignment, validated by verify.

## Reference Documents

**LANDSCAPE.md** -- Codebase Knowledge (optional)
Persistent cache of codebase structure: architecture, modules, conventions, integration points, gotchas. Not an anchor document — it accelerates design research but never blocks workflow. Created by sw-init (survey phase), read by sw-design (with inline refresh when stale), incrementally updated by sw-learn after shipping. Format and freshness rules in `protocols/landscape.md`.

**AUDIT.md** -- Codebase Health Findings (optional)
Persistent record of systemic issues that per-change gates miss: architecture debt, complexity growth, convention drift, accumulated workarounds. Created by sw-audit, surfaced by sw-design during research, resolved by sw-learn after shipping. Findings have stable IDs across re-runs. Resolved findings purge after 90 days. Format, matching, and freshness rules in `protocols/audit.md`.

## Skills (15)

### User-Facing (10)

| Skill | Purpose | Key Innovation |
|-------|---------|----------------|
| `sw-init` | Project setup | Ask, detect, configure. Creates constitution + charter |
| `sw-design` | Interactive solution architecture | Research, design, adversarial critic, assumption surfacing, user approval throughout |
| `sw-plan` | Decompose + spec | Per-unit specs with individual user approval. Self-contained unit directories |
| `sw-build` | TDD implementation | Tester → executor delegation. Context doc travels with agents |
| `sw-verify` | Interactive quality gates | Shows findings, not badges. Orchestrates gate skills in dependency order |
| `sw-ship` | Strategy-aware merge | PR with evidence-mapped body |
| `sw-status` | Where am I, what's done, what's next | Supports --reset to abandon work |
| `sw-guard` | Detect stack, configure guardrails interactively | Layer-by-layer approval (session, commit, push, CI/CD) |
| `sw-learn` | Post-ship capture. What worked, what to remember | Promotes patterns to constitution |
| `sw-audit` | Periodic codebase health check | Finds systemic debt gates miss. Feeds findings into design + learn |

### Internal Gate Skills (5)

Invoked by verify, not directly by users.

| Gate | Checks | Severity |
|------|--------|----------|
| `gate-build` | Build compiles, tests pass | BLOCK |
| `gate-tests` | Test quality: assertions, boundaries, mocks | BLOCK/WARN |
| `gate-security` | Secrets, injection, sensitive data | BLOCK |
| `gate-wiring` | Unused exports, orphans, layer violations | WARN |
| `gate-spec` | Every acceptance criterion has evidence | BLOCK |

### Design / Plan Split

Solution architecture and implementation planning are separate skills:

**sw-design** (interactive solution architecture):
- Research codebase and external systems. Produce `design.md` + `context.md` + `assumptions.md`.
- Conditional artifacts when warranted: `decisions.md`, `data-model.md`, `contracts.md`, `testing-strategy.md`, `infra.md`, `migrations.md`.
- Adversarial critic challenges the design and surfaces implicit assumptions before approval.
- Assumptions are classified by category (technical, integration, data, behavioral, environmental) and resolution type (clarify, reference, external). User must resolve or accept each before design approval.
- Adaptive phases: small requests skip critic, large requests get full treatment.
- Design is per-request (shared across work units). Change requests via `/sw-design <changes>`.

**sw-plan** (decomposition + per-unit specs):
- Reads design artifacts. Decomposes into work units if large.
- For multi-unit work: creates per-unit directories (`units/{unit-id}/`) each containing self-contained `spec.md`, `plan.md`, and curated `context.md`. Each unit's spec is individually reviewed and approved via `AskUserQuestion`.
- For single-unit work: writes `spec.md` and `plan.md` at the work root (flat layout, unchanged).
- Parent `context.md` (design research) is never overwritten.

### Verify Skill Gates

Configurable per project (set up in init). Each gate:
- Runs its check
- Shows detailed findings to the user
- Explains why findings matter
- Recommends actions
- User can discuss and override

The final gate is always **spec compliance**: does the implementation actually do what was asked for?

## Shared Protocols

Extracted once in `protocols/`, referenced by skills. Loaded on demand.

| Protocol | Purpose | Words (measured) |
|----------|---------|-----------------|
| `stage-boundary.md` | Stage scope, termination, handoff enforcement | ~250 |
| `delegation.md` | Agent delegation (custom subagents + agent teams) | ~410 |
| `state.md` | Workflow state, work unit queue, transition validation | ~670 |
| `git.md` | Strategy-aware branch lifecycle, commit format, PR creation | ~650 |
| `recovery.md` | Compaction recovery procedure | ~190 |
| `evidence.md` | Gate evidence format and storage | ~120 |
| `gate-verdict.md` | Self-critique, baseline check, verdict rendering | ~230 |
| `context.md` | Config/state/anchor doc loading | ~175 |
| `insights.md` | External CC insights data access | ~290 |
| `learning-lifecycle.md` | Promotion targets, auto-memory format, patterns.md maintenance | ~390 |
| `landscape.md` | Codebase reference doc format, freshness, updates | ~140 |
| `assumptions.md` | Design assumption format, classification, and lifecycle | ~620 |
| `audit.md` | Codebase health findings format, IDs, matching, lifecycle | ~125 |
| `build-quality.md` | Post-build review and as-built notes | ~230 |

Total: ~4,490 words (loaded on demand, not all at once).

## Skill Anatomy

Every SKILL.md follows this structure:

```
---
name: <skill-name>
description: <single sentence, third person>
argument-hint: "<args>"
allowed-tools: [<minimal set>]
---

# <Skill Name>

## Goal
<1-3 sentences: what this skill achieves>

## Inputs
<What the skill needs and where to find it>

## Outputs
<What exists when the skill completes successfully>

## Constraints
<Boundaries, calibrated by freedom level>
<HIGH freedom items: goals + boundaries>
<MEDIUM freedom items: guidance + heuristics>
<LOW freedom items: protocol references>

## Protocol References
<Pointers to shared protocols>

## Failure Modes
<What can go wrong and what to do>
```

Target: 800 tokens per SKILL.md (~53% of the 1,500 token ceiling).

## Directory Structure

```
specwright/
├── skills/           # SKILL.md files (15 skills)
│   ├── sw-init/      # User-facing
│   ├── sw-design/
│   ├── sw-plan/
│   ├── sw-build/
│   ├── sw-verify/
│   ├── sw-ship/
│   ├── sw-guard/
│   ├── sw-status/
│   ├── sw-learn/
│   ├── sw-audit/
│   ├── gate-build/   # Internal (invoked by verify)
│   ├── gate-tests/
│   ├── gate-security/
│   ├── gate-spec/
│   └── gate-wiring/
├── protocols/        # Shared protocols (loaded on demand)
├── agents/           # Custom subagent definitions (6 agents)
├── hooks/            # Session hooks
├── CLAUDE.md         # Project instructions
├── DESIGN.md         # This document
├── LICENSE
└── README.md
```

Runtime state (created by init):
```
.specwright/
├── config.json       # Project configuration
├── CONSTITUTION.md   # Development practices
├── CHARTER.md        # Technology vision
├── LANDSCAPE.md      # Codebase knowledge (optional)
├── AUDIT.md          # Codebase health findings (optional)
├── state/
│   └── workflow.json # Current state
└── work/             # Work unit artifacts
    └── {work-id}/
        ├── design.md       # Solution design (design-level)
        ├── context.md      # Research findings (design-level)
        ├── assumptions.md  # Design assumptions (design-level)
        ├── spec.md         # Single-unit: acceptance criteria here
        ├── plan.md         # Single-unit: task breakdown here
        └── units/          # Multi-unit: per-unit directories
            └── {unit-id}/
                ├── spec.md     # Unit-scoped acceptance criteria
                ├── plan.md     # Unit-scoped task breakdown
                ├── context.md  # Curated subset of parent context
                └── evidence/   # Gate evidence for this unit
```

## History

v2 is a clean rewrite. v1 artifacts are preserved in git history (pre-v2 commits) but not shipped with the plugin.
