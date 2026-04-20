"""Tests for WU-03 Task 2: documentation surfaces stay aligned on mutation wording."""

import os
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_DOC_PATHS = {
    "root_claude": os.path.join(_REPO_ROOT, "CLAUDE.md"),
    "adapter_claude": os.path.join(_REPO_ROOT, "adapters", "claude-code", "CLAUDE.md"),
    "agents": os.path.join(_REPO_ROOT, "AGENTS.md"),
    "design": os.path.join(_REPO_ROOT, "DESIGN.md"),
}
_SIX_GATE_INVARIANT = "Six internal gates: build, tests, security, wiring, semantic, spec."


class TestMutationDocumentationSurfaces(unittest.TestCase):
    """AC-3: user-facing docs preserve the same gate and mutation story."""

    def test_every_surface_preserves_the_exact_six_gate_invariant(self):
        for label, path in _DOC_PATHS.items():
            with self.subTest(surface=label):
                self.assertIn(_SIX_GATE_INVARIANT, load_text(path))

    def test_every_surface_names_mutation_as_gate_tests_and_tester_capability(self):
        pattern = (
            r"mutation.+gate-tests.+specwright-tester|"
            r"gate-tests.+mutation.+specwright-tester|"
            r"gate-tests.+specwright-tester.+mutation|"
            r"specwright-tester.+mutation.+gate-tests|"
            r"specwright-tester.+gate-tests.+mutation"
        )
        for label, path in _DOC_PATHS.items():
            with self.subTest(surface=label):
                assert_multiline_regex(
                    self,
                    load_text(path).lower(),
                    pattern,
                )

    def test_every_surface_rules_out_a_separate_mutation_gate(self):
        pattern = r"not a new gate|not a separate gate|stays inside gate-tests|inside gate-tests"
        for label, path in _DOC_PATHS.items():
            with self.subTest(surface=label):
                assert_multiline_regex(
                    self,
                    load_text(path).lower(),
                    pattern,
                )


if __name__ == "__main__":
    unittest.main()
