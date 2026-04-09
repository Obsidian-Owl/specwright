"""Pre-scripted prompt templates for automated eval execution.

Each template embeds all interactive decisions upfront so skills
proceed without calling AskUserQuestion.
"""


def init(project_type: str = "typescript") -> str:
    """Prompt template for /sw-init."""
    return f"""Run /sw-init for this project.

Detect the project stack automatically. If asked about preferences,
use standard defaults for a {project_type} project.
Accept all suggested configurations. Do not ask clarifying questions."""


def design(problem_statement: str) -> str:
    """Prompt template for /sw-design.

    Args:
        problem_statement: The problem or feature to design a solution for.
    """
    return f"""Run /sw-design for this project.

Use Full intensity. Approve the design when ready.
Do not ask clarifying questions — treat the problem statement as complete.
Accept all assumptions as ACCEPTED (risk acknowledged).
Approve all defaults.

Problem: {problem_statement}"""


def plan() -> str:
    """Prompt template for /sw-plan."""
    return """Run /sw-plan.

Read the design artifacts from .specwright/work/.
Approve all specs. Use single-unit layout unless the design
explicitly calls for multi-unit decomposition.
Accept all suggested acceptance criteria without changes."""


def build() -> str:
    """Prompt template for /sw-build."""
    return """Run /sw-build.

Implement per the spec and plan in .specwright/work/.
Follow TDD strictly. Commit after each completed task.
Do not ask for confirmation — proceed through all tasks.

End with exactly these three lines:
Done.
Artifacts: <path to stage-report.md>
Next: /sw-verify"""


def verify(gate: str = "") -> str:
    """Prompt template for /sw-verify.

    Args:
        gate: Optional single gate name to run (e.g. "security"). Empty = all gates.
    """
    if gate:
        return f"""Run /sw-verify --gate={gate}

Run only the {gate} quality gate. Report results.
Accept all defaults."""
    return """Run /sw-verify.

Run all enabled quality gates. Report results.
Do not skip any gates. Accept all defaults."""


def ship() -> str:
    """Prompt template for /sw-ship."""
    return """Run /sw-ship.

Create a PR with evidence-mapped body. Use the default branch strategy.
Do not ask for confirmation — proceed with shipping."""


def debug(error_output: str = "") -> str:
    """Prompt template for /sw-debug."""
    if error_output:
        return f"""Run /sw-debug.

Investigate and diagnose the root cause of this error. Apply a fix.
Do not ask clarifying questions — proceed with investigation.

Error output:
{error_output}"""
    return """Run /sw-debug.

Investigate the failing tests or reported error in this project.
Diagnose the root cause and apply a fix.
Do not ask clarifying questions — proceed with investigation."""


def research(topic: str = "") -> str:
    """Prompt template for /sw-research."""
    if topic:
        return f"""Run /sw-research.

Research this topic and produce a validated research brief.
Do not ask clarifying questions.

Topic: {topic}"""
    return """Run /sw-research.

Research the topic described in the project context.
Produce a validated research brief."""


def learn() -> str:
    """Prompt template for /sw-learn."""
    return """Run /sw-learn.

Capture patterns and learnings from the current work unit.
Review build failures, gate findings, and architecture decisions.
Apply objective promotion criteria autonomously."""


def pivot(change_description: str = "") -> str:
    """Prompt template for /sw-pivot."""
    if change_description:
        return f"""Run /sw-pivot.

Apply this mid-build course correction. Revise remaining tasks.
Do not ask for confirmation.

Change: {change_description}"""
    return """Run /sw-pivot.

Review the current build state and apply course corrections
based on the most recent feedback or change request."""


def status() -> str:
    """Prompt template for /sw-status."""
    return """Run /sw-status.

Show current Specwright state — active work unit, task progress,
gate results, and lock status."""


def sync() -> str:
    """Prompt template for /sw-sync."""
    return """Run /sw-sync.

Fetch all remotes, sync the base branch, and identify stale local branches.
Do not delete any branches without confirmation."""


def guard() -> str:
    """Prompt template for /sw-guard."""
    return """Run /sw-guard.

Detect the project stack and existing guardrails.
Configure quality checks across session, commit, push, and CI layers.
Accept recommended defaults."""


def audit(scope: str = "") -> str:
    """Prompt template for /sw-audit."""
    if scope:
        return f"""Run /sw-audit.

Scope: {scope}

Analyze the codebase for architectural debt, complexity, consistency,
and accumulated issues. Produce findings in AUDIT.md."""
    return """Run /sw-audit.

Analyze the full codebase for architectural debt, complexity,
consistency, and accumulated issues. Produce findings in AUDIT.md."""
