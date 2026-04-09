"""Tests for evals.framework.prompts — pre-scripted prompt templates.

AC-11: Each template returns string with /sw-{skill} and pre-scripted decisions
AC-12: design() accepts problem_statement, plan() and build() accept no args
"""

import unittest

from evals.framework.prompts import (
    init, design, plan, build, verify, ship,
    doctor, debug, research, learn, pivot, status, sync, guard, audit,
)


class TestPromptTemplatesReturnStrings(unittest.TestCase):
    """AC-11: All templates return strings."""

    def test_init_returns_string(self):
        self.assertIsInstance(init(), str)

    def test_design_returns_string(self):
        self.assertIsInstance(design("add a feature"), str)

    def test_plan_returns_string(self):
        self.assertIsInstance(plan(), str)

    def test_build_returns_string(self):
        self.assertIsInstance(build(), str)

    def test_verify_returns_string(self):
        self.assertIsInstance(verify(), str)

    def test_ship_returns_string(self):
        self.assertIsInstance(ship(), str)


class TestPromptTemplatesContainSkillInvocation(unittest.TestCase):
    """AC-11: Each template includes /sw-{skill} invocation."""

    def test_init_contains_sw_init(self):
        self.assertIn("/sw-init", init())

    def test_design_contains_sw_design(self):
        self.assertIn("/sw-design", design("test"))

    def test_plan_contains_sw_plan(self):
        self.assertIn("/sw-plan", plan())

    def test_build_contains_sw_build(self):
        self.assertIn("/sw-build", build())

    def test_verify_contains_sw_verify(self):
        self.assertIn("/sw-verify", verify())

    def test_ship_contains_sw_ship(self):
        self.assertIn("/sw-ship", ship())

    def test_doctor_contains_sw_doctor(self):
        self.assertIn("/sw-doctor", doctor())


class TestDesignTemplateEmbedsArgs(unittest.TestCase):
    """AC-12: design() accepts problem_statement and embeds it."""

    def test_problem_statement_appears_in_output(self):
        result = design("Add a GET /health endpoint")
        self.assertIn("Add a GET /health endpoint", result)

    def test_different_statements_produce_different_prompts(self):
        r1 = design("Add feature X")
        r2 = design("Fix bug Y")
        self.assertNotEqual(r1, r2)
        self.assertIn("Add feature X", r1)
        self.assertIn("Fix bug Y", r2)


class TestPlanAndBuildTakeNoArgs(unittest.TestCase):
    """AC-12: plan() and build() take zero parameters."""

    def test_plan_callable_with_no_args(self):
        # Should not raise TypeError
        plan()

    def test_build_callable_with_no_args(self):
        build()


class TestPromptTemplatesContainPreScriptedDecisions(unittest.TestCase):
    """AC-11: Templates include pre-scripted decisions to avoid AskUserQuestion."""

    def test_design_mentions_intensity(self):
        result = design("test problem")
        # Should mention Full intensity or similar decision
        lower = result.lower()
        self.assertTrue(
            "full" in lower or "intensity" in lower or "approve" in lower,
            "Design template should include pre-scripted decisions"
        )

    def test_plan_mentions_approval(self):
        result = plan()
        lower = result.lower()
        self.assertTrue(
            "approve" in lower or "accept" in lower or "spec" in lower,
            "Plan template should include pre-scripted approval"
        )

    def test_build_mentions_tdd(self):
        result = build()
        lower = result.lower()
        self.assertTrue(
            "tdd" in lower or "test" in lower or "implement" in lower or "spec" in lower,
            "Build template should reference implementation approach"
        )

    def test_build_handoff_matches_recovery_contract(self):
        result = build()
        self.assertIn("Attention required:", result)
        self.assertIn("Done. <one-line outcome>.", result)
        self.assertIn("Artifacts: <path to stage-report.md>", result)
        self.assertIn("Next: /sw-verify", result)

    def test_verify_handoff_points_to_stage_report_file(self):
        result = verify()
        self.assertIn("Attention required:", result)
        self.assertIn("Done. <one-line outcome>.", result)
        self.assertIn("Artifacts: <path to stage-report.md>", result)
        self.assertIn("Next: /sw-build or /sw-ship", result)


class TestNewPromptTemplates(unittest.TestCase):
    """New templates return non-empty strings with default args."""

    def test_debug_returns_string(self):
        self.assertIsInstance(debug(), str)
        self.assertTrue(len(debug()) > 0)

    def test_debug_with_error_output(self):
        result = debug(error_output="TypeError: undefined is not a function")
        self.assertIn("TypeError", result)

    def test_research_returns_string(self):
        self.assertIsInstance(research(), str)
        self.assertTrue(len(research()) > 0)

    def test_doctor_returns_string(self):
        self.assertIsInstance(doctor(), str)
        self.assertTrue(len(doctor()) > 0)

    def test_research_with_topic(self):
        result = research(topic="GraphQL pagination patterns")
        self.assertIn("GraphQL", result)

    def test_learn_returns_string(self):
        self.assertIsInstance(learn(), str)
        self.assertTrue(len(learn()) > 0)

    def test_pivot_returns_string(self):
        self.assertIsInstance(pivot(), str)
        self.assertTrue(len(pivot()) > 0)

    def test_pivot_with_change(self):
        result = pivot(change_description="Switch from REST to GraphQL")
        self.assertIn("GraphQL", result)

    def test_status_returns_string(self):
        self.assertIsInstance(status(), str)
        self.assertTrue(len(status()) > 0)

    def test_status_repair_embeds_unit_id(self):
        result = status(repair_unit_id="02d-structural-smoke-evals")
        self.assertIn("--repair 02d-structural-smoke-evals", result)

    def test_status_repair_headless_mentions_report_only(self):
        result = status(repair_unit_id="02d-structural-smoke-evals", headless=True)
        self.assertIn("non-interactive", result)
        self.assertIn("report-only", result)

    def test_ship_handoff_matches_recovery_contract(self):
        result = ship()
        self.assertIn("Attention required:", result)
        self.assertIn("Done. <one-line outcome>.", result)
        self.assertIn("Artifacts: <path to stage-report.md>", result)

    def test_sync_returns_string(self):
        self.assertIsInstance(sync(), str)
        self.assertTrue(len(sync()) > 0)

    def test_guard_returns_string(self):
        self.assertIsInstance(guard(), str)
        self.assertTrue(len(guard()) > 0)

    def test_audit_returns_string(self):
        self.assertIsInstance(audit(), str)
        self.assertTrue(len(audit()) > 0)

    def test_audit_with_scope(self):
        result = audit(scope="src/handlers/")
        self.assertIn("src/handlers/", result)


if __name__ == "__main__":
    unittest.main()
