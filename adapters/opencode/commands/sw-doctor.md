---
description: Read-only installation health check with repair hints
---

Read and follow the skill file at `.specwright/skills/sw-doctor/SKILL.md`.
Doctor should report whether runtime roots are `project-visible` under
`.specwright-local/` or `git-admin` under `.git/specwright/`, and it should
route shipped-state repairs through `/sw-status --repair {unitId}` instead of
inventing a separate repair surface.

$ARGUMENTS
