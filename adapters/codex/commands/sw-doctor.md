---
description: Read-only installation health check with repair hints.
---

Use the installed `specwright:sw-doctor` skill for this request.
Doctor should report whether runtime roots are `project-visible` under
`.specwright-local/` or `git-admin` under `.git/specwright/`, and it should
route shipped-state repairs through `/sw-status --repair {unitId}` instead of
inventing a separate repair surface.

$ARGUMENTS
