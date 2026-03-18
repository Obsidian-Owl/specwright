"""Tests for evals.framework.orchestrator.validate_suite schema validation.

RED phase: all tests must fail against the stub implementation.

This test suite covers:
  AC-1: Returns empty list for valid suites, non-empty list of error strings for invalid
  AC-2: Rejects unknown expectation types; error includes type + eval case ID
  AC-3: Rejects missing required fields per expectation type
  AC-4: Rejects eval cases without exactly one layer field (skill/sequence/workflow)
  AC-5: Rejects Layer 1 prompt_template not matching a prompts.py function
  AC-6: Rejects fixture seed paths that don't exist on disk
  AC-7: run_eval_suite calls validate_suite before execution; errors -> stderr, no run
  AC-8: --validate CLI flag runs validation only, prints OK or errors, exits 0/1

Done when all fail before implementation.
"""

import json
import os
import sys
import tempfile
import unittest
from unittest.mock import patch, MagicMock

from evals.framework.orchestrator import validate_suite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_EVALS_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The 10 registered expectation types per AC-2
REGISTERED_TYPES = [
    "file_exists", "file_not_exists", "file_contains", "tests_pass",
    "state", "state_transition", "artifact_reference", "git",
    "gate_results", "model_grade",
]

# The 6 registered prompt templates per AC-5
REGISTERED_TEMPLATES = ["init", "design", "plan", "build", "verify", "ship"]


def _write_suite(tmpdir, suite_data):
    """Write evals.json to tmpdir, return path."""
    path = os.path.join(tmpdir, "evals.json")
    with open(path, "w") as f:
        json.dump(suite_data, f)
    return path


def _valid_skill_case(case_id="test-case-1", expectations=None):
    """Build a minimal valid Layer 1 (skill) eval case."""
    if expectations is None:
        expectations = [
            {"type": "file_exists", "path": "src/main.ts", "description": "file exists"}
        ]
    return {
        "id": case_id,
        "skill": "sw-build",
        "prompt_template": "build",
        "prompt_args": {},
        "seed": {"type": "fixture", "path": ""},
        "expectations": expectations,
    }


def _valid_sequence_case(case_id="seq-case-1"):
    """Build a minimal valid Layer 2 (sequence) eval case."""
    return {
        "id": case_id,
        "sequence": ["sw-design", "sw-plan"],
        "prompt_args": {"problem_statement": "Add feature X"},
        "seed": {"type": "fixture", "path": ""},
        "expectations": [
            {"type": "state_transition", "expected_sequence": ["designing", "planning"],
             "description": "state transition"}
        ],
    }


def _valid_workflow_case(case_id="wf-case-1"):
    """Build a minimal valid Layer 3 (workflow) eval case."""
    return {
        "id": case_id,
        "workflow": ["sw-init", "sw-design", "sw-plan", "sw-build"],
        "prompt_args": {},
        "seed": {"type": "fixture", "path": ""},
        "expectations": [
            {"type": "file_exists", "path": ".specwright/config.json",
             "description": "config exists"}
        ],
    }


def _valid_suite(*cases):
    """Wrap cases in a suite envelope."""
    if not cases:
        cases = [_valid_skill_case()]
    return {"suite": "test", "version": "1.0", "evals": list(cases)}


# ---------------------------------------------------------------------------
# AC-1: Valid suites return empty list; invalid return non-empty error strings
# ---------------------------------------------------------------------------

