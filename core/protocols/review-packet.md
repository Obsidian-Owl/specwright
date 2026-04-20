# Review Packet Protocol

Define the canonical reviewer-facing audit artifact for one work unit.

## Purpose

`review-packet.md` is the durable synthesis surface that explains:

- what the agent changed
- why the agent implemented it this way
- which approvals were in force
- where spec conformance was proven
- which gate findings still need attention

It exists so reviewers do not need raw transcripts or every gate report open at
once to understand an agent-authored change.

## File Location

- Unit-level audit artifact: `{workDir}/review-packet.md`
- The packet lives with auditable work artifacts, not in runtime-only
  `workflow.json` state.

## Required Inputs

`sw-verify` assembles the packet from existing durable artifacts:

- `{workArtifactsRoot}/{workId}/approvals.md`
- `{workDir}/implementation-rationale.md`
- `{workDir}/evidence/*.md`
- `{workDir}/evidence/spec-compliance.md`
- `{workDir}/spec.md`
- `{workArtifactsRoot}/{workId}/integration-criteria.md` when behavioral ICs
  are relevant

The packet synthesizes those sources. It does not create a second source of
truth for gate execution or approval state.

## Closeout Digest Reuse

`review-packet.md` may feed a closeout digest when a lifecycle surface needs a
human-readable summary and no fresher stage report is available. That closeout
digest is derived from the review-packet structure; it must not become a second free-form summary surface with bespoke wording that drifts from the packet.

## Canonical Structure

```markdown
# Review Packet

## Approval Lineage
{design and current unit approval status, including stale or missing lineage}

## What Changed
{changed files, blast radius, and concise reviewer-oriented diff summary}

## Why The Agent Implemented It This Way
{digest derived from implementation-rationale.md}

## Spec Conformance
{AC / IC proof summary sourced from gate-spec's compliance matrix}

## Gate Summary
{gate verdicts with evidence references}

## Remaining Attention
{WARNs, manual review items, or explicit "none"}
```

## Section Rules

### Approval Lineage

- Report both `design` and current `unit-spec` lineage when available.
- Distinguish `APPROVED`, `STALE`, `SUPERSEDED`, and missing approval clearly.
- When lineage is not current, use the compact reason vocabulary from
  `protocols/approvals.md` (`missing-entry`, `artifact-set-changed`,
  `missing-lineage`, `expired`, `superseded`) instead of dumping hashes into
  the reviewer-facing summary.
- Include the human approval source reference when present.
- Never imply approval truth comes from `workflow.json`.

### What Changed

- Summarize the implementation blast radius for reviewers.
- Focus on files, behavior, and interfaces that changed.
- Do not dump raw git diff or transcript excerpts.

### Why The Agent Implemented It This Way

- Digest the curated task entries from `implementation-rationale.md`.
- Preserve key choices, deviations, and execution path (`executor` vs
  `build-fixer`) where they matter to review.
- This section is rationale, not chat history or shell history.

### Spec Conformance

- `gate-spec` remains the canonical AC / IC proof surface.
- The packet may summarize or excerpt the matrix, but it must not replace or
  contradict gate-spec's evidence.
- Missing proof in gate-spec remains a gate problem, not something the packet
  may silently fill in.

### Gate Summary

- Summarize final gate verdicts and point to the underlying evidence files.
- Do not rerun gates or recreate gate logic here.
- Gate evidence remains the detailed source of truth.

### Remaining Attention

- Include only residual WARNs, blocked manual review items, or explicit absence
  of remaining attention.
- Do not repeat PASS-only noise in this section.

## Publication-Mode Constraint

`review-packet.md` must stay reviewer-usable in both work-artifact modes:

- `tracked`: may link directly to tracked audit artifacts and evidence files
- `clone-local`: must not depend on local-only file links for reviewer
  comprehension

When `workArtifacts.mode = clone-local`, the packet itself or the downstream PR
body must inline the approval, rationale, conformance, and attention summaries
needed by a remote reviewer.

## Non-Goals

The review packet is not:

- a transcript archive
- a second gate engine
- a replacement for per-gate evidence files
- a runtime-state mirror

## Producer / Consumer Responsibilities

- `sw-build` produces the rationale artifact that the packet digests.
- `sw-verify` assembles `review-packet.md` after gate execution.
- `sw-ship` derives the reviewer-facing PR body from `review-packet.md`,
  adapting tracked links versus clone-local inline summaries from the packet's
  publication-mode contract.
- `sw-review` uses the packet, approvals, and evidence as its primary reply
  context when the associated work is available, falling back to diff-only
  reasoning only when no work match can be resolved safely.
