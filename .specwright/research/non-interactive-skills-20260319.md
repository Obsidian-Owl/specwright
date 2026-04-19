---
topic-id: non-interactive-skills
date: 2026-03-19
status: approved
confidence: HIGH (Claude Code capabilities), HIGH (Opencode capabilities), HIGH (Specwright interactivity audit)
sources: 30+ primary across 4 research tracks
---

# Non-Interactive Specwright Skills

## Context

Specwright currently requires an interactive Claude Code or Opencode session for all operations. This research examines whether non-interactive modes are feasible, what tradeoffs they involve, and how both supported platforms enable headless operation.

## Platform Capabilities

### Claude Code Non-Interactive

| Mechanism | How | Skills Available? | Permission Model |
|-----------|-----|------------------|-----------------|
| `claude -p "prompt"` | Single-prompt, exits on completion | **No** — describe task in natural language instead | `--allowedTools` whitelist, `--permission-prompt-tool` for MCP-based decisions |
| `--dangerously-skip-permissions` | Auto-approve all tool calls | Same as `-p` | Bypasses permission prompts (except .git/.claude writes) |
| GitHub Action (`claude-code-action`) | PR/issue/cron triggers | No — prompt-based | `claude_args` passthrough |
| Hooks (PreToolUse/Stop) | Policy enforcement layer | N/A | Can auto-approve/deny per tool |

**Key limitation**: Slash commands and user-invoked skills are NOT available in `-p` mode. Must describe the task in natural language. CLAUDE.md is respected, so behavioral instructions still apply.

**Cost controls**: `--max-turns`, `--max-budget-usd`, workflow-level timeouts.

Sources: code.claude.com/docs/en/headless, code.claude.com/docs/en/cli-reference, code.claude.com/docs/en/permissions

### Opencode Non-Interactive

| Mechanism | How | Plugins Available? | Permission Model |
|-----------|-----|-------------------|-----------------|
| `opencode run "prompt"` | Single-prompt, exits on completion | UNFETCHED — not explicitly documented | Auto-**rejects** permission prompts (safe default) |
| `--dangerously-skip-permissions` / `--yolo` | Auto-approve `ask`-level prompts | Same as `run` | Respects explicit `deny` rules |
| `opencode serve` | Headless HTTP server | Yes — full plugin system | Server-side handling |
| `@opencode-ai/sdk` | Programmatic TypeScript/Go API | Yes | SDK-controlled |
| GitHub Action (`opencode github install`) | First-party PR/issue/cron | Via workflow setup | Per-workflow config |

**Key difference from Claude Code**: Opencode separates non-interactive execution (`run`) from permission bypass (`--yolo`). Combined: `opencode run --yolo "prompt"` gives full headless execution with auto-approval.

**Unique capabilities Opencode has that Claude Code doesn't**:
- Headless HTTP server (`opencode serve`) — persistent, addressable, SDK-connectable
- Official TypeScript SDK (`@opencode-ai/sdk`) with full session management
- Go SDK (`opencode-sdk-go`)
- `--format json` structured output
- Session fork (`--fork`) for branching workflows

**Key limitation**: Whether Specwright's opencode plugin (deployed to `.opencode/commands/`) fires during `opencode run` mode is UNFETCHED. This is critical — if commands don't load in `run` mode, skills aren't accessible headlessly.

Sources: opencode.ai/docs/cli, opencode.ai/docs/sdk, opencode.ai/docs/permissions, opencode.ai/docs/plugins

## Specwright Skill Interactivity Classification

| Classification | Skills | Count |
|---------------|--------|-------|
| **Fully headless** | gate-build, gate-spec, gate-tests, gate-security, gate-wiring, sw-doctor | 6 |
| **Configurable** (headless with flags) | sw-build, sw-verify, sw-ship, sw-status | 4 |
| **Interactive-required** | sw-init, sw-design, sw-plan, sw-research, sw-debug, sw-pivot, sw-guard, sw-learn, sw-audit | 9 |
| **All agents** | architect, tester, executor, reviewer, build-fixer, researcher | 6 (all headless) |

**The headless pipeline**: Once design and plan are approved interactively, the **build → verify → ship** path could run fully headless:
- sw-build: TDD cycle is mechanical. AskUserQuestion only used for build failure handling (configurable: abort/skip/auto-fix)
- sw-verify: Gates are all headless. AskUserQuestion only for freshness check and failure handling (configurable: skip/abort)
- sw-ship: AskUserQuestion only for uncommitted changes and PR creation (configurable: auto-create)

## Use Cases for Non-Interactive Specwright

### Tier 1: Already possible, just needs wiring

**Gate runner in CI** — All 5 gates are headless. A GitHub Action or Opencode workflow that runs `sw-verify` (or describes the task) on every PR would catch quality issues before human review. This is the CodeRabbit/Copilot pattern.

**Post-merge verification** — After PR merges, run gates to confirm nothing was lost in the merge. Standard CI safety net.

