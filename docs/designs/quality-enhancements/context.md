# Context: Quality Enhancements

## Codebase Findings

### Files to Modify (16 files across 4 directories)

**Skills (8 files):**
- `core/skills/sw-design/SKILL.md` — Convergence loop protocol reference (R1)
- `core/skills/sw-plan/SKILL.md` — Late assumption protocol reference (R5)
- `core/skills/sw-build/SKILL.md` — Late assumption + discovered behaviors protocol refs (R5, R6)
- `core/skills/sw-verify/SKILL.md` — Escalation + calibration protocol refs (R9, R10)
- `core/skills/sw-learn/SKILL.md` — Discovered behaviors + calibration protocol refs (R6, R10)
- `core/skills/gate-tests/SKILL.md` — Mutation resistance dimension (R2)
- `core/skills/gate-spec/SKILL.md` — Discovered behaviors INFO reference (R6)
- `DESIGN.md` — Update principles/gate descriptions (all)

**Agents (3 files):**
- `core/agents/specwright-architect.md` — Convergence scoring, optimistic framing detection (R1, R4)
- `core/agents/specwright-tester.md` — Mutation construction mandate (R2, R4)
- `core/agents/specwright-reviewer.md` — Intent-vs-letter verification (R4)

**Protocols (3 existing + 1 new):**
- `core/protocols/build-quality.md` — Universal review, discovered behaviors (R3, R6)
- `core/protocols/gate-verdict.md` — Escalation heuristics, calibration data (R9, R10)
- `core/protocols/assumptions.md` — Late assumption lifecycle (R5)
- `core/protocols/convergence.md` — NEW: Critic convergence loop (R1)

### Existing Patterns

- Agent prompts already have "Behavioral discipline" sections — R4 additions go there
- The tester already has a "lazy implementation test" section — R2 formalizes this in the gate
- Post-build review already has trigger heuristic — R3 replaces it with universal + depth
- As-built notes already exist in build-quality.md — R6 extends them
- sw-learn already scans evidence files — R10 adds gate outcome recording
- gate-verdict.md already has self-critique checkpoint — R9 adds escalation

### Gotchas

- The 800-token SKILL.md target (DESIGN.md line 185) constrains how much we can add per skill
- Agent prompts don't have explicit token budgets but should stay focused
- Convergence tracking (R1) must not create infinite critic loops — needs a hard cap
- Late assumptions (R5) must not create a "stop everything" culture — need clear severity thresholds
- Gate calibration (R10) data must be lightweight — no heavy analytics infrastructure

### Blast Radius

**Changes:** 15 existing files + 1 new protocol across skills, agents, and protocols
**Does NOT change:** The 6-stage workflow, config.json schema, workflow.json schema, evidence format, directory structure, hook infrastructure, CI/CD configuration, adapter layer, CLAUDE.md, AGENTS.md
