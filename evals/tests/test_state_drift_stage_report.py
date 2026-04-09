"""Contract tests for Unit 05 — state drift repair and stage-report artifact.

These tests validate the markdown contract surface across protocols and skills.
They follow the existing pattern used for other skill/protocol units: inspect
SKILL.md and protocol content directly rather than executing a separate runtime.
"""

import os
import re
import unittest


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_STATE_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "state.md")
_DECISION_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "decision.md")
_SHIP_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-ship", "SKILL.md")
_DOCTOR_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-doctor", "SKILL.md")
_STATUS_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-status", "SKILL.md")
_PIPELINE_SKILLS = ["sw-design", "sw-plan", "sw-build", "sw-verify", "sw-ship"]


def _load(path: str) -> str:
    with open(path, "r") as f:
        return f.read()


def _extract_section(content: str, heading: str) -> str | None:
    pattern = rf"^## {re.escape(heading)}\s*\n(.*?)(?=\n## |\Z)"
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        return match.group(1).strip()
    return None


def _extract_constraint_block(content: str, constraint_name: str) -> str | None:
    pattern = rf"\*\*{re.escape(constraint_name)}\s*\([^)]+\):\*\*\s*\n(.*?)(?=\n\*\*[A-Z]|\n## |\Z)"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(0).strip()
    return None


def _require_constraint(content: str, constraint_name: str) -> str:
    block = _extract_constraint_block(content, constraint_name)
    if block is None:
        raise AssertionError(
            f"Constraint block '**{constraint_name}**' must exist"
        )
    return block


class TestStateSchemaPrFields(unittest.TestCase):
    """AC-1: state.md documents prNumber/prMergedAt as nullable optional fields."""

    def setUp(self):
        self.content = _load(_STATE_PATH)
        self.content_lower = self.content.lower()

    def test_schema_mentions_pr_number(self):
        self.assertIn("prNumber", self.content)

    def test_schema_mentions_pr_merged_at(self):
        self.assertIn("prMergedAt", self.content)

    def test_pr_number_is_documented_nullable_and_optional(self):
        self.assertRegex(
            self.content,
            r"prNumber.*number\s*\|\s*null.*optional.*nullable|prNumber.*optional.*nullable.*number\s*\|\s*null",
        )

    def test_pr_merged_at_is_documented_nullable_and_optional(self):
        self.assertRegex(
            self.content,
            r"prMergedAt.*ISO timestamp\s*\|\s*null.*optional.*nullable|prMergedAt.*optional.*nullable.*ISO timestamp\s*\|\s*null",
        )

    def test_backward_compatible_language_present(self):
        self.assertIn("backward", self.content_lower)


class TestSwShipPrNumberContract(unittest.TestCase):
    """AC-2/AC-3: sw-ship writes prNumber after PR creation inside rollback envelope."""

    def setUp(self):
        self.content = _load(_SHIP_PATH)
        self.state_updates = _require_constraint(self.content, "State updates")
        self.failures = _extract_section(self.content, "Failure Modes") or ""

    def test_state_updates_mentions_pr_number_write(self):
        self.assertRegex(
            self.state_updates,
            r"prNumber",
            "State updates block must mention prNumber write",
        )

    def test_pr_number_write_happens_after_pr_creation(self):
        self.assertRegex(
            self.state_updates,
            r"create PR.*prNumber|PR creation.*prNumber|successful PR creation.*prNumber",
        )

    def test_pr_number_write_precedes_shipped_transition(self):
        self.assertRegex(
            self.state_updates,
            r"prNumber.*shipped|write prNumber.*set status to `shipped`",
        )

    def test_failure_modes_keep_verifying_on_pr_create_failure(self):
        self.assertRegex(
            self.failures,
            r"PR creation fails.*verifying|revert.*verifying.*PR creation fails",
        )

    def test_failure_modes_keep_pr_number_null_when_creation_fails(self):
        self.assertRegex(
            self.content,
            r"prNumber stays null|prNumber remains null|null on failure",
        )


