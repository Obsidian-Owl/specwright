---
topic-id: impact-analysis
date: 2026-03-20
status: approved
confidence: HIGH (session logs, PR pipeline, gate calibration), MEDIUM (LLM-assisted thematic analysis), LOW (saturation norms for artifact corpora)
sources: 48 primary
---

# Specwright Impact Analysis: Data Sources, Methods, and Skill Design

## Context

Research into how to analyze Claude Code sessions, GitHub PRs, and Specwright
artifacts to understand what is working and what isn't across projects using
Specwright. Goal: design a local `sw-retro` skill for dogfooding analysis.

## Three Data Pillars

### 1. Claude Code Session Logs

**Location:** `~/.claude/projects/<encoded-path>/<session-uuid>/subagents/*.jsonl`
**Format:** JSONL, one JSON object per turn event.
**Global index:** `~/.claude/history.jsonl` (prompt text, timestamp, project path).
**Auto-deletion:** 30 days by default; set `cleanupPeriodDays` in `~/.claude/settings.json`.

**Schema (verified on filesystem, Claude Code v2.1.37):**
- `type`: "user", "assistant", "progress", "tool_result"
- `timestamp`: ISO 8601
- `sessionId`, `parentUuid`, `uuid`, `isSidechain`
- `cwd`, `version`, `gitBranch`, `agentId`, `slug`
- `message.role`, `message.model`, `message.content[]` (text, tool_use, tool_result)
- `message.usage`: `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`
- Progress events: `data.type`, `data.hookEvent`, `data.hookName`, `data.command`

**Schema is undocumented by Anthropic.** Derived from file inspection. May change across versions.

**Recommended tooling:** DuckDB for multi-file aggregation (`read_ndjson` with glob patterns). `ccusage` (npm) for token/cost aggregation. `jq` for single-file extraction.

