"""Prompt hook coverage for the constrained recovery closeout chain."""

import unittest

from evals.framework.prompts import build, design, plan, verify


class TestRecoveryCloseoutPromptOverrides(unittest.TestCase):
    def test_design_includes_optional_instructions(self):
        result = design("Implement add(a, b)", instructions="Keep this single-unit.")
        self.assertIn("Keep this single-unit.", result)

    def test_plan_includes_optional_instructions(self):
        result = plan(instructions="Do not create workUnits.")
        self.assertIn("Do not create workUnits.", result)

    def test_build_includes_optional_instructions(self):
        result = build(instructions="Keep the build to one task.")
        self.assertIn("Keep the build to one task.", result)

    def test_verify_includes_optional_instructions(self):
        result = verify(instructions="Do not require optional artifacts.")
        self.assertIn("Do not require optional artifacts.", result)


if __name__ == "__main__":
    unittest.main()
