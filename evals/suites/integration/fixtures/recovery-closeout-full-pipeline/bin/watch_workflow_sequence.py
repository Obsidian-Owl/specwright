#!/usr/bin/env python3
"""Poll workflow.json and record distinct status/prNumber states."""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path


def _read_state(workflow_path: Path) -> str:
    data = json.loads(workflow_path.read_text(encoding="utf-8"))
    current = data.get("currentWork") or {}
    work_units = data.get("workUnits") or []
    pr_number = None
    if work_units and isinstance(work_units[0], dict):
        pr_number = work_units[0].get("prNumber")
    return (
        f"status={current.get('status')} "
        f"prNumber={pr_number if pr_number is not None else 'null'}"
    )


def main() -> int:
    if len(sys.argv) != 4:
        raise SystemExit(
            "usage: watch_workflow_sequence.py <workflow.json> <logfile> <target-pr-number>"
        )

    workflow_path = Path(sys.argv[1])
    logfile_path = Path(sys.argv[2])
    target_pr_number = sys.argv[3]

    logfile_path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.time() + 10.0
    last_state = None

    while time.time() < deadline:
        try:
            state = _read_state(workflow_path)
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            time.sleep(0.01)
            continue

        if state != last_state:
            with logfile_path.open("a", encoding="utf-8") as handle:
                handle.write(f"{state}\n")
            last_state = state

        if state == f"status=shipped prNumber={target_pr_number}":
            return 0
        time.sleep(0.01)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
