"""Regression coverage for WU-03 Task 3: verify-time mutation surface alignment."""

import os
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_VERIFY_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-verify", "SKILL.md")
_GATE_TESTS_PATH = os.path.join(_REPO_ROOT, "core", "skills", "gate-tests", "SKILL.md")
_TESTER_PATH = os.path.join(_REPO_ROOT, "core", "agents", "specwright-tester.md")


class TestAcceptedMutantOwnershipAlignment(unittest.TestCase):
    """AC-5: accepted-mutant lineage stays verify-owned and gate-backed."""

    def setUp(self):
        self.verify = load_text(_VERIFY_PATH).lower()
        self.gate = load_text(_GATE_TESTS_PATH).lower()
        self.tester = load_text(_TESTER_PATH).lower()

    def test_verify_and_gate_tests_share_accepted_mutant_lineage_terms(self):
        for surface, content in (("verify", self.verify), ("gate-tests", self.gate)):
            with self.subTest(surface=surface):
                assert_multiline_regex(
                    self,
                    content,
                    r"accepted[- ]mutant.+approval (?:lineage|record)|approval (?:lineage|record).+accepted[- ]mutant",
                )

    def test_tester_does_not_introduce_a_separate_accept_mutant_cli(self):
        self.assertNotIn("accept-mutant", self.tester)


class TestMutationDisclosureAlignment(unittest.TestCase):
    """AC-5: verify, gate-tests, and tester stay aligned on mutation disclosure."""

    def setUp(self):
        self.surfaces = {
            "verify": load_text(_VERIFY_PATH).lower(),
            "gate-tests": load_text(_GATE_TESTS_PATH).lower(),
            "tester": load_text(_TESTER_PATH).lower(),
        }

    def test_all_surfaces_name_t1_t2_t3(self):
        for surface, content in self.surfaces.items():
            with self.subTest(surface=surface):
                assert_multiline_regex(
                    self,
                    content,
                    r"t1.+t2.+t3",
                )

    def test_all_surfaces_share_the_restricted_survivor_record(self):
        for surface, content in self.surfaces.items():
            with self.subTest(surface=surface):
                assert_multiline_regex(
                    self,
                    content,
                    r"operator.+location.+before/after.+defect category.+action",
                )

    def test_all_surfaces_reject_silent_skip_behavior(self):
        for surface, content in self.surfaces.items():
            with self.subTest(surface=surface):
                assert_multiline_regex(
                    self,
                    content,
                    r"silent skip|silently skipping",
                )


if __name__ == "__main__":
    unittest.main()