class TestAC1ValidSuiteReturnsEmptyList(unittest.TestCase):
    """AC-1: Returns empty list when all evals are valid."""

    def test_valid_skill_case_returns_empty_list(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(_valid_skill_case()))
            errors = validate_suite(path)
            self.assertIsInstance(errors, list)
            self.assertEqual(errors, [], f"Expected no errors, got: {errors}")

    def test_valid_sequence_case_returns_empty_list(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(_valid_sequence_case()))
            errors = validate_suite(path)
            self.assertEqual(errors, [])

    def test_valid_workflow_case_returns_empty_list(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(_valid_workflow_case()))
            errors = validate_suite(path)
            self.assertEqual(errors, [])

    def test_multiple_valid_cases_returns_empty_list(self):
        suite = _valid_suite(
            _valid_skill_case("case-a"),
            _valid_sequence_case("case-b"),
            _valid_workflow_case("case-c"),
        )
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, suite)
            errors = validate_suite(path)
            self.assertEqual(errors, [])

    def test_errors_are_descriptive_strings(self):
        """When errors exist, each is a string that references the invalid input."""
        with tempfile.TemporaryDirectory() as tmpdir:
            bad_case = _valid_skill_case(case_id="str-check")
            bad_case["expectations"] = [{"type": "bogus_type", "description": "x"}]
            path = _write_suite(tmpdir, _valid_suite(bad_case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) > 0, "Expected errors for bogus type")
            for err in errors:
                self.assertIsInstance(err, str, f"Error must be string, got {type(err)}")
            combined = " ".join(errors)
            self.assertIn("bogus_type", combined,
                          f"Error strings should reference the invalid type: {errors}")

    def test_suite_with_all_expectation_types_valid(self):
        """A case using every registered type with correct fields is valid."""
        expectations = [
            {"type": "file_exists", "path": "a.txt", "description": "d"},
            {"type": "file_not_exists", "path": "b.txt", "description": "d"},
            {"type": "file_contains", "path": "c.txt", "pattern": "x", "description": "d"},
            {"type": "tests_pass", "command": "npm test", "description": "d"},
            {"type": "state", "field": "status", "expected": "done", "description": "d"},
            {"type": "state_transition", "expected_sequence": ["a", "b"], "description": "d"},
            {"type": "artifact_reference", "source": "a.md", "target": "b.md",
             "check": "headings_referenced", "description": "d"},
            {"type": "git", "check_type": "branch_exists", "description": "d"},
            {"type": "gate_results", "expected": {"test": "pass"}, "description": "d"},
            {"type": "model_grade", "rubric": "Is it good?", "description": "d"},
        ]
        case = _valid_skill_case(expectations=expectations)
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertEqual(errors, [], f"Expected no errors, got: {errors}")


# ---------------------------------------------------------------------------
# AC-2: Rejects unknown expectation types
# ---------------------------------------------------------------------------

class TestAC2RejectsUnknownExpectationTypes(unittest.TestCase):
    """AC-2: Unknown expectation types produce errors mentioning type + case ID."""

    def test_single_unknown_type_produces_error_with_type_and_id(self):
        case = _valid_skill_case(case_id="eval-abc")
        case["expectations"] = [{"type": "magic_check", "description": "x"}]
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1, "Expected at least one error")
            combined = " ".join(errors)
            self.assertIn("magic_check", combined,
                          f"Error should mention the invalid type: {errors}")
            self.assertIn("eval-abc", combined,
                          f"Error should mention the case ID: {errors}")

    def test_error_mentions_invalid_type_name(self):
        case = _valid_skill_case(case_id="eval-xyz")
        case["expectations"] = [{"type": "unicorn_check", "description": "x"}]
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            found = any("unicorn_check" in e for e in errors)
            self.assertTrue(found, f"Error should mention 'unicorn_check', got: {errors}")

    def test_error_mentions_eval_case_id(self):
        case = _valid_skill_case(case_id="my-special-case")
        case["expectations"] = [{"type": "not_real", "description": "x"}]
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            found = any("my-special-case" in e for e in errors)
            self.assertTrue(found, f"Error should mention case ID, got: {errors}")

    def test_multiple_unknown_types_each_produce_error(self):
        case = _valid_skill_case(case_id="multi-bad")
        case["expectations"] = [
            {"type": "fake_a", "description": "x"},
            {"type": "fake_b", "description": "x"},
        ]
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            has_a = any("fake_a" in e for e in errors)
            has_b = any("fake_b" in e for e in errors)
            self.assertTrue(has_a, f"Should mention fake_a: {errors}")
            self.assertTrue(has_b, f"Should mention fake_b: {errors}")

    def test_valid_type_among_unknown_only_flags_unknown(self):
        case = _valid_skill_case(case_id="mixed")
        case["expectations"] = [
            {"type": "file_exists", "path": "ok.txt", "description": "d"},
            {"type": "nonexistent_checker", "description": "d"},
        ]
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1)
            combined = " ".join(errors)
            self.assertIn("nonexistent_checker", combined,
                          f"Error should mention invalid type: {errors}")
            # Should NOT mention file_exists as an error
            file_exists_errors = [e for e in errors if "file_exists" in e and "nonexistent" not in e]
            self.assertEqual(file_exists_errors, [],
                             "file_exists is valid, should not appear as an error")


