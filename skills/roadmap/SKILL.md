---
name: roadmap
description: >-
  Domain-level planning. Analyzes scope, scores complexity per epic,
  flags oversized epics for splitting, and produces an ordered roadmap.
argument-hint: "<domain-or-area-name>"
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Specwright Roadmap: Domain-Level Planning

Analyze a domain or area, score epic complexity, recommend splits for oversized epics, and produce an ordered roadmap with dependencies.

## Arguments

- `$ARGUMENTS`: Domain or area name (e.g., "auth", "payments", "dashboard")

## Step 1: Read Configuration

Read `.specwright/config.json` for:
- `project.languages` — file patterns for codebase analysis
- `architecture.style` and `architecture.layers` — structural context
- `integration.omc` — OMC agent availability

Read `.specwright/memory/constitution.md` for principles.

## Step 2: Gather Domain Context

Analyze the domain area:

1. Use Grep/Glob to find files related to the domain
2. Read any existing CONTEXT.md files for the domain
3. Scan `.specwright/epics/` for completed epics in this area
4. Read existing roadmap if present: `.specwright/domains/{domain}/roadmap.md`

## Step 3: Delegate Scope Analysis to Architect

**Agent Delegation:**

Read `.specwright/config.json` `integration.omc` to determine delegation mode.

**If OMC is available** (`integration.omc` is true):
Use the Task tool with `subagent_type`:

    subagent_type: "oh-my-claudecode:architect"
    description: "Analyze domain scope"
    prompt: |
      Analyze the {domain} area scope for this project.

      Context:
      - Project config: {from config.json}
      - Existing code in this area: {file list and structure}
      - Completed epics: {list}
      - Constitution principles: {summary}

      Your task:
      1. Identify existing capabilities
      2. Identify gaps and missing features
      3. Propose natural next epics
      4. Map dependencies between epics
      5. Consider integration points with other areas

      For each proposed epic:
      - Epic name and short ID
      - Goal and user value
      - Required components (APIs, data changes, integrations, tests)
      - Dependencies on other epics
      - Rough scope estimate

**If OMC is NOT available** (standalone mode):
Use the Task tool with `model`:

    prompt: |
      Analyze the {domain} area scope for this project.

      Context:
      - Project config: {from config.json}
      - Existing code in this area: {file list and structure}
      - Completed epics: {list}
      - Constitution principles: {summary}

      Your task:
      1. Identify existing capabilities
      2. Identify gaps and missing features
      3. Propose natural next epics
      4. Map dependencies between epics
      5. Consider integration points with other areas

      For each proposed epic:
      - Epic name and short ID
      - Goal and user value
      - Required components (APIs, data changes, integrations, tests)
      - Dependencies on other epics
      - Rough scope estimate
    model: "opus"
    description: "Analyze domain scope"

## Step 4: Score Epic Complexity

For each proposed epic, calculate complexity:

| Component Type | Points |
|---------------|--------|
| New API endpoint (CRUD set) | 3 |
| New API endpoint (single) | 1 |
| External API integration | 5 |
| Database migration / schema change | 3 |
| Event/message system changes | 3 |
| Complex business logic | 3 |
| UI component (page) | 3 |
| UI component (widget) | 1 |
| Configuration / infrastructure | 2 |
| Test suite for new feature | 2 |

**Size Classification:**
- 1-8 points: Simple (1 session)
- 9-15 points: Medium (2 sessions)
- 16-20 points: Large (3 sessions)
- 20+ points: MUST SPLIT

## Step 5: Flag and Recommend Splits

For any epic scoring > 20 points:
1. Identify natural split boundaries
2. Suggest sub-epic breakdown
3. Ensure each sub-epic is independently shippable
4. Maintain dependency ordering after split

## Step 6: Present Roadmap

Format and present to user for confirmation:

```markdown
# {Domain} Roadmap

## Epic Summary
| Epic ID | Name | Score | Size | Dependencies |
|---------|------|-------|------|--------------|
| ... | ... | ... | ... | ... |

## Recommended Order
1. {epic} (foundation)
2. {epic} (builds on #1)

## Split Recommendations
- {epic} (XX points) -> split into A + B

Total estimated sessions: X
```

Ask user to confirm or adjust using AskUserQuestion.

## Step 7: Write Roadmap File

```bash
mkdir -p .specwright/domains/{domain}
```

Write roadmap to `.specwright/domains/{domain}/roadmap.md` with full epic details, dependency graph, and timeline.

## Step 8: Update Workflow State

Update `.specwright/state/workflow.json` with roadmap metadata:
```json
{
  "roadmap": {
    "domain": "{domain}",
    "path": ".specwright/domains/{domain}/roadmap.md",
    "epicCount": N,
    "totalComplexity": X,
    "lastUpdated": "{ISO}"
  }
}
```

## Notes

- Maintain dependency ordering throughout
- Each epic must be independently shippable
- Cross-reference constitution principles for alignment
- Consider integration points across domains
