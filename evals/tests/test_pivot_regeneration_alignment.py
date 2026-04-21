"""Regression tests for Unit 02 — remaining-work regeneration alignment."""

from pathlib import Path
import re
import unittest


ROOT_DIR = Path(__file__).resolve().parents[2]
PLAN_SKILL = ROOT_DIR / "core" / "skills" / "sw-plan" / "SKILL.md"


class TestPlanRegenerationAlignment(unittest.TestCase):
    """Task 1 RED: replanning must describe regeneration of remaining work only."""

    def setUp(self):
        self.plan_text = PLAN_SKILL.read_text(encoding="utf-8")

    def test_replanning_regenerates_only_affected_remaining_unit_artifacts(self):
        self.assertRegex(
            self.plan_text,
            re.compile(
                r"affected remaining[- ]unit[\s\S]{0,220}(spec\.md|plan\.md|context\.md)|"
                r"(spec\.md|plan\.md|context\.md)[\s\S]{0,220}affected remaining[- ]unit",
                re.IGNORECASE,
            ),
        )

    def test_replanning_keeps_shipped_units_as_immutable_baseline_scope(self):
        self.assertRegex(
            self.plan_text,
            re.compile(
                r"shipped units?[\s\S]{0,220}(preserve|immutable|baseline scope)|"
                r"(preserve|immutable|baseline scope)[\s\S]{0,220}shipped units?",
                re.IGNORECASE,
            ),
        )

    def test_replanning_preserves_recorded_target_and_freshness_metadata(self):
        self.assertRegex(
            self.plan_text,
            re.compile(
                r"(targetRef|target ref)[\s\S]{0,220}freshness metadata[\s\S]{0,220}(preserve|preserving)|"
                r"(preserve|preserving)[\s\S]{0,220}(targetRef|target ref)[\s\S]{0,220}freshness metadata",
                re.IGNORECASE,
            ),
        )

    def test_structural_replanning_regenerates_integration_criteria_for_open_scope(self):
        self.assertRegex(
            self.plan_text,
            re.compile(
                r"integration-criteria\.md[\s\S]{0,220}(affected remaining|open scope|remaining units)|"
                r"(affected remaining|open scope|remaining units)[\s\S]{0,220}integration-criteria\.md",
                re.IGNORECASE,
            ),
        )


if __name__ == "__main__":
    unittest.main()
