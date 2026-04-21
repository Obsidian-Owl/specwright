"""Helpers for running git commands inside nested test repos.

Git hooks export repository-scoped `GIT_*` variables. Nested git commands in
temporary repos must not inherit that outer context.
"""

import os
from pathlib import Path
import subprocess
from typing import Dict, Mapping, Optional

# Keep only the repo-local variables Git itself marks as local context.
_REPO_LOCAL_GIT_ENV_VARS = frozenset(
    {
        "GIT_ALTERNATE_OBJECT_DIRECTORIES",
        "GIT_COMMON_DIR",
        "GIT_CONFIG",
        "GIT_CONFIG_COUNT",
        "GIT_CONFIG_PARAMETERS",
        "GIT_DIR",
        "GIT_GRAFT_FILE",
        "GIT_IMPLICIT_WORK_TREE",
        "GIT_INDEX_FILE",
        "GIT_NAMESPACE",
        "GIT_NO_REPLACE_OBJECTS",
        "GIT_OBJECT_DIRECTORY",
        "GIT_PREFIX",
        "GIT_REPLACE_REF_BASE",
        "GIT_SHALLOW_FILE",
        "GIT_WORK_TREE",
    }
)


def sanitized_git_env(
    extra: Optional[Mapping[str, str]] = None,
    *,
    strip_from_extra: bool = True,
) -> Dict[str, str]:
    """Return an environment without inherited repo-local git context."""
    env = {
        key: value
        for key, value in os.environ.items()
        if key not in _REPO_LOCAL_GIT_ENV_VARS
    }
    if extra is not None:
        cleaned = (
            {
                key: value
                for key, value in extra.items()
                if key not in _REPO_LOCAL_GIT_ENV_VARS
            }
            if strip_from_extra
            else dict(extra)
        )
        env.update(cleaned)
    return env


def outer_git_env(repo_path: Path) -> Dict[str, str]:
    """Return the repo-local git context for a specific repository path."""
    git_dir = _git_path(repo_path, "rev-parse", "--path-format=absolute", "--git-dir")
    git_common_dir = _git_path(repo_path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return {
        "GIT_DIR": str(git_dir),
        "GIT_WORK_TREE": str(repo_path.resolve()),
        "GIT_COMMON_DIR": str(git_common_dir),
        "GIT_PREFIX": "",
    }


def _git_path(repo_path: Path, *args: str) -> Path:
    output = subprocess.run(
        ["git", *args],
        cwd=repo_path,
        check=True,
        capture_output=True,
        text=True,
        env=sanitized_git_env(),
    ).stdout.strip()
    candidate = Path(output)
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo_path / candidate).resolve()
