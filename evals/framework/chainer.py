"""Eval framework chainer — sequential skill execution with state capture."""

import os
import tempfile
from dataclasses import dataclass, field
from typing import Dict, List, Optional

from evals.framework.capture import capture_snapshot
from evals.framework.runner import RunResult, ToolRunner


@dataclass
class ChainResult:
    """Result of a sequential skill chain execution."""
    steps: List[RunResult] = field(default_factory=list)
    snapshots: List[Dict] = field(default_factory=list)
    snapshot_dirs: List[str] = field(default_factory=list)
    failed_at: Optional[str] = None


def run_sequence(
    runner: ToolRunner,
    skills: List[str],
    prompts: Dict[str, str],
    workdir: str,
    timeout_per_skill: int = 300,
    capture_between: bool = True,
    snapshot_base_dir: Optional[str] = None,
    plugin_dir: Optional[str] = None,
) -> ChainResult:
    """Invoke skills sequentially in the same working directory.

    After each skill, captures a state snapshot if capture_between=True.
    Stops the chain if a skill returns non-zero exit code.

    Args:
        snapshot_base_dir: Parent directory for snapshots. If None, uses
            tempfile.mkdtemp(). Callers control cleanup via snapshot_dirs.
        plugin_dir: Optional path to plugin directory, forwarded to runner.
    """
    result = ChainResult()

    for skill_name in skills:
        prompt = prompts.get(skill_name, "")
        run_result = runner.run_skill(
            skill=skill_name,
            prompt=prompt,
            workdir=workdir,
            timeout=timeout_per_skill,
            plugin_dir=plugin_dir,
        )
        result.steps.append(run_result)

        if capture_between:
            if snapshot_base_dir:
                snapshot_dir = os.path.join(snapshot_base_dir, f"snapshot-{skill_name}")
                os.makedirs(snapshot_dir, exist_ok=True)
            else:
                snapshot_dir = tempfile.mkdtemp(prefix=f"snapshot-{skill_name}-")
            result.snapshot_dirs.append(snapshot_dir)
            snapshot = capture_snapshot(workdir, snapshot_dir)
            result.snapshots.append(snapshot)

        if run_result.exit_code != 0:
            result.failed_at = skill_name
            break

    return result
