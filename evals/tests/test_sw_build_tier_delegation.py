"""Tests for the flattened sw-build contract in core/skills/sw-build/SKILL.md."""

import os
import re
import unittest


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SKILL_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-build", "SKILL.md")


def _load_skill():
    with open(_SKILL_PATH, "r") as f:
        return f.read()


def _extract_block(content: str, heading: str) -> str:
    match = re.search(rf"\*\*{heading}.*?(?=\n\*\*[A-Z]|\n## |\Z)", content, re.DOTALL)
    return match.group(0) if match else ""


class TestTDDCycle(unittest.TestCase):
    """Per-task flow is RED -> GREEN -> REFACTOR only."""

    def setUp(self):
        self.content = _load_skill()
        self.tdd_block = _extract_block(self.content, "TDD cycle")

    def test_red_phase_uses_tester(self):
        self.assertRegex(self.tdd_block, r"RED.*specwright-tester")

    def test_green_phase_uses_executor(self):
        self.assertRegex(self.tdd_block, r"GREEN.*specwright-executor")

    def test_refactor_phase_present(self):
        self.assertIn("REFACTOR", self.tdd_block)

    def test_tdd_block_omits_per_task_integration_phase(self):
        self.assertNotIn("INTEGRATION", self.tdd_block)
        self.assertNotIn("REGRESSION CHECK", self.tdd_block)


class TestAfterBuildPhase(unittest.TestCase):
    """Integration and regression checks moved to an end-of-unit phase."""

    def setUp(self):
        self.content = _load_skill()
        self.lower = self.content.lower()
        self.after_build = _extract_block(self.content, "After-build").lower()

    def test_after_build_block_exists(self):
        self.assertTrue(self.after_build)

    def test_after_build_mentions_post_build_review(self):
        self.assertIn("post-build review", self.after_build)

    def test_after_build_mentions_configured_test_commands(self):
        self.assertIn("commands.test", self.after_build)
        self.assertIn("commands.test:integration", self.after_build)

    def test_after_build_runs_once_per_unit(self):
        self.assertRegex(self.after_build, r"once per unit|end-of-unit")

    def test_after_build_uses_build_fixer(self):
        self.assertRegex(self.after_build, r"build-fixer")
        self.assertRegex(self.after_build, r"max 2|2 attempts")

    def test_after_build_distinguishes_interactive_and_headless(self):
        self.assertIn("interactive", self.after_build)
        self.assertIn("headless", self.after_build)


class TestRelocations(unittest.TestCase):
    """Old inline context plumbing is removed from sw-build."""

    def setUp(self):
        self.content = _load_skill()

    def test_no_repo_map_generation_block(self):
        self.assertNotIn("Repo map generation", self.content)

    def test_no_context_envelope_block(self):
        self.assertNotIn("Context envelope", self.content)

    def test_no_per_task_micro_check_block(self):
        self.assertNotIn("Per-task micro-check", self.content)

    def test_no_inner_loop_validation_block(self):
        self.assertNotIn("Inner-loop validation", self.content)


class TestDocumentIntegrity(unittest.TestCase):
    """Core operational constraints remain present."""

    def setUp(self):
        self.content = _load_skill()

    def test_stage_boundary_preserved(self):
        self.assertIn("Stage boundary", self.content)

    def test_branch_setup_preserved(self):
        self.assertIn("Branch setup", self.content)

    def test_commits_preserved(self):
        self.assertIn("Commits (LOW freedom)", self.content)

    def test_task_tracking_preserved(self):
        self.assertIn("Task tracking", self.content)

    def test_mid_build_checks_preserved(self):
        self.assertIn("Mid-build checks", self.content)

    def test_parallel_execution_preserved(self):
        self.assertIn("Parallel execution", self.content)


if __name__ == "__main__":
    unittest.main()
