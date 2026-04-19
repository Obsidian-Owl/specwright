# Research Brief: Agentic SWE Auditability

Topic-ID: agentic-swe-auditability
Created: 2026-04-15
Updated: 2026-04-15
Tracks: 5

## Summary
This brief examined current agentic software-engineering workflows, team-shared instruction surfaces, repository review controls, empirical code-review findings, and build provenance features. The sources agree that modern coding agents already operate through issues, branches, commits, pull requests, and CI, but they do not by themselves create a complete explanation chain from human-approved design intent to agent rationale to proof of conformance.

For Specwright, the relevant fact pattern is that durable auditability lives in tracked artifacts and repository-native review records, while session memory and local execution state are intentionally local or ephemeral. That makes the core research question less about storing more runtime state and more about deciding which design, rationale, validation, and approval artifacts must be durable enough to survive PR review and later investigation.

## Findings

### Agentic Execution Surface

#### F1: Current agent platforms center autonomous work on branch and pull-request workflows, not only on local chat sessions.
- **Claim**: Major agentic coding platforms describe remote or asynchronous agents as operating on branches with diffs, commits, tests, and pull requests as the durable collaboration surface.
- **Evidence**: GitHub says Copilot cloud agent can research a repository, create implementation plans, make code changes on a branch, run tests in an ephemeral environment, and let users review the diff before or during PR creation. GitHub also says that working on GitHub adds transparency because every step happens in commits and logs. Cursor’s background-agent docs describe asynchronous agents that clone a repo from GitHub, work on a separate branch, and push for handoff.
- **Source**: https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent ; https://docs.cursor.com/background-agents
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15; Cursor Docs crawled 2025-09 and accessed 2026-04-15
- **Potential assumption**: no

#### F2: Session memory and execution context are intentionally not the same thing as the durable audit trail.
- **Claim**: Current agent platforms distinguish between durable repository artifacts and machine-local or worktree-local memory/execution state.
- **Evidence**: Anthropic documents `CLAUDE.md` as team-shared project instructions via version control, but auto memory is stored per project in a machine-local directory and is explicitly “not shared across machines or cloud environments.” GitHub documents Copilot cloud agent as running in an ephemeral GitHub Actions-powered environment for each task.
- **Source**: https://code.claude.com/docs/en/memory ; https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
- **Confidence**: HIGH
- **Version/Date**: Claude Code Docs accessed 2026-04-15; GitHub Docs accessed 2026-04-15
- **Potential assumption**: no

### Instruction and Intent Surface

#### F3: Teams increasingly guide agents with version-controlled project instruction files, while local preferences are kept separate.
- **Claim**: Both Claude Code and GitHub Copilot expose a repo-scoped, version-controlled instruction layer that is distinct from personal or local settings.
- **Evidence**: Anthropic documents project `CLAUDE.md` as team-shared instructions for architecture, coding standards, build and test commands, and workflows, while local preferences belong in `CLAUDE.local.md` or user settings. GitHub documents repository custom instructions in `.github/copilot-instructions.md`, with repository instructions taking precedence over organization instructions and being read from the base branch during pull-request review.
- **Source**: https://code.claude.com/docs/en/memory ; https://docs.github.com/en/copilot/concepts/prompting/response-customization
- **Confidence**: HIGH
- **Version/Date**: Claude Code Docs accessed 2026-04-15; GitHub Docs accessed 2026-04-15
- **Potential assumption**: no

#### F4: Execution-time control surfaces exist, but they are policy and automation layers rather than design-approval records.
- **Claim**: Current agent platforms provide hooks and settings that can block, annotate, or automate agent behavior during execution.
- **Evidence**: Anthropic documents hooks that can automatically run commands and, for blocking events, deny tool calls or configuration changes. GitHub documents Copilot cloud agent hooks, custom instructions, MCP servers, custom agents, and skills as customization mechanisms for validation, logging, security scanning, and workflow automation.
- **Source**: https://code.claude.com/docs/en/hooks ; https://docs.github.com/en/copilot/concepts/agents/cloud-agent/about-cloud-agent
- **Confidence**: HIGH
- **Version/Date**: Claude Code Docs accessed 2026-04-15; GitHub Docs accessed 2026-04-15
- **Potential assumption**: no

### Review and Traceability Surface

#### F5: Repository platforms already support durable linkage among requirements, branches, pull requests, reviewers, and builds.
- **Claim**: Modern planning and repository platforms expose explicit traceability links from work items to branches, pull requests, reviewers, and build/deployment objects.
- **Evidence**: GitHub documents linked pull-request and reviewer fields in Projects, issue-to-branch and issue-to-PR linking, and pull-request templates on the default branch. Azure DevOps documents work items with fields, history, discussion, attachments, and Development/Deployment sections that support creating branches or PRs, linking to existing development and build objects, and viewing release stages and release status associated with the work item.
- **Source**: https://docs.github.com/en/enterprise-cloud@latest/issues/planning-and-tracking-with-projects/understanding-fields/about-pull-request-fields ; https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates ; https://docs.github.com/github/writing-on-github/working-with-advanced-formatting/using-keywords-in-issues-and-pull-requests ; https://learn.microsoft.com/en-us/azure/devops/cross-service/manage-requirements?tabs=agile-process&view=azure-devops
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15; Azure DevOps article last updated 2026-03-04
- **Potential assumption**: no

