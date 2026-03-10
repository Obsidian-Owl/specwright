# Assumptions Protocol

## Purpose

Design assumptions are statements treated as true without verification. Untracked assumptions become risks. This protocol makes them visible, classified, and resolvable before implementation begins.

## Artifact

**File:** `.specwright/work/{id}/assumptions.md`

Produced by sw-design during the critic phase. Travels with design artifacts to sw-plan and downstream.

## Format

```markdown
# Assumptions

Status: {resolved-count}/{total-count} resolved

## Blocking

### A1: {title}
- **Category**: {technical | integration | data | behavioral | environmental}
- **Resolution**: {clarify | reference | external}
- **Status**: UNVERIFIED
- **Impact**: {what breaks if this assumption is wrong}
- **Needs**: {specific action to resolve}

## Accepted

### A2: {title}
- **Category**: ...
- **Resolution**: ...
- **Status**: ACCEPTED
- **Rationale**: {why the user accepted the risk}

## Verified

### A3: {title}
- **Category**: ...
- **Resolution**: ...
- **Status**: VERIFIED
- **Evidence**: {what confirmed it — doc link, user confirmation, code reference}
```

## Classification

**Categories** (what the assumption is about):

| Category | Description | Example |
|----------|-------------|---------|
| `technical` | How a technology works, its capabilities or limits | "Redis supports pub/sub at our expected throughput" |
| `integration` | How an external system behaves, its API contract | "The payment API returns idempotency keys" |
| `data` | Shape, volume, quality, or availability of data | "User records always have an email field" |
| `behavioral` | How users or upstream systems will interact | "Requests arrive at most 100/sec" |
| `environmental` | Infrastructure, permissions, network, deployment | "Lambda has access to the VPC subnet" |

**Resolution types** (how to resolve):

| Type | Meaning | Action required |
|------|---------|-----------------|
| `clarify` | Ambiguity the user can resolve with more detail | User answers specific questions |
| `reference` | Needs authoritative documentation | User provides API docs, schemas, interface definitions, types, or specs |
| `external` | Requires input from another team or third party | User escalates and reports back |

**Statuses:**

| Status | Meaning | Blocks design approval? |
|--------|---------|------------------------|
| `UNVERIFIED` | Not yet resolved | Yes |
| `ACCEPTED` | User acknowledges the risk, proceeds anyway | No |
| `VERIFIED` | Confirmed with evidence | No |
| `LATE-FLAGGED` | Discovered after design phase | No |

## Lifecycle

1. **Identification** -- Critic phase surfaces assumptions from the design. Research phase may also flag assumptions encountered during codebase analysis.
2. **Classification** -- Each assumption gets a category and resolution type.
3. **Presentation** -- All UNVERIFIED assumptions are presented to the user grouped by resolution type, so the user sees a clear action list:
   - "These need your clarification: ..."
   - "These need reference docs: ..."
   - "These need answers from other teams: ..."
4. **Resolution** -- User resolves each assumption by answering, providing docs, or accepting the risk.
5. **Gate** -- Design cannot be approved while BLOCK-category assumptions remain UNVERIFIED. The user may move any assumption to ACCEPTED (risk acknowledged) to unblock.

## Identification Heuristics

Flag as an assumption when the design:

- References an API, schema, or interface not verified against documentation
- Assumes a third-party service behaves a certain way without evidence
- Depends on data being in a specific format without validation
- Assumes infrastructure or permissions exist without checking
- Relies on performance characteristics not benchmarked
- Expects another team's system to support a specific interaction pattern
- Uses phrases like "should work," "probably supports," "typically returns"

## Downstream Usage

- **sw-plan** reads `assumptions.md` to ensure work unit specs don't depend on UNVERIFIED assumptions.
- **sw-verify** (gate-spec) can reference VERIFIED assumptions as supporting evidence.
- Assumptions with `external` resolution type may become dependencies in the plan.

## Late Discovery Lifecycle

Assumptions can surface after design approval — during planning or building.

### Identification

- **In sw-plan:** While writing specs, if the planner encounters an unverified
  dependency or behavioral assumption not in assumptions.md, append it with status
  `LATE-FLAGGED` and the discovery phase (`planning`).
- **In sw-build (pre-build):** Before starting the first task, scan spec.md and
  context.md for assumptions that may have become stale since planning. Quick pass.
- **In sw-build (post-task):** After each task commit, check: did the tester or
  executor encounter something that contradicts the spec?

### Format

Late assumptions use the same format as design-phase assumptions, with additions:
- **Status**: `LATE-FLAGGED`
- **Discovered**: `{phase}` (planning | building)
- **Trigger**: {what was encountered that surfaced this assumption}

### Presentation

- In sw-plan: present late assumptions at the spec approval checkpoint alongside
  the spec. User resolves: VERIFY, ACCEPT, or DEFER. Does not block by default.
- In sw-build: non-critical assumptions captured in as-built notes `## Late
  Assumptions` section. No pause.

### Criticality Rule

An assumption is critical if and only if it **directly contradicts an existing
acceptance criterion**. This is the sole trigger for pausing the build.

- Critical: pause and present to user with two options:
  (a) accept and continue, (b) invoke `/sw-pivot`
- Non-critical: capture in as-built notes. No pause.

### Transitions

`LATE-FLAGGED` transitions to:
- `VERIFIED` — evidence confirms the assumption (provide evidence link)
- `ACCEPTED` — user acknowledges the risk and proceeds
- `DEFERRED` — backlog item created, assumption parked for future resolution

### Gate Interaction

`LATE-FLAGGED` does NOT participate in the design approval gate. The gate checks
only `UNVERIFIED` status. Late assumptions bypass the design gate because they are
discovered after design approval.

### Stage Boundary Re-surfacing

Unresolved `LATE-FLAGGED` assumptions are surfaced again at the next stage boundary
(verify handoff) so they do not silently persist. The orchestrator must present any
remaining `LATE-FLAGGED` assumptions to the user before proceeding to verification.

## Size

Target: 10-30 assumptions for a complex design. Skip the artifact entirely for Quick-intensity designs. Lite-intensity designs produce assumptions inline in `context.md` rather than a separate file.