# ---------------------------------------------------------------------------
# AC-3: Rejects missing required fields per expectation type
# ---------------------------------------------------------------------------

class TestAC3RejectsMissingRequiredFields(unittest.TestCase):
    """AC-3: Each expectation type has required fields; missing ones produce errors."""

    def _assert_missing_field_error(self, exp_type, expectation, missing_field=None,
                                     case_id="missing-field-case"):
        case = _valid_skill_case(case_id=case_id, expectations=[expectation])
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for {exp_type} missing field, got none")
            combined = " ".join(errors)
            # Error must reference the case ID so the user knows which case is broken
            self.assertIn(case_id, combined,
                          f"Error should mention case ID '{case_id}': {errors}")
            # Error must mention the missing field or the expectation type
            if missing_field:
                self.assertIn(missing_field, combined,
                              f"Error should mention missing field '{missing_field}': {errors}")
            return errors

    def test_file_exists_missing_path(self):
        self._assert_missing_field_error("file_exists",
                                         {"type": "file_exists", "description": "d"},
                                         missing_field="path")

    def test_file_not_exists_missing_path(self):
        self._assert_missing_field_error("file_not_exists",
                                         {"type": "file_not_exists", "description": "d"},
                                         missing_field="path")

    def test_file_contains_missing_path(self):
        self._assert_missing_field_error("file_contains",
                                         {"type": "file_contains", "pattern": "x", "description": "d"},
                                         missing_field="path")

    def test_file_contains_missing_pattern(self):
        self._assert_missing_field_error("file_contains",
                                         {"type": "file_contains", "path": "a.txt", "description": "d"},
                                         missing_field="pattern")

    def test_file_contains_missing_both(self):
        errors = self._assert_missing_field_error(
            "file_contains", {"type": "file_contains", "description": "d"},
            missing_field="path")
        # Should report errors for BOTH missing fields
        self.assertTrue(len(errors) >= 2,
                        f"Expected >= 2 errors for two missing fields, got {len(errors)}: {errors}")
        combined = " ".join(errors)
        self.assertIn("pattern", combined,
                      f"Should also mention missing 'pattern': {errors}")

    def test_tests_pass_missing_command(self):
        self._assert_missing_field_error("tests_pass",
                                         {"type": "tests_pass", "description": "d"},
                                         missing_field="command")

    def test_state_missing_field(self):
        self._assert_missing_field_error("state",
                                         {"type": "state", "expected": "done", "description": "d"},
                                         missing_field="field")

    def test_state_missing_expected(self):
        self._assert_missing_field_error("state",
                                         {"type": "state", "field": "status", "description": "d"},
                                         missing_field="expected")

    def test_state_transition_missing_expected_sequence(self):
        self._assert_missing_field_error("state_transition",
                                         {"type": "state_transition", "description": "d"},
                                         missing_field="expected_sequence")

    def test_artifact_reference_missing_source(self):
        self._assert_missing_field_error("artifact_reference",
                                         {"type": "artifact_reference", "target": "b.md",
                                          "check": "headings_referenced", "description": "d"},
                                         missing_field="source")

    def test_artifact_reference_missing_target(self):
        self._assert_missing_field_error("artifact_reference",
                                         {"type": "artifact_reference", "source": "a.md",
                                          "check": "headings_referenced", "description": "d"},
                                         missing_field="target")

    def test_artifact_reference_missing_check(self):
        self._assert_missing_field_error("artifact_reference",
                                         {"type": "artifact_reference", "source": "a.md",
                                          "target": "b.md", "description": "d"},
                                         missing_field="check")

    def test_gate_results_missing_expected(self):
        self._assert_missing_field_error("gate_results",
                                         {"type": "gate_results", "description": "d"},
                                         missing_field="expected")

    def test_model_grade_missing_rubric(self):
        self._assert_missing_field_error("model_grade",
                                         {"type": "model_grade", "description": "d"},
                                         missing_field="rubric")


# ---------------------------------------------------------------------------
# AC-4: Rejects eval cases without exactly one layer field
# ---------------------------------------------------------------------------

