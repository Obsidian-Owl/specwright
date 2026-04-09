"""Eval framework setup — fixture copying, repo cloning, and eval bootstrap helpers."""

import os
import shlex
import shutil
import subprocess
from typing import Callable, List, Optional, Set


_REPO_OVERLAY_IGNORES = {
    ".git",
    ".env",
    ".DS_Store",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".venv",
    "venv",
    "node_modules",
    "dist",
    "build",
    "coverage",
}
_REPO_OVERLAY_RELATIVE_IGNORES = {
    os.path.join("evals", "results"),
    os.path.join(".specwright", "state"),
    os.path.join(".specwright", "work"),
}


def setup_fixture(fixture_path: str, workdir: str) -> None:
    """Copy the fixture directory to the working directory.

    Raises FileNotFoundError if fixture_path does not exist.
    """
    if not os.path.isdir(fixture_path):
        raise FileNotFoundError(
            f"Fixture directory not found: {fixture_path}"
        )
    shutil.copytree(fixture_path, workdir)


def setup_repo_overlay_fixture(
    repo_root: str,
    fixture_path: str,
    workdir: str,
) -> None:
    """Copy repo_root into workdir, then overlay fixture contents on top."""
    if not os.path.isdir(repo_root):
        raise FileNotFoundError(f"Repository root not found: {repo_root}")
    if not os.path.isdir(fixture_path):
        raise FileNotFoundError(
            f"Fixture directory not found: {fixture_path}"
        )
    shutil.copytree(repo_root, workdir, ignore=_repo_overlay_ignore(repo_root))
    shutil.copytree(fixture_path, workdir, dirs_exist_ok=True)


def init_git_repo(workdir: str, default_branch: str = "main") -> None:
    """Initialize a disposable git repo with one initial commit."""
    _run_checked(["git", "init", "-b", default_branch], cwd=workdir)
    _run_checked(["git", "config", "user.name", "Specwright Eval"], cwd=workdir)
    _run_checked(
        ["git", "config", "user.email", "specwright-evals@example.com"],
        cwd=workdir,
    )
    _run_checked(["git", "add", "."], cwd=workdir)
    _run_checked(["git", "commit", "-m", "chore(eval): seed fixture"], cwd=workdir)


def run_setup_commands(workdir: str, commands: List[str]) -> None:
    """Run shell-split setup commands in workdir."""
    for command in commands:
        _run_checked(shlex.split(command), cwd=workdir)


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
        _run_checked(shlex.split(install_command), cwd=workdir)


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


def _repo_overlay_ignore(repo_root: str) -> Callable[[str, List[str]], Set[str]]:
    """Return an ignore callable for copying the current repo into eval fixtures."""
    repo_root_abs = os.path.abspath(repo_root)

    def ignore(current_dir: str, names: List[str]) -> Set[str]:
        rel_dir = os.path.relpath(os.path.abspath(current_dir), repo_root_abs)
        if rel_dir == ".":
            rel_dir = ""

        ignored: Set[str] = set()
        for name in names:
            rel_path = os.path.normpath(os.path.join(rel_dir, name))
            if name in _REPO_OVERLAY_IGNORES:
                ignored.add(name)
                continue
            if rel_path in _REPO_OVERLAY_RELATIVE_IGNORES:
                ignored.add(name)
        return ignored

    return ignore


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
        shlex.split(test_command),
        cwd=workdir,
        capture_output=True,
        text=True,
    )
    return bool(result.returncode != 0)
