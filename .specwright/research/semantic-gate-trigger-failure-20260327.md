# Research Brief: Semantic Gate Not Triggering During Verify

**Date:** 2026-03-27
**Confidence:** HIGH (direct code analysis + session log evidence + artifact inspection)
**Tracks:** Skill analysis, Protocol analysis, Session retro, Cross-project config audit

---

## Executive Summary

The semantic gate is configured and enabled across 5 of 6 Specwright projects but
has only produced evidence files in **3 out of 30+ total work units** (across 2
projects). The root cause is a combination of three factors:

1. **Ambiguous "disabled by default" language** in the verify skill (v0.20.0–v0.21.0)
2. **Config schema inconsistency** between `gates.enabled` (array) and `gates.{name}.enabled` (object)
3. **LLM execution drift** — the verify skill executor interprets "disabled by default" as a signal to skip

---

## Track 1: Verify Skill Analysis

### Finding 1.1 — "Disabled by default" language (HIGH confidence)

The v0.20.0 and v0.21.0 verify skills contained this text:

```
Note: `gate-semantic` is disabled by default and must be explicitly enabled.
```

This was present in the **Gate execution order** constraint at LOW freedom level.
The current v0.23.0 skill has **removed this language** — the gate execution order
now reads:

```
Execute in dependency order: gate-build → gate-tests → gate-security, gate-wiring →
gate-semantic → gate-spec. Skip gates not in `gates.enabled`.
```

**Impact:** Projects using cached versions (0.20.0, 0.21.0) still have the
"disabled by default" text, which biases the LLM toward skipping the gate even
when config says `enabled: true`. The phrase "must be explicitly enabled" is
ambiguous — does `gates.semantic.enabled: true` count as "explicitly enabled"?
The LLM frequently decides it doesn't.

### Finding 1.2 — `gates.enabled` reference is ambiguous (HIGH confidence)

The verify skill references `config.json` `gates.enabled` list. But the actual
config schema across projects uses **two incompatible formats**:

**Format A (object-per-gate):**
```json
"gates": {
  "semantic": { "enabled": true },
  "build": { "enabled": true }
}
```
Used by: specwright, financial-fusion, proof, proof-design-canvas

**Format B (array):**
```json
"gates": {
  "enabled": ["build", "tests", "security", "wiring", "spec", "semantic"]
}
```
Used by: financialfusion-enc, floe

The skill says "Skip gates not in `gates.enabled`". With Format A, there is no
`gates.enabled` — the LLM must infer that `gates.semantic.enabled: true` means
semantic is enabled. With Format B, `gates.enabled` is a literal array to check.

**Observation:** financialfusion-enc (Format B) is the project with the MOST
semantic gate evidence files. This correlates with the array format being
unambiguous.

### Finding 1.3 — No gate registry or dispatch map (MEDIUM confidence)

Gates are discovered by convention (`skills/gate-{name}/SKILL.md`) but there is
no explicit registry mapping config keys to gate skill files. The verify skill
executor must infer the connection: `gates.semantic` config → `gate-semantic`
skill. This indirection is another opportunity for the LLM to lose track.

---

## Track 2: Gate-Semantic Skill Analysis

### Finding 2.1 — Gate itself has no skip conditions (HIGH confidence)

The gate-semantic skill has **zero conditions that would prevent execution** once
invoked. It gracefully degrades:
- No ast-grep → Tier 0 only (still runs)
- No OpenGrep → resource-lifecycle skipped (still runs other categories)
- No changed files → returns PASS (still runs, just no findings)
- No code files → returns PASS

**Conclusion:** The problem is NOT in the gate-semantic skill itself. It's in the
verify skill's decision to invoke it.

### Finding 2.2 — Evidence file naming is consistent (HIGH confidence)

Where the gate DID execute, evidence files are named `gate-semantic.md` (matching
the standard gate evidence pattern). The absence of this file in work units
confirms the gate was never invoked, not that it ran and produced nothing.

---

## Track 3: Session Log Retro

### Finding 3.1 — Zero semantic gate text in assistant responses (HIGH confidence)

Searched the 15 most recent sessions across specwright, financial-fusion,
proof, and proof-design-canvas. **Zero assistant messages** contained text
matching "gate-semantic", "semantic gate", or "semantic-report" patterns.

The only projects with semantic activity in sessions were:
- specwright (development sessions — building the gate, not using it)
- financialfusion-enc (1 verify session with actual gate execution)

### Finding 3.2 — Gate reference counts tell the story (HIGH confidence)

