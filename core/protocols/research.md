# Research Brief Protocol

## Brief Format

```markdown
# Research Brief: {topic title}

Topic-ID: {kebab-case-id}
Created: {ISO date}
Updated: {ISO date}
Tracks: {N}

## Summary
{2-3 sentences: what was researched and key takeaways}

## Findings

### {track-name}

#### F{n}: {finding title}
- **Claim**: {factual statement — no opinions or recommendations}
- **Evidence**: {direct quote when available, otherwise summary of source material}
- **Source**: {URL}
- **Confidence**: HIGH | MEDIUM | LOW
- **Version/Date**: {version number or date of source material, when applicable}
- **Potential assumption**: {yes/no — flagged when confidence is LOW or MEDIUM}

## Conflicts & Agreements
{Where sources disagree or reinforce each other across tracks}

## Open Questions
{What could not be verified — flagged honestly, not hidden}
```

## Confidence Scoring

Confidence measures **source quality**, not design risk:

- **HIGH**: Official documentation, verified against multiple authoritative sources
- **MEDIUM**: Reputable secondary source (established blog, conference talk, book) or single official source without corroboration
- **LOW**: Single non-authoritative source, community answer, or unverified claim

## File Naming

```
{projectArtifactsRoot}/research/{topic-id}-{YYYYMMDD}.md
```

Topic ID: kebab-case, descriptive, 2-4 words (e.g., `stripe-api-webhooks`, `react-server-components`, `oauth2-pkce-flow`).

Same topic-id + date: overwrite (intentional refresh). Different date: new brief.

**Priority rule:** When multiple briefs share the same topic-id, consumers use
only the one with the most recent `Updated` date and skip older versions.

## Staleness

Briefs older than 90 days from their `Updated` date are **STALE**.

Consumers (sw-design) must warn when loading stale briefs. The brief itself is never automatically deleted — user decides.

## Size Limits

- Maximum **10 briefs** in `{projectArtifactsRoot}/research/`
- Maximum **20 findings** per brief (keep highest-confidence if more)

## Consumption by sw-design

During its research phase, sw-design checks `{projectArtifactsRoot}/research/`
for briefs relevant to the current request. Relevant findings are incorporated
into `context.md` with brief references (e.g., "per research brief
`stripe-api-webhooks-20260301`").

Stale briefs are surfaced with a warning. sw-design may suggest re-running `/sw-research` to refresh.
