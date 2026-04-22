"""Pre-scripted prompt templates for automated eval execution.

Each template embeds all interactive decisions upfront so skills
proceed without calling AskUserQuestion.
"""


def _format_instructions(instructions: str = "") -> str:
    """Render optional extra instructions for a prompt template."""
    normalized = instructions.strip()
    if not normalized:
        return ""
    return f"\n\nAdditional constraints for this eval:\n{normalized}"


def init(project_type: str = "typescript") -> str:
    """Prompt template for /sw-init."""
    return f"""Run /sw-init for this project.

Detect the project stack automatically. If asked about preferences,
use standard defaults for a {project_type} project.
Accept all suggested configurations. Do not ask clarifying questions."""


def design(problem_statement: str, instructions: str = "") -> str:
    """Prompt template for /sw-design.

    Args:
        problem_statement: The problem or feature to design a solution for.
        instructions: Optional extra constraints for this eval run.
    """
    return f"""Run /sw-design for this project.

Use Full intensity. Approve the design when ready.
Do not ask clarifying questions — treat the problem statement as complete.
Accept all assumptions as ACCEPTED (risk acknowledged).
Approve all defaults.
Write the stage report before the terminal handoff.
The stage report must begin with `Attention required:` and stay concise.{_format_instructions(instructions)}

End with exactly these three lines:
Done. <one-line outcome>.
Artifacts: <path to stage-report.md>
Next: /sw-plan

Problem: {problem_statement}"""


def plan(instructions: str = "") -> str:
    """Prompt template for /sw-plan."""
    return """Run /sw-plan.

Read the design artifacts from the selected work directory.
Approve all specs. Use single-unit layout unless the design
explicitly calls for multi-unit decomposition.
Accept all suggested acceptance criteria without changes.
Write the stage report before the terminal handoff.
The stage report must begin with `Attention required:` and stay concise.""" + _format_instructions(instructions) + """

End with exactly these three lines:
Done. <one-line outcome>.
Artifacts: <path to stage-report.md>
Next: /sw-build"""


def build(instructions: str = "") -> str:
    """Prompt template for /sw-build."""
    return """Run /sw-build.

Implement per the spec and plan in the selected work directory.
Follow TDD strictly. Commit after each completed task.
If branch-head freshness blocks entry and reconcile is rebase or merge, recover
in the same stage. If policy is manual, treat it as explicit fallback:
reconcile the current branch against the recorded target in the owning
worktree, then rerun /sw-build. Do not rewrite target metadata to bypass the
block.
Do not ask for confirmation — proceed through all tasks.
Write the stage report before the terminal handoff.
The stage report must begin with `Attention required:` and stay concise.""" + _format_instructions(instructions) + """

End with exactly these three lines:
Done. <one-line outcome>.
Artifacts: <path to stage-report.md>
Next: /sw-verify"""


def verify(gate: str = "", instructions: str = "") -> str:
    """Prompt template for /sw-verify.

    Args:
        gate: Optional single gate name to run (e.g. "security"). Empty = all gates.
        instructions: Optional extra constraints for this eval run.
    """
    if gate:
        return f"""Run /sw-verify --gate={gate}

Run only the {gate} quality gate. Report results.
If branch-head freshness blocks entry and reconcile is rebase or merge, recover
in the same verify run. If policy is manual, treat it as explicit fallback:
reconcile the current branch against the recorded target in the owning
worktree, then rerun /sw-verify. Do not go back to /sw-build solely to clear
freshness.
Accept all defaults.
Write the stage report before the terminal handoff.
The stage report must begin with `Attention required:` and stay concise.{_format_instructions(instructions)}

End with exactly these three lines:
Done. <one-line outcome>.
Artifacts: <path to stage-report.md>
Next: /sw-build or /sw-ship"""
    return """Run /sw-verify.

Run all enabled quality gates. Report results.
If branch-head freshness blocks entry and reconcile is rebase or merge, recover
in the same verify run. If policy is manual, treat it as explicit fallback:
reconcile the current branch against the recorded target in the owning
worktree, then rerun /sw-verify. Do not go back to /sw-build solely to clear
freshness.
Do not skip any gates. Accept all defaults.
Write the stage report before the terminal handoff.
The stage report must begin with `Attention required:` and stay concise.""" + _format_instructions(instructions) + """

End with exactly these three lines:
Done. <one-line outcome>.
Artifacts: <path to stage-report.md>
Next: /sw-build or /sw-ship"""


