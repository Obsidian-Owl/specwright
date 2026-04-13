"""Helpers for running git commands inside nested test repos.

Git hooks export repository-scoped `GIT_*` variables. Nested git commands in
temporary repos must not inherit that outer context.
"""

import os
from typing import Dict, Optional

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
        "GIT_NO_REPLACE_OBJECTS",
        "GIT_OBJECT_DIRECTORY",
        "GIT_PREFIX",
        "GIT_REPLACE_REF_BASE",
        "GIT_SHALLOW_FILE",
        "GIT_WORK_TREE",
    }
)


def sanitized_git_env(extra: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    """Return an environment without inherited repo-local git context."""
    env = {
        key: value
        for key, value in os.environ.items()
        if key not in _REPO_LOCAL_GIT_ENV_VARS
    }
    if extra is not None:
        env.update(extra)
    return env
