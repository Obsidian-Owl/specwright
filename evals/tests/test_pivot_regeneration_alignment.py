"""Regression tests for Unit 02 — remaining-work regeneration alignment."""

from pathlib import Path
import re
import unittest


ROOT_DIR = Path(__file__).resolve().parents[2]
PLAN_SKILL = ROOT_DIR / "core" / "skills" / "sw-plan" / "SKILL.md"
BUILD_SKILL = ROOT_DIR / "core" / "skills" / "sw-build" / "SKILL.md"
VERIFY_SKILL = ROOT_DIR / "core" / "skills" / "sw-verify" / "SKILL.md"
SHIP_SKILL = ROOT_DIR / "core" / "skills" / "sw-ship" / "SKILL.md"
FRESHNESS_PROTOCOL = ROOT_DIR / "core" / "protocols" / "git-freshness.md"


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


class TestFreshnessReconcileAlignment(unittest.TestCase):
    """Task 2 RED: lifecycle stages must share one non-looping reconcile contract."""

    def setUp(self):
        self.build_text = BUILD_SKILL.read_text(encoding="utf-8")
        self.verify_text = VERIFY_SKILL.read_text(encoding="utf-8")
        self.ship_text = SHIP_SKILL.read_text(encoding="utf-8")
        self.freshness_text = FRESHNESS_PROTOCOL.read_text(encoding="utf-8")

    def test_build_treats_pivoted_unit_artifacts_as_current_approval_surface(self):
        self.assertRegex(
            self.build_text,
            re.compile(
                r"(pivot|replan|regenerated)[\s\S]{0,220}(approval surface|unit-spec)[\s\S]{0,220}(refresh|record)|"
                r"(refresh|record)[\s\S]{0,220}(unit-spec|approval surface)[\s\S]{0,220}(pivot|replan|regenerated)",
                re.IGNORECASE,
            ),
        )

    def test_build_manual_reconcile_guidance_returns_to_build_after_reconcile(self):
        self.assertRegex(
            self.build_text,
            re.compile(
                r"manual reconcile[\s\S]{0,260}/sw-build|/sw-build[\s\S]{0,260}manual reconcile",
                re.IGNORECASE,
            ),
        )

    def test_verify_manual_reconcile_guidance_retries_verify_without_looping_to_build(self):
        self.assertRegex(
            self.verify_text,
            re.compile(
                r"manual reconcile[\s\S]{0,260}/sw-verify|/sw-verify[\s\S]{0,260}manual reconcile",
                re.IGNORECASE,
            ),
        )

    def test_ship_manual_reconcile_guidance_routes_through_verify_then_ship(self):
        self.assertRegex(
            self.ship_text,
            re.compile(
                r"manual reconcile[\s\S]{0,260}/sw-verify[\s\S]{0,120}/sw-ship|"
                r"/sw-verify[\s\S]{0,120}/sw-ship[\s\S]{0,260}manual reconcile",
                re.IGNORECASE,
            ),
        )

    def test_freshness_protocol_names_linked_worktree_guidance_and_no_target_mutation(self):
        self.assertRegex(
            self.freshness_text,
            re.compile(
                r"(linked worktree|owning worktree|adopt/takeover)[\s\S]{0,260}manual|"
                r"manual[\s\S]{0,260}(linked worktree|owning worktree|adopt/takeover)",
                re.IGNORECASE,
            ),
        )
        self.assertRegex(
            self.freshness_text,
            re.compile(
                r"(targetRef|target ref)[\s\S]{0,260}(freshness metadata|freshness policy)[\s\S]{0,260}(not|never).*(rewrite|mutat|clear)|"
                r"(not|never).*(rewrite|mutat|clear)[\s\S]{0,260}(targetRef|target ref)[\s\S]{0,260}(freshness metadata|freshness policy)",
                re.IGNORECASE,
            ),
        )


if __name__ == "__main__":
    unittest.main()
