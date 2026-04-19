"""Tests for WU-02 Task 1: gate-tests adopts the tiered mutation model.

RED phase: these tests must fail until `core/skills/gate-tests/SKILL.md`
documents the T1 / T2 / T3 mutation flow, its fallback rules, and the
evidence requirements for verify-time reporting.
"""

import os
import re
import unittest


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_GATE_TESTS_PATH = os.path.join(_REPO_ROOT, "core", "skills", "gate-tests", "SKILL.md")


def _load_text(path):
    with open(path, "r") as f:
        return f.read()


def _assert_multiline_regex(testcase, text, pattern):
    testcase.assertIsNotNone(
        re.search(pattern, text, re.DOTALL),
        f"pattern not found: {pattern}",
    )


class TestTieredMutationModel(unittest.TestCase):
    """AC-1: gate-tests keeps mutation analysis inside the tests gate."""

    def setUp(self):
        self.content = _load_text(_GATE_TESTS_PATH)
        self.lower = self.content.lower()

    def test_names_t1_t2_t3_as_the_only_mutation_tiers(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"mutation resistance.+t1.+t2.+t3",
        )

    def test_describes_t1_as_tool_backed(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t1.+tool[- ]backed",
        )

    def test_describes_t2_as_llm_generated(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t2.+llm[- ]generated",
        )

    def test_describes_t3_as_the_qualitative_floor(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t3.+qualitative.+floor",
        )

    def test_does_not_allow_missing_tool_to_become_skip(self):
        self.assertNotRegex(
            self.lower,
            r"missing tool.{0,80}gate skip|gate skip.{0,80}missing tool",
        )
        _assert_multiline_regex(
            self,
            self.lower,
            r"missing tool.+t2.+t3|t2.+t3.+missing tool",
        )

    def test_keeps_mutation_analysis_inside_existing_tests_gate(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"(inside|within).{0,40}(existing|tests) gate",
        )


class TestTierTransitions(unittest.TestCase):
    """AC-2: gate-tests defines the approved T1 / T2 / T3 transitions."""

    def setUp(self):
        self.lower = _load_text(_GATE_TESTS_PATH).lower()

    def test_configured_tool_runs_use_t1(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"configured.+tool[- ]backed.+t1|t1.+configured.+tool[- ]backed",
        )

    def test_zero_applicable_mutants_drop_to_t2(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"zero applicable mutants?.+t2|t2.+zero applicable mutants?",
        )

    def test_configured_llm_fallback_uses_t2(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"configured.+llm fallback.+t2|t2.+configured.+llm fallback",
        )

    def test_t1_errors_drop_to_t3(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t1.+errors?.+t3|t3.+t1.+errors?",
        )

    def test_t2_errors_drop_to_t3(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t2.+errors?.+t3|t3.+t2.+errors?",
        )

    def test_unavailable_fallback_drops_to_t3(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"(fallback unavailable|unavailable fallback).+t3|t3.+(fallback unavailable|unavailable fallback)",
        )


class TestMutationEvidenceRequirements(unittest.TestCase):
    """AC-3: T1 / T2 findings preserve useful verify-time evidence."""

    def setUp(self):
        self.lower = _load_text(_GATE_TESTS_PATH).lower()

    def test_t1_t2_findings_require_file_line_evidence(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"t1.+file:line|t2.+file:line|file:line.+t1/t2",
        )

    def test_t1_t2_findings_require_score_or_survivor_details(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"(mutation score|survivor details).+(t1|t2)|(t1|t2).+(mutation score|survivor details)",
        )

    def test_honors_accepted_mutant_lineage(self):
        _assert_multiline_regex(
            self,
            self.lower,
            r"accepted[- ]mutant.+(approval|config)|(approval|config).+accepted[- ]mutant",
        )


if __name__ == "__main__":
    unittest.main()
