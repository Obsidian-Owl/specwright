"""Helpers for running git commands inside nested test repos.

Git hooks export repository-scoped `GIT_*` variables. Nested git commands in
temporary repos must not inherit that outer context.
"""

import os
from typing import Dict, Optional


def sanitized_git_env(extra: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    """Return an environment without inherited git repository context."""
    env = {
        key: value
        for key, value in os.environ.items()
        if not key.startswith("GIT_")
    }
    if extra:
        env.update(extra)
    return env
