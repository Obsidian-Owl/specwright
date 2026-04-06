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
Do not ask for confirmation — proceed through all tasks."""


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