class TestAC4RejectsInvalidLayerFields(unittest.TestCase):
    """AC-4: Each eval case must have exactly one of skill/sequence/workflow."""

    def test_no_layer_field_produces_error(self):
        case = {
            "id": "no-layer",
            "prompt_template": "build",
            "prompt_args": {},
            "seed": {"type": "fixture", "path": ""},
            "expectations": [
                {"type": "file_exists", "path": "a.txt", "description": "d"}
            ],
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1, f"Expected error for no layer field: {errors}")
            found = any("no-layer" in e for e in errors)
            self.assertTrue(found, f"Error should mention case ID 'no-layer': {errors}")

    def test_error_mentions_case_id_for_no_layer(self):
        case = {
            "id": "orphan-eval-42",
            "prompt_args": {},
            "seed": {"type": "fixture", "path": ""},
            "expectations": [
                {"type": "file_exists", "path": "a.txt", "description": "d"}
            ],
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            found = any("orphan-eval-42" in e for e in errors)
            self.assertTrue(found, f"Error should mention case ID: {errors}")

    def test_two_layer_fields_produces_error(self):
        case = {
            "id": "double-layer",
            "skill": "sw-build",
            "sequence": ["sw-design", "sw-plan"],
            "prompt_template": "build",
            "prompt_args": {},
            "seed": {"type": "fixture", "path": ""},
            "expectations": [
                {"type": "file_exists", "path": "a.txt", "description": "d"}
            ],
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for two layer fields: {errors}")
            found = any("double-layer" in e for e in errors)
            self.assertTrue(found, f"Error should mention 'double-layer': {errors}")

    def test_all_three_layer_fields_produces_error(self):
        case = {
            "id": "triple-layer",
            "skill": "sw-build",
            "sequence": ["sw-design", "sw-plan"],
            "workflow": ["sw-init", "sw-build"],
            "prompt_template": "build",
            "prompt_args": {},
            "seed": {"type": "fixture", "path": ""},
            "expectations": [
                {"type": "file_exists", "path": "a.txt", "description": "d"}
            ],
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for three layer fields: {errors}")
            found = any("triple-layer" in e for e in errors)
            self.assertTrue(found, f"Error should mention 'triple-layer': {errors}")

    def test_skill_and_workflow_produces_error(self):
        case = {
            "id": "skill-workflow",
            "skill": "sw-build",
            "workflow": ["sw-init"],
            "prompt_template": "build",
            "prompt_args": {},
            "seed": {"type": "fixture", "path": ""},
            "expectations": [
                {"type": "file_exists", "path": "a.txt", "description": "d"}
            ],
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for skill+workflow: {errors}")
            found = any("skill-workflow" in e for e in errors)
            self.assertTrue(found, f"Error should mention 'skill-workflow': {errors}")


# ---------------------------------------------------------------------------
# AC-5: Rejects Layer 1 prompt_template not matching prompts.py function
# ---------------------------------------------------------------------------

class TestAC5RejectsInvalidPromptTemplate(unittest.TestCase):
    """AC-5: Layer 1 evals must reference a registered prompt template."""

    def test_unknown_template_produces_error(self):
        case = _valid_skill_case(case_id="bad-template")
        case["prompt_template"] = "nonexistent_template"
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for unknown template: {errors}")
            combined = " ".join(errors)
            self.assertIn("nonexistent_template", combined,
                          f"Error should mention the bad template: {errors}")

    def test_error_mentions_template_name(self):
        case = _valid_skill_case(case_id="bad-tmpl-2")
        case["prompt_template"] = "deploy_rockets"
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            found = any("deploy_rockets" in e for e in errors)
            self.assertTrue(found, f"Error should mention template name: {errors}")

    def test_all_registered_templates_are_accepted(self):
        """Each of the 6 registered templates should be valid in a skill case."""
        for template in REGISTERED_TEMPLATES:
            case = _valid_skill_case(case_id=f"template-{template}")
            case["prompt_template"] = template
            case["skill"] = f"sw-{template}"
            with tempfile.TemporaryDirectory() as tmpdir:
                path = _write_suite(tmpdir, _valid_suite(case))
                errors = validate_suite(path)
                self.assertEqual(errors, [],
                                 f"Template '{template}' should be valid, got: {errors}")

    def test_empty_template_produces_error(self):
        case = _valid_skill_case(case_id="empty-tmpl")
        case["prompt_template"] = ""
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for empty template: {errors}")
            found = any("empty-tmpl" in e for e in errors)
            self.assertTrue(found, f"Error should mention case ID: {errors}")

    def test_sequence_case_does_not_require_prompt_template(self):
        """Layer 2/3 cases should not be validated for prompt_template."""
        case = _valid_sequence_case()
        # Deliberately no prompt_template field
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertEqual(errors, [],
                             f"Valid sequence case should produce no errors: {errors}")


# ---------------------------------------------------------------------------
# AC-6: Rejects fixture seed paths that don't exist on disk
# ---------------------------------------------------------------------------

class TestAC6RejectsNonexistentSeedPaths(unittest.TestCase):
    """AC-6: Fixture seeds with non-existent paths produce errors."""

    def test_nonexistent_fixture_path_produces_error(self):
        case = _valid_skill_case(case_id="bad-seed")
        case["seed"] = {
            "type": "fixture",
            "path": "suites/skill/fixtures/this-does-not-exist-anywhere-12345"
        }
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 1,
                            f"Expected error for nonexistent seed path: {errors}")
            combined = " ".join(errors)
            self.assertIn("bad-seed", combined,
                          f"Error should mention case ID: {errors}")

    def test_existing_fixture_path_produces_no_seed_error(self):
        """A fixture path that exists should not produce a seed-related error."""
        case = _valid_skill_case(case_id="good-seed")
        # Empty seed path means no fixture to check - should not error
        case["seed"] = {"type": "fixture", "path": ""}
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            self.assertEqual(errors, [],
                             f"Valid case with empty seed path should produce no errors: {errors}")

    def test_error_mentions_bad_path(self):
        bad_path = "suites/nonexistent/fixtures/unicorn-land"
        case = _valid_skill_case(case_id="path-err")
        case["seed"] = {"type": "fixture", "path": bad_path}
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case))
            errors = validate_suite(path)
            found = any(bad_path in e or "unicorn-land" in e for e in errors)
            self.assertTrue(found, f"Error should mention the bad path: {errors}")


# ---------------------------------------------------------------------------
# AC-7: run_eval_suite calls validate_suite before execution
# ---------------------------------------------------------------------------

class TestAC7RunEvalSuiteCallsValidation(unittest.TestCase):
    """AC-7: run_eval_suite validates before running; errors go to stderr, no run."""

    @patch("evals.framework.orchestrator.validate_suite")
    @patch("evals.framework.orchestrator.run_single_eval")
    def test_validation_errors_prevent_execution(self, mock_run, mock_validate):
        """When validate_suite returns errors, run_single_eval must not be called."""
        mock_validate.return_value = ["error: bad thing happened"]
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            from evals.framework.orchestrator import run_eval_suite
            run_eval_suite(path)
        mock_run.assert_not_called()

    @patch("evals.framework.orchestrator.validate_suite")
    @patch("evals.framework.orchestrator.run_single_eval")
    def test_validation_errors_printed_to_stderr(self, mock_run, mock_validate):
        """Validation errors should be printed to stderr."""
        mock_validate.return_value = ["error: field X missing in case Y"]
        import io
        captured = io.StringIO()
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            from evals.framework.orchestrator import run_eval_suite
            with patch("sys.stderr", captured):
                run_eval_suite(path)
        output = captured.getvalue()
        self.assertIn("field X missing", output,
                       f"Stderr should contain error text, got: {output}")

    @patch("evals.framework.orchestrator.validate_suite")
    @patch("evals.framework.orchestrator.ClaudeCodeRunner")
    def test_valid_suite_proceeds_to_execution(self, mock_runner_cls, mock_validate):
        """When validate_suite returns [], execution should proceed (validate was called)."""
        mock_validate.return_value = []
        mock_runner = MagicMock()
        mock_runner_cls.return_value = mock_runner
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            from evals.framework.orchestrator import run_eval_suite
            with patch("evals.framework.orchestrator.run_single_eval") as mock_run:
                with patch("evals.framework.orchestrator.aggregate_results", return_value={}):
                    run_eval_suite(path, results_dir=os.path.join(tmpdir, "results"))
            # validate_suite must have been called with the suite path
            mock_validate.assert_called_once_with(path)
            mock_run.assert_called()


# ---------------------------------------------------------------------------
# AC-8: --validate CLI flag
# ---------------------------------------------------------------------------

class TestAC8ValidateCLIFlag(unittest.TestCase):
    """AC-8: --validate flag runs validation only, prints OK or errors, exits 0/1."""

    @patch("evals.framework.orchestrator.validate_suite")
    def test_validate_flag_prints_ok_on_valid(self, mock_validate):
        mock_validate.return_value = []
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            import io
            captured = io.StringIO()
            from evals.__main__ import main
            with patch("sys.stdout", captured):
                try:
                    main(["--suite", path, "--validate"])
                except SystemExit as e:
                    self.assertEqual(e.code, 0, f"Expected exit 0, got {e.code}")
            self.assertIn("OK", captured.getvalue())

    @patch("evals.framework.orchestrator.validate_suite")
    def test_validate_flag_exits_1_on_errors(self, mock_validate):
        mock_validate.return_value = ["error: something wrong"]
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            from evals.__main__ import main
            with self.assertRaises(SystemExit) as ctx:
                main(["--suite", path, "--validate"])
            self.assertEqual(ctx.exception.code, 1)

    @patch("evals.framework.orchestrator.validate_suite")
    def test_validate_flag_prints_errors_on_invalid(self, mock_validate):
        mock_validate.return_value = ["error: missing field 'path'", "error: unknown type"]
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            import io
            captured_err = io.StringIO()
            captured_out = io.StringIO()
            from evals.__main__ import main
            with patch("sys.stderr", captured_err), patch("sys.stdout", captured_out):
                try:
                    main(["--suite", path, "--validate"])
                except SystemExit:
                    pass
            combined = captured_err.getvalue() + captured_out.getvalue()
            self.assertIn("missing field", combined,
                          f"Should print errors, got: {combined}")

    @patch("evals.framework.orchestrator.validate_suite")
    @patch("evals.framework.orchestrator.run_eval_suite")
    def test_validate_flag_does_not_run_suite(self, mock_run, mock_validate):
        """--validate should only validate, not run the suite."""
        mock_validate.return_value = []
        with tempfile.TemporaryDirectory() as tmpdir:
            suite = _valid_suite(_valid_skill_case())
            path = _write_suite(tmpdir, suite)
            from evals.__main__ import main
            try:
                main(["--suite", path, "--validate"])
            except SystemExit:
                pass
        # validate_suite must have been called (proving --validate is recognized)
        mock_validate.assert_called_once()
        mock_run.assert_not_called()


# ---------------------------------------------------------------------------
# Cross-cutting: compound validation (multiple errors in one suite)
# ---------------------------------------------------------------------------

class TestCompoundValidation(unittest.TestCase):
    """Multiple errors across different criteria should all be reported."""

    def test_multiple_errors_from_different_cases(self):
        """Two bad cases should produce at least two errors."""
        case1 = _valid_skill_case(case_id="bad-1")
        case1["expectations"] = [{"type": "fake_type", "description": "d"}]

        case2 = {
            "id": "bad-2",
            "prompt_args": {},
            "seed": {"type": "fixture", "path": ""},
            "expectations": [
                {"type": "file_exists", "path": "a.txt", "description": "d"}
            ],
        }  # no layer field

        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case1, case2))
            errors = validate_suite(path)
            self.assertTrue(len(errors) >= 2,
                            f"Expected >= 2 errors, got {len(errors)}: {errors}")

    def test_errors_reference_distinct_case_ids(self):
        """Each error should reference the specific case it belongs to."""
        case1 = _valid_skill_case(case_id="alpha-case")
        case1["expectations"] = [{"type": "unknown_1", "description": "d"}]

        case2 = _valid_skill_case(case_id="beta-case")
        case2["expectations"] = [{"type": "unknown_2", "description": "d"}]

        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, _valid_suite(case1, case2))
            errors = validate_suite(path)
            has_alpha = any("alpha-case" in e for e in errors)
            has_beta = any("beta-case" in e for e in errors)
            self.assertTrue(has_alpha, f"Should mention alpha-case: {errors}")
            self.assertTrue(has_beta, f"Should mention beta-case: {errors}")

    def test_empty_evals_list_is_valid(self):
        """A suite with no eval cases should be valid (nothing to fail)."""
        suite = {"suite": "test", "version": "1.0", "evals": []}
        with tempfile.TemporaryDirectory() as tmpdir:
            path = _write_suite(tmpdir, suite)
            errors = validate_suite(path)
            self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
