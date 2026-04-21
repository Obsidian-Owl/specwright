"""Shared helpers for markdown contract tests."""

import json
import os
import re
from pathlib import Path
import subprocess


ROOT_DIR = Path(__file__).resolve().parents[2]


def load_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


def run_node_json(script: str, env: dict[str, str] | None = None) -> dict:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)

    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        cwd=ROOT_DIR,
        check=False,
        env=merged_env,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "node execution failed")
    return json.loads(result.stdout)


def assert_multiline_regex(testcase, text, pattern):
    testcase.assertIsNotNone(
        re.search(pattern, text, re.DOTALL),
        f"pattern not found: {pattern}",
    )


def assert_not_multiline_regex(testcase, text, pattern):
    testcase.assertIsNone(
        re.search(pattern, text, re.DOTALL),
        f"unexpected pattern found: {pattern}",
    )
