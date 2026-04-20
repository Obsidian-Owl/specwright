"""Regression tests for Unit 01 — pivot rebaselining foundation."""

from pathlib import Path
import re
import unittest


ROOT_DIR = Path(__file__).resolve().parents[2]
PIVOT_SKILL = ROOT_DIR / "core" / "skills" / "sw-pivot" / "SKILL.md"
STATE_PROTOCOL = ROOT_DIR / "core" / "protocols" / "state.md"


class TestPivotRebaseliningContract(unittest.TestCase):
    """Task 1 RED: sw-pivot must stop describing the narrow build-only contract."""

    def setUp(self):
        self.pivot_text = PIVOT_SKILL.read_text(encoding="utf-8")
        self.state_text = STATE_PROTOCOL.read_text(encoding="utf-8")

    def test_goal_reframes_pivot_as_research_backed_rebaselining(self):
        self.assertRegex(
            self.pivot_text,
            re.compile(
                r"research[- ]backed[\s\S]*rebaselin|rebaselin[\s\S]*research[- ]backed",
                re.IGNORECASE,
            ),
        )

    def test_skill_declares_task_unit_and_work_pivot_classes(self):
        for pivot_class in ("task-pivot", "unit-pivot", "work-pivot"):
            with self.subTest(pivot_class=pivot_class):
                self.assertIn(pivot_class, self.pivot_text)

    def test_precondition_accepts_planning_building_and_verifying(self):
        self.assertRegex(
            self.pivot_text,
            re.compile(
                r"planning[\s\S]*building[\s\S]*verifying|verifying[\s\S]*planning[\s\S]*building",
                re.IGNORECASE,
            ),
        )

    def test_failure_modes_no_longer_claim_building_only(self):
        self.assertNotRegex(
            self.pivot_text,
            re.compile(r"Status not `?building`?|only valid during active sw-build", re.IGNORECASE),
        )

    def test_state_protocol_mentions_pivot_return_to_building_without_new_status(self):
        self.assertRegex(
            self.state_text,
            re.compile(
                r"sw-pivot[\s\S]*returns?.*building|building[\s\S]*sw-pivot[\s\S]*without.*new.*status",
                re.IGNORECASE,
            ),
        )


if __name__ == "__main__":
    unittest.main()
