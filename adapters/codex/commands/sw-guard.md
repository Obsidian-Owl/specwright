---
description: Detect stack and configure deterministic guardrails.
---

Use the installed `specwright:sw-guard` skill for this request.
Guard should keep runtime policy explicit: prefer `project-visible`
`.specwright-local/` for interactive installs, reserve `git-admin` under
`.git/specwright/` for compatibility, and never imply same-work takeover
outside `/sw-adopt`.

$ARGUMENTS