def ship() -> str:
    """Prompt template for /sw-ship."""
    return """Run /sw-ship.

This is a constrained non-interactive ship eval. Execute only the ship flow.
Do not reopen `core/skills/sw-ship/SKILL.md` unless execution is blocked.
Read only the selected workflow state, `.specwright/config.json`,
`{workDir}/spec.md`, `{workDir}/plan.md`, and `{workDir}/evidence/`.
If shipping freshness blocks and reconcile is rebase or merge, recover in the
same run. If policy is manual, STOP and report that this is explicit fallback:
the operator must reconcile the current branch against the recorded target in
the owning worktree, then rerun /sw-verify followed by /sw-ship in a separate
invocation.
If pre-flight passes, set status to `shipping`, run exactly one
`gh pr create`, then on success write `prNumber`, keep `prMergedAt` null,
set status to `shipped`, and write `{workDir}/stage-report.md`.
If push, PR creation, or the `prNumber` write fails, revert to `verifying`
and keep `prNumber` null.
Do not ask for confirmation — proceed with shipping.
Assume PATH-provided CLI shims behave like their stock tools.
Use the documented `gh` command path directly.
Do not inspect unrelated files or audit the shim environment.
Avoid intermediate narration. Execute the ship flow and only emit the final handoff.
Write the stage report before the terminal handoff.
The stage report must begin with `Attention required:` and stay concise.

End with exactly these three lines:
Done. <one-line outcome>.
Artifacts: <path to stage-report.md>
Next: /sw-build"""


def doctor() -> str:
    """Prompt template for /sw-doctor."""
    return """Run /sw-doctor.

This is a constrained non-interactive doctor eval. Execute only the
STATE_DRIFT detection and backfill path.
Do not reopen `core/skills/sw-doctor/SKILL.md` unless execution is blocked.
Inspect the selected workflow state for shipped units with `prNumber=null`.
For each candidate, attempt one-time backfill in this order: `gh search prs` /
`gh pr list`, then git merge history, else report STATE_DRIFT with the exact
remediation command `sw-status --repair {unitId}`.
If `gh` proves a merged PR, persist the backfill immediately in
`workflow.json`. This eval expects the safe/provable mutation path, not a
report-only summary.
Never modify `status`; only `prNumber` and `prMergedAt` may change.
Assume PATH-provided CLI shims behave like their stock tools.
Do not inspect unrelated files or audit the shim environment.
Avoid intermediate narration. Execute the doctor flow and print the final result only."""


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

Apply research-backed rebaselining for work in planning, building, or verifying.
Preserve completed scope and shipped scope while revising design, plan, and
in-progress work.
If the requested change would rewrite shipped scope, discard history, or needs
a brand-new direction, use /sw-design instead.
Do not invent a new command or extra confirmation.

Change: {change_description}"""
    return """Run /sw-pivot.

Review the current work in planning, building, or verifying and apply
research-backed rebaselining. Preserve completed scope and shipped scope while
revising design, plan, and in-progress work.
If the requested change would rewrite shipped scope, discard history, or needs
a brand-new direction, use /sw-design instead.
Do not invent a new command or extra confirmation."""


def status(repair_unit_id: str = "", headless: bool = False) -> str:
    """Prompt template for /sw-status."""
    if repair_unit_id:
        prompt = f"""Run /sw-status --repair {repair_unit_id}.

Inspect the target unit and follow the documented repair flow."""
        if headless:
            prompt += """

Treat this as a non-interactive run. If AskUserQuestion would be required,
stay report-only and explain the next interactive step."""
        else:
            prompt += """

If interaction is available, continue through the documented repair options
without asking clarifying questions."""
        return prompt

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