Sources: [Simon Willison, Oct 2025](https://simonwillison.net/2025/Oct/22/claude-code-logs/), [Milvus Blog](https://milvus.io/blog/why-claude-code-feels-so-stable-a-developers-deep-dive-into-its-local-storage-design.md), [Liam ERD DuckDB analysis](https://liambx.com/blog/claude-code-log-analysis-with-duckdb), [ccusage](https://ccusage.com/), [Claude Code monitoring docs](https://code.claude.com/docs/en/monitoring-usage)

### 2. GitHub PRs (via gh CLI)

**Pipeline:** Two-phase collection required.
- Phase 1: `gh search prs --author=@me --created=">YYYY-MM-DD" --state=all --limit=100 --json number,repository,url,createdAt,state`
- Phase 2: `gh pr view NUMBER --repo OWNER/REPO --json additions,deletions,changedFiles,reviews,statusCheckRollup,commits,comments,mergedAt,createdAt,body,title,number,url,author,state`

**Limitation:** `gh search prs` lacks rich fields (additions, reviews, CI status). Must call `gh pr view` per PR. Alternative: single GraphQL query via `gh api graphql --paginate`.

**Computable metrics:**
- Cycle time: `(mergedAt - createdAt) / 3600` hours
- Change size: XS (≤10), S (≤50), M (≤200), L (≤500), XL (>500) lines changed
- Revision count: `reviews[].state == "CHANGES_REQUESTED"` count
- First review latency: `min(reviews[].submittedAt) - createdAt`
- CI pass rate: `statusCheckRollup[].conclusion`
- Specwright detection: body matches `specwright|sw-build|sw-ship` or commits contain `Co-Authored-By: Claude`

**Rate limits:** 20-50 PRs uses ~51 of 5,000 REST requests/hour. Not a constraint.

Sources: [gh search prs manual](https://cli.github.com/manual/gh_search_prs), [gh pr view manual](https://cli.github.com/manual/gh_pr_view), [GitHub GraphQL rate limits](https://docs.github.com/en/graphql/overview/rate-limits-and-query-limits-for-the-graphql-api)

### 3. Specwright Artifacts

**Gate evidence:** `.specwright/work/{id}/evidence/gates.md` — pass/fail per gate with BLOCK/WARN/INFO findings.
**Learnings:** `.specwright/learnings/{work-id}.json` — categorized findings with dispositions (promoted, tracked, dismissed).
**Gate calibration:** Embedded in learnings JSON: `gateCalibration.{gateName}.{verdict, findingCount, falsePositives, falseNegatives}`.
**Patterns:** `.specwright/patterns.md` — promoted reusable patterns with source attribution.
**Audit:** `.specwright/AUDIT.md` — systemic debt findings with severity, lifecycle tracking.
**Workflow state:** `.specwright/state/workflow.json` — task completion, gate results, work unit history.

## Analysis Methods

### Quantitative: Session Metrics

| Metric | Source | Computation |
|--------|--------|-------------|
| Token spend per session | JSONL `usage` | Sum `input_tokens + output_tokens` where `type == "assistant"` |
| Tool call distribution | JSONL `content` | Count `content[].type == "tool_use"` grouped by `name` |
| Session duration | JSONL `timestamp` | `max(timestamp) - min(timestamp)` per `sessionId` |
| Error rate | JSONL `tool_result` | Count `is_error: true` / total tool results |
| Friction: retry loops | JSONL sequence | Consecutive failed tool calls to same tool |
| Friction: high-cost idle | JSONL `usage` + `content` | High `input_tokens` with zero `tool_use` blocks |
| Friction: long gaps | JSONL `timestamp` | Inter-turn gaps > threshold (e.g., 5 min) |
| Git correlation | JSONL `gitBranch` + `timestamp` | Join to `git log` by branch + time overlap |

**DuckDB example:**
```sql
SELECT * FROM read_ndjson('~/.claude/projects/**/*.jsonl', filename=true)
```

### Quantitative: PR Metrics (SPACE Framework Dimensions)

| SPACE Dimension | Metric | PR Field |
|-----------------|--------|----------|
| Activity | PR count, commit volume | count, `commits` |
| Communication | Review response time | `reviews[].submittedAt` - `createdAt` |
| Efficiency | Cycle time | `mergedAt` - `createdAt` |
| Performance | CI pass rate, revision count | `statusCheckRollup`, `reviews` |
| Satisfaction | N/A (requires survey) | — |

Reference frameworks: DORA (deployment frequency, lead time, change failure rate, MTTR), SPACE (Forsgren et al., 2021 — measure ≥3 dimensions simultaneously).

Sources: [DORA.dev](https://dora.dev/), [SPACE framework, ACM Queue](https://queue.acm.org/detail.cfm?id=3454124), [2024 DORA Report](https://cloud.google.com/blog/products/devops-sre/announcing-the-2024-dora-report)

### Quantitative: Gate Effectiveness

**Precision/recall framing:**
- Precision = TP / (TP + FP) — "of all findings flagged, how many were real?"
- Recall = TP / (TP + FN) — "of all real issues, how many were caught?"
- OWASP Youden Index: `(TPR + Specificity) - 1` (0 = chance, negative = worse than random)

**Data source:** `gateCalibration.falsePositives` and `gateCalibration.falseNegatives` in learnings JSON. Aggregate across work units for per-gate precision/recall over time.

**Decision axes:**
- Tighten: recall low (bugs escaping past gate)
- Loosen: precision low (FP rate >2%, override frequency >1%)
- Restructure: gate mixes high-value and noisy checks

**Industry calibration references:**
- SonarQube: differential (new-code) metrics, 4 base conditions, suppresses on <20 new lines
- NIST SATE: FP rates of 3-48% across 10 SAST tools (empirical range)
- NoOps: FP rate target <2%, override frequency target <1%, decision latency <5 min

Sources: [OWASP Benchmark](https://owasp.org/www-project-benchmark/), [SonarQube Quality Gates](https://docs.sonarsource.com/sonarqube-server/10.8/instance-administration/analysis-functions/quality-gates), [NIST SATE IV](https://www.nist.gov/itl/ssd/software-quality-group/static-analysis-tool-exposition-sate-iv)

### Qualitative: Thematic Analysis (Braun & Clarke)

**6-phase process:**
1. Familiarization — read all artifacts without coding (MUST be manual)
2. Initial coding — segment-by-segment annotation (LLM-assisted viable)
3. Searching for themes — sort codes into candidate groupings
4. Reviewing themes — validate against full dataset in two passes
5. Defining and naming themes — one-paragraph interpretive definitions
6. Report production — narrative with direct evidence quotes

**LLM-assisted coding:**
- LLM codes preferred 61% of time over human for depth/clarity (single study, n=15)
- Weaknesses: latent vs. semantic balance (2.59/4), context loss on short fragments, run-to-run inconsistency
- Recommended: LLM generates initial codes anchored to line references with justification; human reviews and revises before theme generation
- Pin model version and temperature for reproducibility

**Starter codebook (4 deductive categories, empirically grounded):**
- **Quality** (Q-xx): bugs caught/missed, regressions, security issues
- **Process** (P-xx): workflow friction, bottlenecks, skipped steps, role shift
- **Value** (V-xx): time saved, complexity handled, learning, flow state
- **Risk** (R-xx): over-reliance, blind spots, false confidence, verification overhead

**Saturation estimate:** 15-20 PRs with associated artifacts for code saturation. Track new-codes-per-artifact empirically (Guest et al., 2020: base=4, run length=2-3, threshold ≤5% new info).

**Caveat:** All published saturation norms are interview-based. Artifact corpora may differ. Braun & Clarke argue saturation is a poor fit for reflexive TA.

Sources: [Braun & Clarke 2006](https://psychology.ukzn.ac.za/?mdocs-file=1176), [Toward Good Practice in TA, PMC 2022](https://pmc.ncbi.nlm.nih.gov/articles/PMC9879167/), [LLMs in TA, arxiv Oct 2025](https://arxiv.org/html/2510.18456v1), [Guest et al. 2020, PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7200005/)

## Gaps Identified

1. **No cross-project aggregation** — Specwright artifacts are per-project; no collector exists
2. **No session analytics** — rich JSONL data unused for pattern detection
3. **No PR collection pipeline** — quality signals require scripted two-phase collection
4. **No retrospective artifact** — nothing ties all three data sources into a single analysis
5. **No longitudinal view** — gate calibration data per-unit, not trended over time
6. **No thematic coding infrastructure** — qualitative data unstructured across artifacts

## Recommended Skill Design: `sw-retro`

A local skill with three phases:

1. **Collect** — Gather session logs (DuckDB), PRs (`gh` CLI), Specwright artifacts across specified project directories
2. **Analyze** — Compute quantitative metrics + LLM-assisted thematic coding
3. **Report** — Structured retrospective: metrics, theme codebook, actionable recommendations

## Existing Community Tools

| Tool | Type | Use |
|------|------|-----|
| [ccusage](https://ccusage.com/) | npm | Token/cost aggregation from session JSONL |
| [claude-code-log](https://github.com/daaain/claude-code-log) | Python/PyPI | JSONL → HTML with token breakdown |
| [claude-history](https://github.com/raine/claude-history) | Rust TUI | Fuzzy search across sessions |
| [github/issue-metrics](https://github.com/github/issue-metrics) | GitHub Action | Time-to-first-response, time-to-close |

## Published Studies on AI Tool Impact

- NAV IT longitudinal (2025): 13 developer interviews, Copilot/ChatGPT, themes: cognitive load reduction, role shift, trust friction. [arxiv 2509.20353](https://arxiv.org/html/2509.20353v2)
- 300-engineer quasi-experiment (2025): 33.8% cycle time reduction, 29.8% review time reduction. [arxiv 2509.19708](https://arxiv.org/html/2509.19708v1)
- Zoominfo enterprise (2025): 33% suggestion acceptance, domain-specificity limits. [arxiv 2501.13282](https://arxiv.org/html/2501.13282v1)
- GitHub Copilot asset/liability (JSS 2023): efficiency gains offset by verification costs. [ScienceDirect](https://www.sciencedirect.com/science/article/abs/pii/S0164121223001292)

## Open Questions

- Should the skill compare Specwright-assisted vs. non-Specwright PRs, or focus purely on Specwright work?
- What time window is most useful for recurring retrospectives? (sprint, monthly, quarterly)
- Should gate calibration adjustments be recommended automatically or only surfaced for human decision?
- How to handle projects where learnings JSON lacks `gateCalibration` data?
