"""Eval framework setup — fixture copying, repo cloning, and baseline verification."""

import os
import shutil
import subprocess
from typing import List, Optional


def setup_fixture(fixture_path: str, workdir: str) -> None:
    """Copy the fixture directory to the working directory.

    Raises FileNotFoundError if fixture_path does not exist.
    """
    if not os.path.isdir(fixture_path):
        raise FileNotFoundError(
            f"Fixture directory not found: {fixture_path}"
        )
    shutil.copytree(fixture_path, workdir)


def setup_repo(
    repo: str,
    base_commit: str,
    workdir: str,
    install_command: Optional[str] = None,
) -> None:
    """Clone a repo, checkout a commit, and optionally run install.

    Raises subprocess.CalledProcessError (with stderr) on any failure.
    """
    _run_checked(["git", "clone", repo, workdir])
    _run_checked(["git", "checkout", base_commit], cwd=workdir)
    if install_command is not None:
        _run_checked(install_command.split(), cwd=workdir)


def _run_checked(cmd: List[str], cwd: Optional[str] = None) -> None:
    """Run a command, raising RuntimeError with stderr on failure."""
    try:
        subprocess.run(
            cmd,
            check=True,
            capture_output=True,
            text=True,
            cwd=cwd,
        )
    except subprocess.CalledProcessError as exc:
        stderr_msg = exc.stderr or str(exc)
        raise RuntimeError(stderr_msg) from exc


def verify_baseline(
    workdir: str,
    fail_to_pass: List[str],
    test_command: str,
) -> bool:
    """Run the test command and confirm tests fail (non-zero exit).

    Returns True if tests fail as expected (non-zero exit code).
    Returns False if tests unexpectedly pass (exit code 0).
    """
    result = subprocess.run(
        test_command.split(),
        cwd=workdir,
        capture_output=True,
        text=True,
    )
    return bool(result.returncode != 0)
