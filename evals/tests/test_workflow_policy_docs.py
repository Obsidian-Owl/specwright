"""Regression tests for Unit 05 workflow-policy documentation."""

import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


VERIFY_SKILL = "core/skills/sw-verify/SKILL.md"
PARALLEL_PROTOCOL = "core/protocols/parallel-build.md"
PLAN_SKILL = "core/skills/sw-plan/SKILL.md"
BUILD_SKILL = "core/skills/sw-build/SKILL.md"
SIDECAR_SKILLS = [
    "core/skills/sw-research/SKILL.md",
    "core/skills/sw-doctor/SKILL.md",
    "core/skills/sw-review/SKILL.md",
    "core/skills/sw-sync/SKILL.md",
    "core/skills/sw-audit/SKILL.md",
    "core/skills/sw-learn/SKILL.md",
]


class TestVerifyParallelLanePolicy(unittest.TestCase):
    """Task 1 RED: verify must describe prerequisite-first read-only lanes."""

    def setUp(self) -> None:
        self.verify_text = load_text(VERIFY_SKILL)
        self.parallel_text = load_text(PARALLEL_PROTOCOL)

    def test_verify_runs_freshness_build_and_tests_before_parallel_lanes(self) -> None:
        assert_multiline_regex(
            self,
            self.verify_text.lower(),
            r"freshness[\s\S]{0,220}build[\s\S]{0,220}tests[\s\S]{0,260}"
            r"(parallel|read-only lane|read-only lanes)",
        )

    def test_verify_limits_parallelism_to_read_only_evidence_producers(self) -> None:
        assert_multiline_regex(
            self,
            self.verify_text.lower(),
            r"(security|wiring|semantic|spec)[\s\S]{0,220}"
            r"(read-only evidence producers|read-only lanes?)",
        )

    def test_verify_requires_parent_only_aggregation_of_lane_results(self) -> None:
        assert_multiline_regex(
            self,
            self.verify_text.lower(),
            r"(parent|top-level)[\s\S]{0,220}(aggregate|aggregates|aggregation)"
            r"[\s\S]{0,220}(workflow state|shared work state|gates section)",
        )

    def test_verify_keeps_missing_evidence_or_lane_failure_fail_closed(self) -> None:
        assert_multiline_regex(
            self,
            self.verify_text.lower(),
            r"(missing evidence|lane failure|skipped prerequisite state)[\s\S]{0,220}"
            r"(prevents|block|cannot|must not)[\s\S]{0,160}(aggregate )?pass",
        )

    def test_parallel_protocol_restates_parent_only_shared_state_for_helpers(self) -> None:
        assert_multiline_regex(
            self,
            self.parallel_text.lower(),
            r"(parent|top-level)[\s\S]{0,180}(only authority|only writer|only mutator)"
            r"[\s\S]{0,180}(shared workflow state|workflow\.json|shared work state)",
        )


class TestWorkflowOwnershipLanguage(unittest.TestCase):
    """Task 2 RED: sidecars and core stages must describe the same ownership model."""

    def test_sidecar_skills_do_not_claim_core_stage_or_top_level_ownership(self) -> None:
        for skill_path in SIDECAR_SKILLS:
            with self.subTest(skill=skill_path):
                skill_text = load_text(skill_path).lower()
                assert_multiline_regex(
                    self,
                    skill_text,
                    r"not a core workflow stage",
                )
                assert_multiline_regex(
                    self,
                    skill_text,
                    r"never claims top-level work ownership",
                )

    def test_sw_plan_directs_mutable_concurrency_into_separate_works(self) -> None:
        assert_multiline_regex(
            self,
            load_text(PLAN_SKILL).lower(),
            r"mutable concurrency[\s\S]{0,220}separate works[\s\S]{0,220}integration criteria",
        )

    def test_sw_build_directs_mutable_concurrency_into_separate_works(self) -> None:
        assert_multiline_regex(
            self,
            load_text(BUILD_SKILL).lower(),
            r"mutable concurrency[\s\S]{0,220}separate works[\s\S]{0,220}integration criteria",
        )


class TestWorkflowPolicyProofHardening(unittest.TestCase):
    """Task 3 RED: the proof surface must fail closed on helper writes and soft success."""

    def setUp(self) -> None:
        self.verify_text = load_text(VERIFY_SKILL).lower()
        self.parallel_text = load_text(PARALLEL_PROTOCOL).lower()

    def test_parallel_protocol_forbids_direct_helper_writes_to_shared_state(self) -> None:
        assert_multiline_regex(
            self,
            self.parallel_text,
            r"directly write[\s\S]{0,120}workflow\.json[\s\S]{0,120}session\.json",
        )

    def test_verify_explicitly_rejects_soft_success_without_required_evidence(self) -> None:
        assert_multiline_regex(
            self,
            self.verify_text,
            r"soft (success|pass)[\s\S]{0,160}(required evidence|missing evidence)",
        )


if __name__ == "__main__":
    unittest.main()