#### F6: Human sign-off and merge safety are enforced at branch-policy level, not inside the agent itself.
- **Claim**: Repository controls for approval and merge readiness are implemented through required reviews, stale-approval handling, code-owner approval, required status checks, and merge queues.
- **Evidence**: GitHub protected-branch documentation says required reviews can be mandated, approvals can be dismissed as stale when diffs change, code-owner approval can be required, and required status checks must pass before merge. GitHub merge-queue documentation says the queue ensures the pull request passes required checks when applied to the latest target branch and earlier queued changes.
- **Source**: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches ; https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/merging-a-pull-request-with-a-merge-queue?tool=webui
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15
- **Potential assumption**: no

### Efficient Review and Validation

#### F7: Efficient review depends on small, scoped changes and fast iteration.
- **Claim**: Peer-reviewed code-review research continues to associate efficient review with small changes, lightweight process, and quick iteration.
- **Evidence**: The Google ICSE case study found that Google’s process is lighter weight than many other contexts, with single reviewers, quick iterations, and small changes. The same study reports that change-size growth is associated in prior work with fewer useful comments and higher latency. Mozilla contributors also reported that reviewing several small patches is faster than one large merged patch.
- **Source**: https://storage.googleapis.com/gweb-research2023-stg-media/pubtools/4476.pdf ; https://plg.uwaterloo.ca/~migod/papers/2016/icse16.pdf
- **Confidence**: HIGH
- **Version/Date**: ICSE-SEIP 2018; ICSE 2016
- **Potential assumption**: no

#### F8: Review decisions and reviewer confidence depend heavily on rationale clarity, test evidence, and code-owner/reviewer fit.
- **Claim**: Review quality is affected by how clearly the change explains what it is trying to do, whether tests and test results accompany it, and whether the reviewer understands the relevant code and ownership surface.
- **Evidence**: Mozilla survey responses identified “clearly identified goal for the patch,” thorough tests, test results, simplicity/readability, and fit with the existing codebase as major factors in review decisions. The Google study reports reviewer recommendation and ownership support as important in practice, and describes static-analysis integration as a way to let reviewers focus on understandability and maintainability rather than trivial issues.
- **Source**: https://plg.uwaterloo.ca/~migod/papers/2016/icse16.pdf ; https://storage.googleapis.com/gweb-research2023-stg-media/pubtools/4476.pdf
- **Confidence**: HIGH
- **Version/Date**: ICSE 2016; ICSE-SEIP 2018
- **Potential assumption**: no

#### F9: Design or requirement detail can live outside the issue body, but it still needs a durable linked home.
- **Claim**: Work-tracking systems expect that some requirements need more detail than fits in a single work-item body and support storing or linking richer specifications elsewhere.
- **Evidence**: Azure DevOps explicitly says some requirements need more detail than a work item can hold and recommends storing and managing requirements in a repository or project wiki, then linking or attaching those specifications to the requirement. GitHub issue forms and PR templates standardize required fields, but they are templates for submission rather than a substitute for deeper linked specifications.
- **Source**: https://learn.microsoft.com/en-us/azure/devops/cross-service/manage-requirements?tabs=agile-process&view=azure-devops ; https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/about-issue-and-pull-request-templates
- **Confidence**: HIGH
- **Version/Date**: Azure DevOps article last updated 2026-03-04; GitHub Docs accessed 2026-04-15
- **Potential assumption**: no

### Release Provenance Boundaries

#### F10: Artifact attestations are appropriate for release provenance, but GitHub explicitly does not recommend them for frequent internal test builds.
- **Claim**: Build provenance and SBOM-linked attestations are a release-consumption control, not a replacement for normal PR or test evidence.
- **Evidence**: GitHub says artifact attestations create cryptographically signed provenance, can include SBOMs, and are useful for released binaries or packages that consumers will verify. The same documentation says teams should not sign frequent builds that are only for automated testing or individual source/documentation files.
- **Source**: https://docs.github.com/en/actions/concepts/security/artifact-attestations
- **Confidence**: HIGH
- **Version/Date**: GitHub Docs accessed 2026-04-15
- **Potential assumption**: no

## Conflicts & Agreements
- The sources strongly agree on one structural split: team-shared instructions belong in version-controlled project files, while personal or automatically accumulated memory is local or scoped outside the shared repository flow.
- The sources also agree that repository-native controls remain the enforcement layer for merge safety: approvals, code owners, checks, and merge queues decide what can land, not the agent alone.
- There is no direct conflict on traceability, but the sources cover different slices of it. GitHub emphasizes PR-native workflow artifacts, Azure DevOps emphasizes work-item-to-development and work-item-to-deployment linkage, and Anthropic emphasizes instruction and local memory surfaces.
- The reviewed sources do not claim that default agent logs fully explain implementation rationale. They document where instructions, memory, branches, commits, hooks, and reviews live, but they stop short of defining a canonical “why the agent chose this design” artifact.

## Open Questions
- What is the minimum durable artifact set needed to reconstruct agent rationale without overwhelming reviewers with transcript noise?
- Should approved design intent live primarily in issue/work-item fields, in linked markdown specs, or in both, when the goal is later audit rather than backlog grooming?
- Which parts of agent execution should be elevated into the PR body or linked evidence bundle, and which parts should remain transient runtime detail?
- If Specwright supports auditable work artifacts in Git, what is the right publication boundary between tracked human-approved design records and local-only execution/session state?
- How should Specwright represent approval for designs or specs in GitHub-only environments where issue templates and PR templates exist, but there is no built-in signed “spec approved” state?
