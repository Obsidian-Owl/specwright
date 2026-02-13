# Delegation Protocol

## Custom Subagents

Specwright defines agents as markdown files in `agents/`. Each file has YAML frontmatter (name, description, model, tools) and a system prompt body. Claude Code loads these at **session start**. Agents added mid-session require `/agents` or a session restart to become available.

## Invocation

**Primary** (when agents are loaded):
```
Task({
  subagent_type: "{agent-name}",
  description: "Short description",
  prompt: "Full context brief with deliverable, file paths, constraints, output format"
})
```

**Fallback** (mid-session or when custom agents unavailable):
```
Task({
  subagent_type: "general-purpose",
  model: "{model from roster}",
  description: "Short description",
  prompt: "{agent system prompt from agents/{name}.md}\n\n{task-specific brief}"
})
```

When using fallback, read the agent's markdown file and include its system prompt in the task prompt. This preserves the agent's behavioral constraints.

## Context Handoff

Agents do NOT inherit the main conversation. Include in every prompt:
- The specific deliverable expected
- File paths to read (spec, plan, config, constitution)
- Relevant constraints from constitution
- Expected output format

## Context Discipline

Request structured, concise output. Every delegation prompt should end with
an output format constraint (e.g., "Return: files changed, test results,
issues found. No narrative.").

Between tasks in multi-task skills: reference committed source code by path
only (agents can Read it). Spec/plan/design content needed for the current
task should still be included inline — agents have no conversation history.

For large context documents (context.md, design.md): include only sections
relevant to the current task, not the full document.

## Agent Roster

| Agent | Model | Use for | Constraint |
|-------|-------|---------|------------|
| specwright-architect | opus | Design, review, critic | READ-ONLY |
| specwright-tester | opus | Write brutal tests, audit test quality | Adversarial mindset |
| specwright-executor | sonnet | Implementation (make tests pass) | No subagents |
| specwright-reviewer | opus | Code quality, spec compliance | READ-ONLY |
| specwright-build-fixer | sonnet | Build/test error fixes | Minimal diffs only |
| specwright-researcher | sonnet | Documentation, API research | READ-ONLY |

## Agent Teams (Experimental)

For complex parallel work, skills may use Claude Code agent teams:
- Multiple independent research tracks
- Competing design approaches evaluated in parallel
- Large codebases investigated from different angles simultaneously

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in Claude Code settings.

## Anti-Patterns

- Don't delegate simple lookups -- use Glob/Grep directly
- Don't delegate work that requires the main conversation's history
- Don't nest delegation -- agents cannot spawn other agents
- Don't delegate without all necessary context in the prompt
