"""Eval runtime path helpers shared by capture and grading."""

import json
import os


DEFAULT_PROJECT_VISIBLE_ROOT = ".specwright-local"
CONFIG_PATH = os.path.join(".specwright", "config.json")


def load_project_visible_root(workdir: str) -> str:
    """Return the configured project-visible runtime root, or the default."""
    config_path = os.path.join(workdir, CONFIG_PATH)
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError):
        return DEFAULT_PROJECT_VISIBLE_ROOT

    runtime = config.get("git", {}).get("runtime", {})
    if not isinstance(runtime, dict):
        return DEFAULT_PROJECT_VISIBLE_ROOT

    project_visible_root = runtime.get("projectVisibleRoot")
    if not isinstance(project_visible_root, str):
        return DEFAULT_PROJECT_VISIBLE_ROOT

    project_visible_root = project_visible_root.strip()
    return project_visible_root or DEFAULT_PROJECT_VISIBLE_ROOT
