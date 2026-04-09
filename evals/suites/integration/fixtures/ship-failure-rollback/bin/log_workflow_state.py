#!/usr/bin/env python3
"""Append the current workflow status/prNumber tuple to a log file."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        raise SystemExit("usage: log_workflow_state.py <workflow.json> <logfile>")

    workflow_path = Path(sys.argv[1])
    logfile_path = Path(sys.argv[2])

    data = json.loads(workflow_path.read_text(encoding="utf-8"))
    current = data.get("currentWork") or {}
    work_units = data.get("workUnits") or []
    pr_number = None
    if work_units and isinstance(work_units[0], dict):
        pr_number = work_units[0].get("prNumber")

    logfile_path.parent.mkdir(parents=True, exist_ok=True)
    with logfile_path.open("a", encoding="utf-8") as handle:
        handle.write(
            f"status={current.get('status')} "
            f"prNumber={pr_number if pr_number is not None else 'null'}\n"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
