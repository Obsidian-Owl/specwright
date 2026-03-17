"""Eval framework capture — state snapshots and timing data."""

import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional


def capture_snapshot(workdir: str, output_dir: str) -> Dict[str, Any]:
    """Snapshot .specwright/ state, git status, and file tree.

    If .specwright/ does not exist, returns a manifest with workflow_state=None,
    empty artifacts list, and an error note.
    """
    specwright_dir = os.path.join(workdir, ".specwright")
    timestamp = datetime.now(timezone.utc).isoformat()

    if not os.path.isdir(specwright_dir):
        return {
            "workflow_state": None,
            "artifacts": [],
            "git_status": _get_git_status(workdir),
            "timestamp": timestamp,
            "error": ".specwright/ directory not found",
        }

    # Copy .specwright/ to output
    dest = os.path.join(output_dir, ".specwright")
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(specwright_dir, dest)

    # Parse workflow.json
    workflow_state = _read_workflow_state(specwright_dir)

    # List artifacts
    artifacts = _list_artifacts(specwright_dir)

    return {
        "workflow_state": workflow_state,
        "artifacts": artifacts,
        "git_status": _get_git_status(workdir),
        "timestamp": timestamp,
    }


def capture_timing(run_result: Any, output_dir: str) -> None:
    """Write timing.json from a RunResult."""
    timing = {
        "tokens": run_result.tokens,
        "duration_ms": run_result.duration_ms,
        "exit_code": run_result.exit_code,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    path = os.path.join(output_dir, "timing.json")
    with open(path, "w") as f:
        json.dump(timing, f, indent=2)


def _read_workflow_state(specwright_dir: str) -> Optional[Dict]:
    """Read and parse workflow.json, or return None on error."""
    workflow_path = os.path.join(specwright_dir, "state", "workflow.json")
    try:
        with open(workflow_path) as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return None


def _list_artifacts(specwright_dir: str) -> List[str]:
    """List file paths under .specwright/work/."""
    work_dir = os.path.join(specwright_dir, "work")
    if not os.path.isdir(work_dir):
        return []
    artifacts = []
    for root, _dirs, files in os.walk(work_dir):
        for name in files:
            rel_path = os.path.relpath(os.path.join(root, name), specwright_dir)
            artifacts.append(rel_path)
    return sorted(artifacts)


def _get_git_status(workdir: str) -> str:
    """Get git status --porcelain output, or empty string on error."""
    try:
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=workdir,
            capture_output=True,
            text=True,
        )
        return result.stdout
    except (FileNotFoundError, subprocess.SubprocessError):
        return ""
