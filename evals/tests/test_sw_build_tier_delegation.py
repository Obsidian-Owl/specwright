"""Tests for tier-aware delegation in core/skills/sw-build/SKILL.md.

RED phase: all tests targeting new content must fail because sw-build does not
yet have tier-aware delegation to specwright-integration-tester.

This test suite covers:
  AC-1: TDD cycle extended with integration tester delegation for non-unit ACs
  AC-2: Existing RED → GREEN → REFACTOR preserved for unit-tier ACs
  AC-3: Context envelope extended with integration-tester delegation items
  AC-4: Build failures covers integration test failures via build-fixer
  AC-5: Combined test run after integration tests (configured commands)
  AC-6: Inner-loop validation updated for tier-aware delegation
"""

import os
import re
import unittest


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SKILL_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-build", "SKILL.md")


def _load_skill():
    with open(_SKILL_PATH, "r") as f:
        return f.read()


# ===========================================================================
# AC-1: TDD cycle extended with integration tester delegation
# ===========================================================================

class TestAC1_TDDCycleTierDelegation(unittest.TestCase):
    """AC-1: sw-build delegates non-unit ACs to specwright-integration-tester."""

    def setUp(self):
        self.content = _load_skill()
        self.content_lower = self.content.lower()

    def test_mentions_integration_tester_agent(self):
        """sw-build must reference specwright-integration-tester."""
        self.assertIn(
            "specwright-integration-tester",
            self.content,
            "sw-build must mention specwright-integration-tester agent"
        )

    def test_tier_tag_check_described(self):
        """sw-build must describe checking ACs for tier tags."""
        has_tier_check = bool(re.search(
            r"(check|identif|read|scan).{0,40}(tier\s+tag|tier\s+annot|\[tier:)",
            self.content_lower
        ))
        self.assertTrue(
            has_tier_check,
            "sw-build must describe checking ACs for tier tags"
        )

    def test_non_unit_acs_delegated_to_integration_tester(self):
        """Non-unit ACs (integration/contract/e2e) must be delegated to integration-tester."""
        has_delegation = bool(re.search(
            r"(integration|contract|e2e).{0,80}(specwright-integration-tester|integration.tester)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_delegation,
            "Non-unit tier ACs must be delegated to specwright-integration-tester"
        )

    def test_delegation_happens_after_green(self):
        """Integration tester delegation must happen after GREEN phase."""
        has_after_green = bool(re.search(
            r"green.{0,300}(specwright-integration-tester|integration.tester)",
            self.content_lower, re.DOTALL
        )) or bool(re.search(
            r"(after|following).{0,80}(green|executor).{0,200}(integration.tester|non.unit)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_after_green,
            "Integration tester delegation must be described as happening after GREEN"
        )

    def test_delegation_happens_before_refactor(self):
        """Integration tester delegation must happen before REFACTOR phase."""
        has_before_refactor = bool(re.search(
            r"(integration.tester|non.unit).{0,500}refactor",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_before_refactor,
            "Integration tester delegation must happen before REFACTOR"
        )

    def test_includes_tier_tags_in_delegation_prompt(self):
        """The delegation prompt for integration tester must include tier tags or non-unit ACs."""
        has_prompt_content = bool(re.search(
            r"(delegation|prompt|include).{0,120}(tier|non.unit).{0,80}(ac|criteria|acceptance)",
            self.content_lower, re.DOTALL
        )) or bool(re.search(
            r"(non.unit|tier).{0,80}(ac|criteria).{0,120}(specwright-integration-tester|integration.tester)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_prompt_content,
            "Integration tester delegation prompt must include tier-tagged ACs"
        )

    def test_includes_testing_md_reference(self):
        """Integration tester delegation prompt must reference TESTING.md."""
        has_testing_ref = bool(re.search(
            r"(integration.tester|delegation).{0,300}testing\.md",
            self.content_lower, re.DOTALL
        )) or bool(re.search(
            r"testing\.md.{0,300}(integration.tester)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_testing_ref,
            "Integration tester delegation prompt must reference TESTING.md"
        )

    def test_includes_config_languages(self):
        """Integration tester delegation prompt must include config.json languages field."""
        has_lang = bool(re.search(
            r"(config\.json|language).{0,200}(integration.tester|delegation)",
            self.content_lower, re.DOTALL
        )) or bool(re.search(
            r"(integration.tester|delegation).{0,200}(config\.json|language)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_lang,
            "Integration tester delegation must include config.json languages field"
        )


# ===========================================================================
# AC-2: Existing RED → GREEN → REFACTOR preserved
# ===========================================================================

class TestAC2_ExistingFlowPreserved(unittest.TestCase):
    """AC-2: Existing RED → GREEN → REFACTOR for unit ACs is unchanged."""

    def setUp(self):
        self.content = _load_skill()

    def test_red_phase_still_delegates_to_tester(self):
        """RED phase must still delegate to specwright-tester."""
        has_red_tester = bool(re.search(
            r"RED.*?specwright-tester",
            self.content, re.DOTALL
        ))
        self.assertTrue(
            has_red_tester,
            "RED phase must still delegate to specwright-tester"
        )

    def test_green_phase_still_delegates_to_executor(self):
        """GREEN phase must still delegate to specwright-executor."""
        has_green_exec = bool(re.search(
            r"GREEN.*?specwright-executor",
            self.content, re.DOTALL
        ))
        self.assertTrue(
            has_green_exec,
            "GREEN phase must still delegate to specwright-executor"
        )

    def test_refactor_phase_still_exists(self):
        """REFACTOR phase must still exist."""
        self.assertIn("REFACTOR", self.content)

    def test_no_non_unit_acs_changes_existing_flow(self):
        """When no non-unit ACs exist, the flow must be unchanged."""
        has_no_change_path = bool(re.search(
            r"no\s+non.unit.{0,80}(existing|unchanged|normal|zero|no\s+additional|skip)",
            self.content.lower(), re.DOTALL
        ))
        self.assertTrue(
            has_no_change_path,
            "Must document that tasks with no non-unit ACs follow existing flow"
        )


# ===========================================================================
# AC-3: Context envelope extended
# ===========================================================================

class TestAC3_ContextEnvelope(unittest.TestCase):
    """AC-3: Context envelope includes integration-tester delegation items."""

    def setUp(self):
        self.content = _load_skill()
        self.content_lower = self.content.lower()

    def test_context_mentions_languages_field(self):
        """Context envelope must mention config.json languages field."""
        has_lang = bool(re.search(
            r"(context|envelope|delegat).{0,200}language",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_lang,
            "Context envelope must mention languages field for integration tester"
        )

    def test_context_mentions_testing_md(self):
        """Context envelope must mention TESTING.md for integration tester."""
        has_testing = bool(re.search(
            r"testing\.md",
            self.content_lower
        ))
        self.assertTrue(
            has_testing,
            "Context must reference TESTING.md"
        )


# ===========================================================================
# AC-4: Build failures covers integration test failures
# ===========================================================================

class TestAC4_BuildFailureHandling(unittest.TestCase):
    """AC-4: Integration test failures handled via build-fixer."""

    def setUp(self):
        self.content = _load_skill()
        self.content_lower = self.content.lower()

    def test_integration_test_failure_mentions_build_fixer(self):
        """Integration test failures must delegate to build-fixer."""
        has_int_fixer = bool(re.search(
            r"integration.{0,100}(test|tester).{0,100}(build.fixer|specwright-build-fixer)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_int_fixer,
            "Integration test failures must route to build-fixer"
        )

    def test_infrastructure_health_check_mentioned(self):
        """Build-fixer should check infrastructure health for integration failures."""
        has_infra_check = bool(re.search(
            r"infrastructure\s+health",
            self.content_lower
        ))
        self.assertTrue(
            has_infra_check,
            "Must mention checking infrastructure health for integration test failures"
        )


# ===========================================================================
# AC-5: Combined test run
# ===========================================================================

class TestAC5_CombinedTestRun(unittest.TestCase):
    """AC-5: Combined test run after integration tests using configured commands."""

    def setUp(self):
        self.content = _load_skill()
        self.content_lower = self.content.lower()

    def test_mentions_configured_test_commands(self):
        """Must reference configured test commands for the combined run."""
        has_commands = bool(re.search(
            r"commands\.test",
            self.content_lower
        ))
        self.assertTrue(
            has_commands,
            "Must reference configured test commands (commands.test)"
        )

    def test_regression_check_after_integration(self):
        """Must run tests to confirm nothing regressed after integration tests."""
        has_regression = bool(re.search(
            r"(regress|confirm|verify).{0,120}(all|both|unit.*integration)",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_regression,
            "Must describe running all tests to check for regressions"
        )


# ===========================================================================
# AC-6: Inner-loop validation updated
# ===========================================================================

class TestAC6_InnerLoopValidation(unittest.TestCase):
    """AC-6: Inner-loop validation notes relationship to tier-aware delegation."""

    def setUp(self):
        self.content = _load_skill()
        self.content_lower = self.content.lower()

    def test_inner_loop_mentions_tier_or_integration_tester(self):
        """Inner-loop validation must acknowledge tier-aware delegation context."""
        # The inner-loop section should note that integration tests may have already run
        has_context = bool(re.search(
            r"inner.loop.{0,400}(tier|integration.tester|already.{0,30}run|task.loop)",
            self.content_lower, re.DOTALL
        )) or bool(re.search(
            r"(tier|integration.tester).{0,400}inner.loop",
            self.content_lower, re.DOTALL
        ))
        self.assertTrue(
            has_context,
            "Inner-loop validation must acknowledge tier-aware delegation or integration tests already run"
        )


# ===========================================================================
# Document integrity
# ===========================================================================

class TestDocumentIntegrity(unittest.TestCase):
    """Ensure existing constraints are not broken."""

    def setUp(self):
        self.content = _load_skill()

    def test_stage_boundary_preserved(self):
        self.assertIn("Stage boundary", self.content)

    def test_branch_setup_preserved(self):
        self.assertIn("Branch setup", self.content)

    def test_commits_preserved(self):
        self.assertIn("Commits (LOW freedom)", self.content)

    def test_parallel_execution_preserved(self):
        self.assertIn("Parallel execution", self.content)

    def test_as_built_notes_preserved(self):
        self.assertIn("As-built notes", self.content)

    def test_post_build_review_preserved(self):
        self.assertIn("Post-build review", self.content)

    def test_protocol_references_preserved(self):
        self.assertIn("protocols/delegation.md", self.content)
        self.assertIn("protocols/git.md", self.content)


if __name__ == "__main__":
    unittest.main()