In sessions where verify DID run, gate-semantic reference counts were
proportionally low or absent:

| Project | Session | build refs | tests refs | security refs | semantic refs |
|---------|---------|-----------|-----------|--------------|--------------|
| financialfusion-enc | 00c4a355 | 3 | 3 | 4 | 5 |
| specwright | 7f32e8b1 | 150 | 169 | 651 | 1624* |

*specwright session 7f32e8b1 was a development session (building the gate skill itself).

---

## Track 4: Cross-Project Config Audit

### Finding 4.1 — Semantic gate enabled in 5/6 projects (HIGH confidence)

| Project | Semantic Enabled | Config Format | Evidence Files | Evidence Exists? |
|---------|-----------------|---------------|---------------|-----------------|
| specwright | true | Object | 0 | NO |
| financial-fusion | true | Object | 0 | NO |
| financialfusion-enc | true | Array | 2 | YES |
| proof | true | Object | 1 | YES |
| proof-design-canvas | true | Object | 0 | NO |
| floe | **false** | Array | 0 | N/A (correctly skipped) |

### Finding 4.2 — Array format correlates with execution (MEDIUM confidence)

financialfusion-enc (array format with "semantic" in list) has the most evidence.
proof (object format) has 1 evidence file — but that work unit ("benchmark-script-resilience")
may have been built after the v0.23.0 update which removed the "disabled by default" language.

---

## Root Cause Analysis

**Primary cause:** The verify skill executor (the LLM) is not reliably invoking
gate-semantic during its gate execution loop. Contributing factors:

1. **v0.20.0–v0.21.0 "disabled by default" language** — Still cached in some
   project environments. Even though config says enabled, the skill text biases
   the LLM toward skipping.

2. **Config format ambiguity** — `gates.enabled` (array) vs `gates.{name}.enabled`
   (object) is not normalized. The verify skill references `gates.enabled` which
   only exists in array format.

3. **Gate ordering and context pressure** — Semantic is 5th of 6 gates. By the time
   verify reaches it, significant context has been consumed by build, tests,
   security, and wiring gate execution. The LLM may deprioritize or skip the
   remaining gates under context pressure.

4. **No enforcement mechanism** — The verify skill relies on the LLM faithfully
   executing all gates in order. There is no checklist, no state tracking of
   which gates have been executed, and no validation that all enabled gates
   produced evidence files.

---

## Recommendations

### R1: Normalize config gate enablement (HIGH priority)

Add explicit guidance to the verify skill about BOTH config formats:
```
Enabled gate detection: For each gate in the dependency order, check:
- Array format: gate name exists in `config.gates.enabled` array
- Object format: `config.gates[gateName].enabled === true`
Either format means the gate should be executed.
```

### R2: Remove "disabled by default" language (DONE in v0.23.0)

Already addressed in the current version. Ensure cached versions are updated
across all project environments.

### R3: Add gate execution tracking to verify (HIGH priority)

Before starting gate execution, build an explicit checklist:
```
Gates to execute: [build, tests, security, wiring, semantic, spec]
```
After each gate, log completion. After all gates, verify every enabled gate
has an evidence file. Missing evidence = ERROR.

### R4: Consider protocol-level enforcement (MEDIUM priority)

Add a post-gate validation step to the verify skill or a protocol that:
1. Reads config to determine enabled gates
2. Checks `{workDir}/evidence/` for corresponding evidence files
3. Reports any gaps as ERROR findings in the aggregate report

### R5: Clear cached plugin versions (IMMEDIATE)

Projects using cached specwright versions (0.20.0, 0.21.0) will continue to
see the old "disabled by default" language. Force cache refresh.

---

## Open Questions

1. Why did proof's benchmark-script-resilience work unit get semantic evidence
   when other proof work units didn't? Was it a different specwright version?
2. Is context window pressure during verify a measurable factor? Could gate
   delegation to subagents help?
3. Should the config schema be formally specified and validated by sw-doctor?

---

## Sources

- `core/skills/sw-verify/SKILL.md` (current v0.23.0)
- `cache/specwright/0.21.0/skills/sw-verify/SKILL.md` (v0.21.0 with "disabled by default")
- `cache/specwright/0.20.0/skills/sw-verify/SKILL.md` (v0.20.0 with same language)
- `core/skills/gate-semantic/SKILL.md` (current)
- Session logs: 6 projects, 57+ sessions searched
- Evidence directories: 6 projects, 30+ work units inspected
- Config files: 6 projects audited
