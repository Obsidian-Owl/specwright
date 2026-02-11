# Specwright v2: Design

## Vision

Specwright is a Claude Code plugin for spec-driven app development. It ensures the user gets what they asked for through quality gates that verify implementation against requirements.

**Scope:** Application development (backend, agentic systems, data pipelines). Trunk-based development workflow.

**Unique value:** The full loop -- understand deeply, plan with adversarial review, build with discipline, verify against requirements, ship cleanly. No other meta-prompting framework closes this loop.

## Principles

1. **Goals over procedures** -- Skills state what to achieve, not how to do it step by step. Claude is smart. Tell it the destination and the guardrails, not the route.

2. **Freedom calibrated to fragility** -- HIGH freedom for creative work (analysis, design, code review). LOW freedom for fragile operations (state mutations, git commands, file paths). The inverse of v1.

3. **Progressive disclosure** -- SKILL.md files stay under 600 tokens. Detail lives in protocols (loaded on demand), not inlined.

4. **Visible verification** -- Quality gates show their work. Findings, not badges. Users see problems and discuss them.

5. **Context at the right time** -- The right information available to the right agent at the right moment. Anchor documents (constitution, charter) provide persistent context. Research phase provides implementation context.

6. **Adversarial quality** -- Every plan gets challenged by a critic. Every implementation gets verified against requirements. Default stance is "prove it works," not "assume it works."

## Anchor Documents

Two persistent documents created during init, referenced throughout:

**CONSTITUTION.md** -- Development Practices
How the user wants code written. Testing standards, coding conventions, security requirements, error handling patterns. The AI MUST follow these. Validated by verify.

**CHARTER.md** -- Technology Vision
What is this repo? What are we building? Who are the consumers? Architectural invariants. The things that don't change. Referenced by plan to ensure alignment, validated by verify.

## Skills (13)

### User-Facing (8)

| Skill | Purpose | Key Innovation |
|-------|---------|----------------|
| `sw-init` | Project setup | Ask, detect, configure. Creates constitution + charter |
| `sw-plan` | Understand + design + decompose | Triage, deep research, critic review, user questions throughout |
| `sw-build` | TDD implementation | Tester → executor delegation. Context doc travels with agents |
| `sw-verify` | Interactive quality gates | Shows findings, not badges. Orchestrates gate skills in dependency order |
| `sw-ship` | Trunk-based merge | PR with evidence-mapped body |
| `sw-status` | Where am I, what's done, what's next | Supports --reset to abandon work |
| `sw-guard` | Detect stack, configure guardrails interactively | Layer-by-layer approval (session, commit, push, CI/CD) |
| `sw-learn` | Post-ship capture. What worked, what to remember | Promotes patterns to constitution |

### Internal Gate Skills (5)

Invoked by verify, not directly by users.

| Gate | Checks | Severity |
|------|--------|----------|
| `gate-build` | Build compiles, tests pass | BLOCK |
| `gate-tests` | Test quality: assertions, boundaries, mocks | BLOCK/WARN |
| `gate-security` | Secrets, injection, sensitive data | BLOCK |
| `gate-wiring` | Unused exports, orphans, layer violations | WARN |
| `gate-spec` | Every acceptance criterion has evidence | BLOCK |

### Plan Skill Phases

The plan skill handles triage internally:

1. **Triage** -- Small request (one session) → single spec. Large request → decompose first.
2. **Research** -- Deep codebase scan. Dependencies, frameworks, APIs, existing patterns. Produces a context document.
3. **Design** -- Architecture decisions. How to solve the problem.
4. **Critic** -- Adversarial review. What's wrong with this plan? What was missed? What assumptions are wrong?
5. **Decompose** -- If large, break into session-sized work units. Each gets a clear spec.
6. **User checkpoints** -- Questions flow back at every stage.

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

| Protocol | Purpose | Tokens |
|----------|---------|--------|
| `delegation.md` | Agent delegation (custom subagents + agent teams) | ~200 |
| `state.md` | Workflow state read-modify-write, lock handling | ~200 |
| `git.md` | Branch, stage, commit, push (trunk-based) | ~150 |
| `recovery.md` | Compaction recovery procedure | ~120 |
| `evidence.md` | Gate evidence format and storage | ~100 |
| `gate-verdict.md` | Self-critique, baseline check, verdict rendering | ~150 |
| `context.md` | Config/state/anchor doc loading | ~100 |
| `insights.md` | External CC insights data access | ~150 |
| `learning-lifecycle.md` | Compaction triggers, tier structure, theme format | ~150 |

Total: ~1270 tokens (loaded on demand, not all at once).

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

Target: 600 tokens per SKILL.md (40% of the 1,500 token ceiling).

## Directory Structure

```
specwright/
├── skills/           # SKILL.md files (13 skills)
│   ├── sw-init/      # User-facing
│   ├── sw-plan/
│   ├── sw-build/
│   ├── sw-verify/
│   ├── sw-ship/
│   ├── sw-guard/
│   ├── sw-status/
│   ├── sw-learn/
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
├── state/
│   └── workflow.json # Current state
└── work/             # Work unit artifacts (specs, evidence, plans)
```

## History

v2 is a clean rewrite. v1 artifacts are preserved in git history (pre-v2 commits) but not shipped with the plugin.
