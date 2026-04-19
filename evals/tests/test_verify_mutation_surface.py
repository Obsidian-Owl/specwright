"""Tests for WU-03 Task 1: sw-verify exposes mutation lineage and tiers."""

import os
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_VERIFY_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-verify", "SKILL.md")


class TestVerifyMutationSurface(unittest.TestCase):
    """AC-1: verify documents accepted-mutant handling and gate ownership."""

    def setUp(self):
        self.content = load_text(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_documents_accept_mutant_command_shape(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"accept-mutant\s+\{id\}.+reason",
        )

    def test_ties_accepted_mutants_to_approval_lineage(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"accepted[- ]mutant.+approval (?:lineage|record)|approval (?:lineage|record).+accepted[- ]mutant",
        )

    def test_keeps_mutation_inside_gate_tests(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"gate-tests.+(?:not a new gate|stays inside|inside the existing tests gate)|(?:not a new gate|stays inside|inside the existing tests gate).+gate-tests",
        )


class TestVerifyMutationOutputSemantics(unittest.TestCase):
    """AC-2: verify explains tiered mutation evidence without breaking verify semantics."""

    def setUp(self):
        self.content = load_text(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_names_t1_t2_t3_in_verify_output(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"t1.+t2.+t3",
        )

    def test_discloses_restricted_survivor_fields(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"operator.+location.+before/after.+defect category.+action",
        )

    def test_excludes_test_bodies_and_assertion_literals(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"no test bodies?.+no assertion literals|no assertion literals.+no test bodies?",
        )

    def test_preserves_partial_run_evidence_completeness_rule(self):
        self.assertIn("Skip when `--gate=<name>` was used", self.content)
        self.assertIn("partial run", self.lower)

    def test_preserves_six_gate_execution_model(self):
        self.assertIn("All six gates are eligible", self.content)


if __name__ == "__main__":
    unittest.main()