**Scheduled audit** — sw-audit doesn't require workflow locks. Run nightly via cron, produce AUDIT.md, open issues for findings.

### Tier 2: Needs configuration flags

**Headless build→verify→ship** — After interactive design+plan, the build pipeline runs unattended. User reviews the PR at the end (not during execution). Requires `--on-failure=abort` defaults for sw-build and sw-verify.

**Auto-review PRs** — On PR open, run gate-spec + gate-tests + gate-security and post findings as PR comments. No workflow state needed — gates are independent.

### Tier 3: Needs design work

**Event-driven issue triage** — On issue create, run sw-debug's investigation phase (read-only) and post a diagnosis comment. Requires splitting sw-debug's investigation from its fix path.

**Continuous test improvement** — On schedule, analyze test coverage gaps and open PRs with new tests. Requires a new skill or adaptation of existing tester agent.

## Tradeoffs

### What's gained
- CI/CD integration — quality gates on every PR without human initiation
- Batch processing — audits, security scans, test quality checks on schedule
- Faster feedback — findings posted before human review begins
- Reduced context switching — build→verify→ship runs while developer works on other things

### What's lost
- Ambiguity resolution — agent must infer intent, can't ask clarifying questions
- Course correction — no mid-build pivots without interactive session
- Contextual judgment — unstated constraints, organizational history not available
- Cost visibility — token usage accumulates without per-action approval

### Safety patterns (universal across shipping tools)
- Agent produces PR/diff — **never auto-merges to main**
- `--max-turns` caps iteration depth
- `--allowedTools` whitelists permitted actions
- Draft PRs as output (human merge approval required)
- Graduated autonomy: read-only → comment → PR → blocking gate

## How This Works With Our Architecture

### Claude Code adapter
Non-interactive via `-p` mode. Skills not directly accessible — must describe tasks in natural language. CLAUDE.md provides behavioral context. GitHub Action available as `anthropics/claude-code-action@v1`.

### Opencode adapter
Non-interactive via `opencode run`. Commands deployed to `.opencode/commands/` — **need to verify if these load in `run` mode** (UNFETCHED). SDK available for full programmatic control. First-party GitHub Action via `opencode github install`.

### What Specwright would need to add
1. **Headless flags** on sw-build, sw-verify, sw-ship: `--on-failure=abort`, `--skip-freshness-check`, `--auto-create-pr`
2. **Structured output mode** for gates: JSON output consumable by CI systems
3. **GitHub Action workflow template**: YAML that runs gates on PR events
4. **Documentation**: How to set up non-interactive Specwright in CI

### What Specwright should NOT add
- Non-interactive sw-design or sw-plan — these require genuine human decisions
- Auto-merge — every tool in the ecosystem uses PRs as the human checkpoint
- Daemon mode — neither platform supports it natively

## Open Questions

1. **Do opencode commands load in `opencode run` mode?** Critical — determines whether our plugin works headlessly. Needs testing.
2. **Should we ship a GitHub Action?** Or document how to use the platform-native actions with Specwright prompts?
3. **How should gate findings be formatted for PR comments?** Markdown table? Inline annotations? Collapsible sections?
4. **Cost model**: Running 5 gates on every PR at ~50-200K tokens — is this practical for Max subscription users?

## Caveats

- Claude Code has no official SDK (deprecated `@anthropic-ai/claude-code` replaced by Agent SDK which requires API key, not Max subscription)
- Opencode plugin behavior in `run` mode is UNFETCHED
- No native daemon mode on either platform
- `--dangerously-skip-permissions` should only be used in containers/VMs (Claude Code) or with explicit `deny` rules (Opencode)
- Multi-agent failure rate documented at 41-86.7% in production for specification/coordination issues

## Sources

- [Claude Code: Run programmatically](https://code.claude.com/docs/en/headless)
- [Claude Code: CLI reference](https://code.claude.com/docs/en/cli-reference)
- [Claude Code: GitHub Actions](https://code.claude.com/docs/en/github-actions)
- [Claude Code: Permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code: Hooks guide](https://code.claude.com/docs/en/hooks-guide)
- [Opencode: CLI docs](https://opencode.ai/docs/cli/)
- [Opencode: SDK docs](https://opencode.ai/docs/sdk/)
- [Opencode: Permissions](https://opencode.ai/docs/permissions/)
- [Opencode: Plugins](https://opencode.ai/docs/plugins/)
- [Opencode: GitHub integration](https://opencode.ai/docs/github/)
- [Opencode: Config](https://opencode.ai/docs/config/)
- [GitHub issue #10411: opencode run non-interactive](https://github.com/anomalyco/opencode/issues/10411)
- [GitHub issue #8463: --dangerously-skip-permissions](https://github.com/anomalyco/opencode/issues/8463)
- [CodeRabbit docs](https://docs.coderabbit.ai/)
- [GitHub Copilot Coding Agent](https://docs.github.com/en/copilot/concepts/agents/coding-agent/about-coding-agent)
- [Cursor: Scaling agents](https://cursor.com/blog/scaling-agents)
