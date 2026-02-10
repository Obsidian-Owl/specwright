# Recovery Protocol

## After Context Compaction

**IMMEDIATELY execute these steps:**

### 1. Recover Current State
```
Read .specwright/state/workflow.json
```
This is the source of truth for where you are.

### 2. Load Anchor Context
```
Read .specwright/CHARTER.md      # Technology vision
Read .specwright/CONSTITUTION.md # Development practices
```

### 3. Resume Active Work

**If active work exists:**
- Read the current work unit's spec/plan documents
- Check progress markers in workflow.json
- Resume from current state

**Never:**
- Rely on conversation history
- Assume what was happening
- Restart from scratch

### 4. Skill-Specific Recovery

Each skill's documentation has a "Failure Modes" section with specific recovery notes.

Example:
- If plan exists but tasks don't → resume at task decomposition
- If tasks exist but evidence missing → re-run last gate
- If lock is stale → clear lock and resume

## Critical Rule

**Workflow state is the source of truth, not conversation history.**
