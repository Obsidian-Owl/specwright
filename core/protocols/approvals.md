# Approval Protocol

Define how Specwright records durable human approval for auditable work
artifacts.

## File Location

- Work-level approval ledger: `{workArtifactsRoot}/{workId}/approvals.md`
- Approval state travels with auditable artifacts, not runtime-only session
  state.
- `workflow.json` is never approval truth — this is a hard invariant, not guidance.

## Approval Scopes

- `design` — approves the design artifact set that `/sw-plan` consumes
- `unit-spec` — approves one unit's `spec.md` / `plan.md` / `context.md`
- `accepted-mutant` — approves one accepted-mutant lineage record for the
  live `/sw-verify --accept-mutant` flow

Use one active approval entry per design or unit-spec scope. `unit-spec`
entries also carry `unitId`. `accepted-mutant` uses one active entry per
`mutantId`.

## Approval Status Vocabulary

Only these status values are valid:

- `APPROVED`
- `STALE`
- `SUPERSEDED`

Semantics:

- `APPROVED` — a human approved the current artifact set hash for the scope
- `STALE` — the approved artifact set hash no longer matches current contents
- `SUPERSEDED` — a newer approval replaced an older approval for the same scope

## Approval Source Classification

Only these source classifications are valid:

- `command` — human-triggered lifecycle command such as `/sw-plan` or `/sw-build`
- `review-comment` — human approval captured from a PR review or issue comment
- `external-record` — human approval imported from another durable system
- `headless-check` — automation validated or reported lineage but did not approve

`headless-check` may report `STALE` or missing lineage, but it MUST NOT create
an `APPROVED` entry.

## Accepted-Mutant Lineage

Accepted mutants are not silent config waivers. The config list is only the
lookup surface for the current branch; durable approval truth lives in
`approvals.md`. The canonical config linkage is
`config.gates.tests.mutation.acceptedMutants[]`.

Each `accepted-mutant` entry is an auditable approval record tied to the mutant
lineage and carries:

- `unitId`
- `mutantId`
- `reason`
- `configPath` or equivalent config linkage
- `approvedAt`
- `expiresAt`

Default expiry is 90 days from approval. Once `expiresAt` passes, or the
underlying mutant lineage no longer matches the current artifact set, the
approval becomes `STALE` and verify must surface it again.

## Artifact Set Hashing

Approval freshness is determined by a deterministic artifact-set hash:

1. Normalize each artifact path relative to the work or unit directory.
2. Sort the artifact paths lexically.
3. Hash each artifact's contents.
4. Hash the ordered manifest of `{path, content hash}` pairs.

The resulting `artifactSetHash` is the approval fingerprint. If any approved
artifact changes or disappears, the approval becomes `STALE`.

## File Shape

`approvals.md` stays human-readable, but the machine-readable source of truth is
the fenced JSON ledger between the approval markers.

````markdown
# Approvals

Durable human approval checkpoints for this work.

<!-- approvals-ledger:start -->
```json
{
  "version": "1.0",
  "entries": [
    {
      "scope": "design",
      "unitId": null,
      "status": "APPROVED",
      "source": {
        "classification": "command",
        "ref": "/sw-plan"
      },
      "artifactSetHash": "sha256:...",
      "artifacts": ["design.md", "context.md", "decisions.md"],
      "approvedAt": "2026-04-15T00:00:00Z",
      "notes": null
    },
    {
      "scope": "accepted-mutant",
      "unitId": "01-mutation-contract-foundation",
      "mutantId": "mut-123",
      "status": "APPROVED",
      "source": {
        "classification": "command",
        "ref": "/sw-verify --accept-mutant mut-123 --reason \"equivalent defensive branch\""
      },
      "artifactSetHash": "sha256:...",
      "artifacts": ["spec.md", "plan.md", "context.md"],
      "reason": "equivalent defensive branch",
      "configPath": "gates.tests.mutation.acceptedMutants",
      "approvedAt": "2026-04-15T00:00:00Z",
      "expiresAt": "2026-07-14T00:00:00Z",
      "notes": "Accepted mutant lineage; not a silent waiver"
    }
  ]
}
```
<!-- approvals-ledger:end -->
````

## Lifecycle Responsibilities

- `sw-design` identifies the design artifact set awaiting approval. It does not
  write an `APPROVED` entry on its own.
- `sw-plan` records design approval on entry when a human triggered `/sw-plan`.
  In headless mode it must validate an existing human approval instead of
  fabricating one.
- `sw-build` records or validates `unit-spec` approval on entry using the
  current unit artifact set.
- `sw-verify` validates approval freshness before gate execution and reports
  approval lineage separately from ordinary code-quality findings.
- `sw-verify --accept-mutant {id} --reason "{prose}"` records or refreshes an
  `accepted-mutant` approval entry with config linkage and expiry (default:
  90 days from approval) instead of relying on a silent config-only waiver.

## Shared Helper Contract

Shared approval helpers must provide deterministic support for:

- artifact-set hashing
- parsing and serializing `approvals.md`
- recording a new approval entry while marking older entries for the same scope
  as `SUPERSEDED`
- recording or refreshing `accepted-mutant` entries without collapsing them
  into a silent config-only waiver
- validating approval freshness against current artifacts
- rejecting any attempt to create `APPROVED` approval state from
  `headless-check`