class TestSwDoctorStateDrift(unittest.TestCase):
    """AC-4..AC-7: sw-doctor detects state drift and backfills safely."""

    def setUp(self):
        self.content = _load(_DOCTOR_PATH)
        self.checks = _require_constraint(self.content, "Checks")
        self.outputs = _extract_section(self.content, "Outputs") or ""
        self.constraints = _extract_section(self.content, "Constraints") or ""
        self.failures = _extract_section(self.content, "Failure Modes") or ""

    def test_defines_state_drift_check(self):
        self.assertIn("STATE_DRIFT", self.content)

    def test_detects_shipped_null_pr_number(self):
        self.assertRegex(
            self.content,
            r"status\s*=\s*shipped.*prNumber\s*=\s*null|prNumber=null.*status=shipped",
        )

    def test_prints_inline_repair_command(self):
        self.assertIn("sw-status --repair", self.content)

    def test_mentions_one_time_backfill(self):
        self.assertRegex(
            self.content.lower(),
            r"one.time backfill|backfill on first invocation|first invocation.*backfill",
        )

    def test_backfill_uses_gh_then_git_log_then_warn(self):
        self.assertRegex(
            self.content.lower(),
            r"gh.*git log.*warn|gh.*merge commit.*warn",
        )

    def test_backfill_only_mutates_pr_fields_not_status(self):
        self.assertRegex(
            self.content,
            r"never modifies `?status`?.*only.*prNumber.*prMergedAt|only.*prNumber.*prMergedAt.*never modifies `?status`?",
        )


class TestSwStatusRepairMode(unittest.TestCase):
    """AC-8..AC-10: sw-status gains --repair mode with interactive options."""

    def setUp(self):
        self.content = _load(_STATUS_PATH)
        self.display = _require_constraint(self.content, "Display")
        self.non_interactive = _require_constraint(self.content, "Non-interactive context")
        self.failure_modes = _extract_section(self.content, "Failure Modes") or ""

    def test_argument_hint_includes_repair(self):
        self.assertRegex(
            self.content,
            r"argument-hint:\s*\"[^\"]*--repair",
        )

    def test_repair_mode_documented(self):
        self.assertIn("--repair", self.content)

    def test_repair_mode_handles_confirmed_merged_pr(self):
        self.assertRegex(
            self.content.lower(),
            r"merged pr.*repaired|gh confirms a merged pr.*populate",
        )

    def test_repair_mode_lists_three_interactive_options(self):
        for option in ("revert-to-building", "mark-abandoned", "force-shipped-with-note"):
            self.assertIn(option, self.content)

    def test_headless_repair_is_report_only(self):
        self.assertRegex(
            self.non_interactive.lower(),
            r"repair.*report-only|report-only.*repair",
        )

    def test_force_shipped_writes_decision_note(self):
        self.assertRegex(
            self.content.lower(),
            r"decisions\.md|decision[s]?\.md",
        )


class TestStageReportProtocol(unittest.TestCase):
    """AC-11..AC-13: stage-report contract and handoff artifact path."""

    def setUp(self):
        self.content = _load(_DECISION_PATH)
        self.stage_report = _extract_section(self.content, "Stage Report") or ""
        self.gate_handoff = _extract_section(self.content, "Gate Handoff") or ""

    def test_stage_report_section_exists(self):
        self.assertIn("## Stage Report", self.content)

    def test_stage_report_mentions_attention_required_at_top(self):
        self.assertRegex(
            self.stage_report,
            r"Attention required",
        )

    def test_stage_report_mentions_40_line_cap(self):
        self.assertRegex(
            self.stage_report,
            r"40\s*line|~40 lines",
        )

    def test_stage_report_lists_required_sections(self):
        for required in (
            "Precondition State",
            "What I did",
            "Decisions digest",
            "Quality Checks",
            "Postcondition State",
            "Recommendation",
        ):
            self.assertIn(required, self.stage_report)

    def test_gate_handoff_points_to_stage_report(self):
        self.assertIn("Artifacts: {workDir}/stage-report.md", self.gate_handoff)


class TestPipelineSkillsReferenceStageReport(unittest.TestCase):
    """AC-11/AC-13: pipeline skills expose stage-report artifact and handoff path."""

    def _load_skill(self, skill_name: str) -> str:
        return _load(os.path.join(_REPO_ROOT, "core", "skills", skill_name, "SKILL.md"))

    def test_outputs_sections_include_stage_report(self):
        for skill in _PIPELINE_SKILLS:
            with self.subTest(skill=skill):
                content = self._load_skill(skill)
                outputs = _extract_section(content, "Outputs") or ""
                self.assertIn("stage-report.md", outputs)

    def test_handoff_constraints_reference_stage_report(self):
        for skill in _PIPELINE_SKILLS:
            with self.subTest(skill=skill):
                content = self._load_skill(skill)
                self.assertRegex(
                    content,
                    r"stage-report\.md",
                    f"{skill} must reference stage-report.md somewhere in its contract",
                )

    def test_pipeline_skills_keep_machine_parseable_next_step(self):
        for skill in ("sw-design", "sw-plan", "sw-verify", "sw-ship"):
            with self.subTest(skill=skill):
                content = self._load_skill(skill)
                self.assertRegex(content, r"Next: /sw-")


if __name__ == "__main__":
    unittest.main()
