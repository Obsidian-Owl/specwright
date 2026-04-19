# Specwright Charter

## What Is This Project?

Specwright is a Claude Code plugin that provides spec-driven development workflows. It ensures that AI-assisted development produces what the user actually asked for by enforcing quality gates between planning, implementation, and shipping.

## Who Uses It?

Developers who use Claude Code and want structured, verifiable AI-assisted development. They install Specwright as a plugin and use its skills (`/sw-design`, `/sw-plan`, `/sw-build`, `/sw-verify`, `/sw-ship`) to guide their workflow.

## What Problem Does It Solve?

AI coding assistants can drift from requirements, skip testing, introduce regressions, and ship code that doesn't match what was asked for. Specwright closes the loop: specs define the target, quality gates verify the result, and nothing ships without evidence of compliance.

## Architectural Invariants

These are foundational decisions. They do not change.

1. **Skills are declarative.** SKILL.md files define goals and constraints. They never contain step-by-step procedures. The AI determines how to achieve the goal within the constraints.

2. **Protocols govern fragile operations.** Git operations, state mutations, agent delegation, and evidence formatting all go through shared protocols in `protocols/`. No skill may inline these behaviors.

3. **Quality gates default to FAIL.** A gate passes only when evidence proves it should. Absence of evidence is not evidence of absence.

4. **Anchor documents drive decisions.** The Constitution (practices), Charter (vision), and Testing Strategy (approach) are the sources of truth. They are validated against, not merely referenced. Precedence: Constitution > Testing Strategy > patterns.md.

5. **Optional runtime dependencies with mandatory graceful degradation.** Enhanced features may require user-installed tools. Core workflow (design → plan → build → verify → ship) must function without any external tool beyond git. Every tool-dependent feature must degrade to a functional baseline when the tool is absent.

## Foundational Technologies

- **Claude Code plugin system** -- the distribution and execution platform.
- **Markdown** -- the primary authoring format for skills, protocols, agents, and documentation.
- **JSON** -- state management and configuration.
- **Git** -- version control with trunk-based workflow.
- **GitHub Actions** -- CI/CD for releases and validation.
