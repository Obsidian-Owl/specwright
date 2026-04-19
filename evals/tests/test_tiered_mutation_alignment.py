"""Regression coverage for WU-02 Task 3: tier alignment across gate and tester.

RED phase: these tests must fail until gate-tests and specwright-tester stay
aligned on the restricted survivor format and the T3 qualitative floor.
"""

import os
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_GATE_TESTS_PATH = os.path.join(_REPO_ROOT, "core", "skills", "gate-tests", "SKILL.md")
_TESTER_PATH = os.path.join(_REPO_ROOT, "core", "agents", "specwright-tester.md")
_RESTRICTED_FIELDS = ["operator", "location", "before/after", "defect category", "action"]
_T3_FLOOR = ["hardcoded returns", "partial implementations", "boundary skips"]


class TestTierVocabularyAlignment(unittest.TestCase):
    """AC-6: gate-tests and tester stay aligned on the tier vocabulary."""

    def setUp(self):
        self.gate = load_text(_GATE_TESTS_PATH)
        self.tester = load_text(_TESTER_PATH)

    def test_both_surfaces_name_t1_t2_t3_in_order(self):
        for content in (self.gate, self.tester):
            assert_multiline_regex(
                self,
                content,
                r"T1.+T2.+T3",
            )

    def test_both_surfaces_preserve_the_t3_floor_classes(self):
        for surface, content in (("gate", self.gate.lower()), ("tester", self.tester.lower())):
            for label in _T3_FLOOR:
                with self.subTest(surface=surface, label=label):
                    self.assertIn(label, content)


class TestRestrictedSurvivorFormatAlignment(unittest.TestCase):
    """AC-6: verify-time survivor details stay restricted and aligned."""

    def setUp(self):
        self.gate = load_text(_GATE_TESTS_PATH).lower()
        self.tester = load_text(_TESTER_PATH).lower()

    def test_gate_tests_names_the_restricted_survivor_fields(self):
        assert_multiline_regex(
            self,
            self.gate,
            r"survivor details?.+operator.+location.+before/after.+defect category.+action",
        )

    def test_tester_names_the_same_restricted_survivor_fields(self):
        assert_multiline_regex(
            self,
            self.tester,
            r"operator.+location.+before/after.+defect category.+action",
        )

    def test_tester_still_excludes_test_bodies_and_assertion_literals(self):
        assert_multiline_regex(
            self,
            self.tester,
            r"no test bodies?.+no assertion literals|no assertion literals.+no test bodies?",
        )


if __name__ == "__main__":
    unittest.main()
