"""Tests for WU-02 Task 2: specwright-tester adopts tiered mutation triage.

RED phase: these tests must fail until `core/agents/specwright-tester.md`
documents equivalent-mutant preprocessing, the restricted verify-time survivor
format, and advisory-only mutation pressure during RED.
"""

import os
import re
import unittest


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_TESTER_PATH = os.path.join(_REPO_ROOT, "core", "agents", "specwright-tester.md")


def _load_text(path):
    with open(path, "r") as f:
        return f.read()


def _assert_multiline_regex(testcase, text, pattern):
    testcase.assertIsNotNone(
        re.search(pattern, text, re.DOTALL),
        f"pattern not found: {pattern}",
    )


class TestTieredMutationTriage(unittest.TestCase):
    """AC-4: tester prompt keeps tier names and survivor triage aligned."""

    def setUp(self):
        self.content = _load_text(_TESTER_PATH)
        self.lower = self.content.lower()

    def test_names_t1_t2_t3(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t1.+t2.+t3",
        )

    def test_requires_equivalent_mutant_preprocessing(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"equivalent[- ]mutant.+preprocess|preprocess.+equivalent[- ]mutant",
        )

    def test_verify_time_survivor_output_has_restricted_fields_only(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"operator.+location.+before/after.+defect category.+action",
        )

    def test_verify_time_survivor_output_excludes_test_bodies_and_assertion_literals(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"no test bodies?.+no assertion literals|no assertion literals.+no test bodies?",
        )


class TestAdvisoryRedPhaseMutationPressure(unittest.TestCase):
    """AC-5: build-time mutation pressure stays lightweight and non-blocking."""

    def setUp(self):
        self.lower = _load_text(_TESTER_PATH).lower()

    def test_red_phase_limits_tool_backed_scope(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"red phase.+(test-in-progress|current change)|(test-in-progress|current change).+red phase",
        )

    def test_build_time_mutation_signal_is_advisory(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"(build-time|red-phase).+mutation.+advisory|advisory.+(build-time|red-phase).+mutation",
        )

    def test_tool_errors_do_not_block_tdd_completion(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"tool[- ]backed.+errors?.+do not block|do not block.+tool[- ]backed.+errors?",
        )


if __name__ == "__main__":
    unittest.main()
