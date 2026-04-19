"""Shared helpers for markdown contract tests."""

import re


def load_text(path):
    with open(path, "r", encoding="utf-8") as f:
        return f.read()


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
