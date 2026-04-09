"""Tests for evals.framework.grader — check functions and grading orchestration.

RED phase: all tests must fail because the implementation is stubbed.

Acceptance criteria covered:
  AC-13: check_file_exists(path, workdir) — passed=True when exists, False with evidence when not
  AC-14: check_file_not_exists(path, workdir) — passed=True when NOT exists, False when found
  AC-15: check_file_contains(path, pattern, workdir) — regex match, 200-char evidence on fail
  AC-16: check_tests_pass(command, workdir) — exit 0 = pass, non-zero = fail with last 500 chars
  AC-17: check_state(field, expected, workdir) — dotted path in workflow.json, error on missing
  AC-18: check_state_transition(expected_sequence, snapshots) — protocol table, >=2 snapshots
  AC-19: check_artifact_reference(source, target, check, workdir) — headings/ids extraction
  AC-20: check_git(check_type, workdir, **kwargs) — branch_exists, commit_count, no_uncommitted
  AC-21: check_gate_results(expected, workdir) — gates[name].status match
  AC-22: grade_eval(eval_case, workdir, snapshots) — orchestration, return structure, timing
  AC-23: model_grade expectation type returns passed=None, evidence="Skipped..."
"""

import json
import os
import shutil
import tempfile
import time
import unittest
from unittest.mock import patch, MagicMock

def _wrap_as_stream_json(text: str) -> str:
    """Wrap text in NDJSON stream-json format for model grader mocks."""
    event = {"type": "assistant", "message": {"content": [{"type": "text", "text": text}]}}
    return json.dumps(event) + "\n"


from evals.framework.grader import (
    CheckResult,
    VALID_TRANSITIONS,
    check_file_exists,
    check_file_not_exists,
    check_file_contains,
    check_file_not_contains,
    check_tests_pass,
    check_state,
    check_state_transition,
    check_artifact_reference,
    check_git,
    check_gate_results,
    check_transcript_final_block,
    grade_eval,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _assert_check_result(test_case, result, expected_passed, expected_type=None):
    """Assert common CheckResult structure and specific passed value."""
    test_case.assertIsInstance(result, CheckResult)
    test_case.assertIsInstance(result.type, str)
    test_case.assertTrue(len(result.type) > 0, "type must be non-empty")
    test_case.assertIsInstance(result.description, str)
    test_case.assertTrue(len(result.description) > 0, "description must be non-empty")
    test_case.assertIsInstance(result.evidence, str)
    test_case.assertIsInstance(result.score, float)
    if expected_passed is None:
        test_case.assertIsNone(result.passed)
    else:
        test_case.assertIs(result.passed, expected_passed)
    if expected_type is not None:
        test_case.assertEqual(result.type, expected_type)


def _make_workdir_with_file(filename, content=""):
    """Create a temp workdir containing a file with given content."""
    d = tempfile.mkdtemp()
    filepath = os.path.join(d, filename)
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w") as f:
        f.write(content)
    return d


def _make_workflow_json(workdir, data):
    """Write workflow.json inside workdir/.specwright/state/."""
    state_dir = os.path.join(workdir, ".specwright", "state")
    os.makedirs(state_dir, exist_ok=True)
    with open(os.path.join(state_dir, "workflow.json"), "w") as f:
        json.dump(data, f)


# ===========================================================================
# AC-13: check_file_exists
# ===========================================================================

class TestCheckFileExistsPass(unittest.TestCase):
    """AC-13: passed=True when file exists at workdir/path."""

    def setUp(self):
        self.workdir = _make_workdir_with_file("src/main.py", "print('hello')")

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_true_when_file_exists(self):
        result = check_file_exists("src/main.py", self.workdir)
        _assert_check_result(self, result, expected_passed=True)

    def test_score_is_1_when_file_exists(self):
        result = check_file_exists("src/main.py", self.workdir)
        self.assertEqual(result.score, 1.0)

    def test_type_is_file_exists(self):
        result = check_file_exists("src/main.py", self.workdir)
        self.assertEqual(result.type, "file_exists")


class TestCheckFileExistsFail(unittest.TestCase):
    """AC-13: passed=False with evidence when file does not exist."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_false_when_file_missing(self):
        result = check_file_exists("nonexistent.txt", self.workdir)
        _assert_check_result(self, result, expected_passed=False)

    def test_evidence_mentions_missing_path(self):
        result = check_file_exists("nonexistent.txt", self.workdir)
        self.assertIn("nonexistent.txt", result.evidence)

    def test_score_is_0_when_file_missing(self):
        result = check_file_exists("nonexistent.txt", self.workdir)
        self.assertEqual(result.score, 0.0)


class TestCheckFileExistsBoundary(unittest.TestCase):
    """AC-13: Edge cases for check_file_exists."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_directory_is_not_a_file(self):
        """A directory at the path should not count as file exists."""
        os.makedirs(os.path.join(self.workdir, "somedir"))
        result = check_file_exists("somedir", self.workdir)
        # Spec says "file exists" — a directory is not a file
        # This is intentionally ambiguous; accept either behavior but test
        # that we get a CheckResult back
        self.assertIsInstance(result, CheckResult)
        self.assertIn(result.passed, (True, False))

    def test_nested_path_that_exists(self):
        d = _make_workdir_with_file("deep/nested/file.txt", "content")
        result = check_file_exists("deep/nested/file.txt", d)
        self.assertTrue(result.passed)
        shutil.rmtree(d, ignore_errors=True)

    def test_uses_workdir_not_cwd(self):
        """File must be looked up relative to workdir, not process cwd."""
        d = _make_workdir_with_file("unique_marker_file.txt", "x")
        result = check_file_exists("unique_marker_file.txt", d)
        self.assertTrue(result.passed)
        # Same file should NOT be found relative to a different workdir
        other = tempfile.mkdtemp()
        result2 = check_file_exists("unique_marker_file.txt", other)
        self.assertFalse(result2.passed)
        shutil.rmtree(d, ignore_errors=True)
        shutil.rmtree(other, ignore_errors=True)


# ===========================================================================
# AC-14: check_file_not_exists
# ===========================================================================

class TestCheckFileNotExistsPass(unittest.TestCase):
    """AC-14: passed=True when file does NOT exist."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_true_when_file_absent(self):
        result = check_file_not_exists("should_not_exist.txt", self.workdir)
        _assert_check_result(self, result, expected_passed=True)

    def test_score_is_1_when_file_absent(self):
        result = check_file_not_exists("should_not_exist.txt", self.workdir)
        self.assertEqual(result.score, 1.0)

    def test_type_is_file_not_exists(self):
        result = check_file_not_exists("should_not_exist.txt", self.workdir)
        self.assertEqual(result.type, "file_not_exists")


class TestCheckFileNotExistsFail(unittest.TestCase):
    """AC-14: passed=False when file IS found."""

    def setUp(self):
        self.workdir = _make_workdir_with_file("unwanted.log", "log data")

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_false_when_file_found(self):
        result = check_file_not_exists("unwanted.log", self.workdir)
        _assert_check_result(self, result, expected_passed=False)

    def test_evidence_mentions_found_path(self):
        result = check_file_not_exists("unwanted.log", self.workdir)
        self.assertIn("unwanted.log", result.evidence)

    def test_score_is_0_when_file_found(self):
        result = check_file_not_exists("unwanted.log", self.workdir)
        self.assertEqual(result.score, 0.0)


# ===========================================================================
# AC-15: check_file_contains
# ===========================================================================

class TestCheckFileContainsPass(unittest.TestCase):
    """AC-15: passed=True when pattern matches file content via re.search."""

    def setUp(self):
        self.workdir = _make_workdir_with_file(
            "config.yaml", "version: 2.0\nname: specwright\n"
        )

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_true_on_literal_match(self):
        result = check_file_contains("config.yaml", "version: 2.0", self.workdir)
        _assert_check_result(self, result, expected_passed=True)

    def test_returns_passed_true_on_regex_match(self):
        result = check_file_contains("config.yaml", r"version:\s+\d+\.\d+", self.workdir)
        self.assertTrue(result.passed)

    def test_score_is_1_on_match(self):
        result = check_file_contains("config.yaml", "specwright", self.workdir)
        self.assertEqual(result.score, 1.0)

    def test_type_is_file_contains(self):
        result = check_file_contains("config.yaml", "version", self.workdir)
        self.assertEqual(result.type, "file_contains")


class TestCheckFileContainsFail(unittest.TestCase):
    """AC-15: passed=False with first 200 chars of content on fail."""

    def setUp(self):
        self.content = "A" * 300
        self.workdir = _make_workdir_with_file("big.txt", self.content)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_false_when_pattern_not_found(self):
        result = check_file_contains("big.txt", "ZZZNOTHERE", self.workdir)
        _assert_check_result(self, result, expected_passed=False)

    def test_evidence_shows_first_200_chars_on_fail(self):
        result = check_file_contains("big.txt", "ZZZNOTHERE", self.workdir)
        # Evidence must include file content but truncated to 200 chars
        self.assertIn("A" * 200, result.evidence)
        # Must NOT contain the full 300 chars
        self.assertNotIn("A" * 300, result.evidence)

    def test_evidence_truncation_at_exactly_200(self):
        """Content portion in evidence must be at most 200 characters."""
        result = check_file_contains("big.txt", "ZZZNOTHERE", self.workdir)
        # The evidence might contain additional context text (like "Content: ..."),
        # but the file content portion must be truncated to 200 chars.
        # We check that 201 consecutive A's do NOT appear.
        self.assertNotIn("A" * 201, result.evidence)

    def test_score_is_0_on_no_match(self):
        result = check_file_contains("big.txt", "ZZZNOTHERE", self.workdir)
        self.assertEqual(result.score, 0.0)


class TestCheckFileContainsBoundary(unittest.TestCase):
    """AC-15: Edge cases for check_file_contains."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_failed_when_file_missing(self):
        result = check_file_contains("missing.txt", "anything", self.workdir)
        self.assertFalse(result.passed)

    def test_evidence_mentions_file_not_found(self):
        result = check_file_contains("missing.txt", "anything", self.workdir)
        self.assertTrue(
            "not found" in result.evidence.lower() or "missing" in result.evidence.lower()
            or "no such" in result.evidence.lower() or "does not exist" in result.evidence.lower(),
            f"Evidence should mention file not found, got: {result.evidence}",
        )

    def test_empty_file_does_not_match_nonempty_pattern(self):
        d = _make_workdir_with_file("empty.txt", "")
        result = check_file_contains("empty.txt", "something", d)
        self.assertFalse(result.passed)
        shutil.rmtree(d, ignore_errors=True)

    def test_multiline_content_matches_across_lines(self):
        """re.search with DOTALL or multiline should find patterns spanning lines."""
        d = _make_workdir_with_file("multi.txt", "line1\nline2\nline3")
        # Pattern that just matches within one line should work
        result = check_file_contains("multi.txt", "line2", d)
        self.assertTrue(result.passed)
        shutil.rmtree(d, ignore_errors=True)


# ===========================================================================
# check_file_not_contains
# ===========================================================================

class TestCheckFileNotContains(unittest.TestCase):
    """Tests for check_file_not_contains — inverse of check_file_contains."""

    def test_passed_when_pattern_absent(self):
        d = _make_workdir_with_file("clean.txt", "no secrets here")
        result = check_file_not_contains("clean.txt", "CWE-636", d)
        self.assertTrue(result.passed)
        self.assertEqual(result.score, 1.0)
        shutil.rmtree(d, ignore_errors=True)

    def test_failed_when_pattern_present(self):
        d = _make_workdir_with_file("dirty.txt", "Found CWE-636 vulnerability")
        result = check_file_not_contains("dirty.txt", "CWE-636", d)
        self.assertFalse(result.passed)
        self.assertEqual(result.score, 0.0)
        shutil.rmtree(d, ignore_errors=True)

    def test_failed_when_file_missing(self):
        d = tempfile.mkdtemp()
        result = check_file_not_contains("missing.txt", "anything", d)
        self.assertFalse(result.passed)
        shutil.rmtree(d, ignore_errors=True)

    def test_type_is_file_not_contains(self):
        d = _make_workdir_with_file("test.txt", "content")
        result = check_file_not_contains("test.txt", "missing", d)
        self.assertEqual(result.type, "file_not_contains")
        shutil.rmtree(d, ignore_errors=True)

    def test_regex_pattern_support(self):
        d = _make_workdir_with_file("test.txt", "error code 404")
        result = check_file_not_contains("test.txt", r"CWE-\d+", d)
        self.assertTrue(result.passed)
        shutil.rmtree(d, ignore_errors=True)


# ===========================================================================
# AC-16: check_tests_pass
# ===========================================================================

class TestCheckTestsPassSuccess(unittest.TestCase):
    """AC-16: passed=True when subprocess exits with 0."""

    @patch("evals.framework.grader.subprocess.run")
    def test_returns_passed_true_on_exit_0(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        result = check_tests_pass("pytest", "/tmp/workdir")
        _assert_check_result(self, result, expected_passed=True)

    @patch("evals.framework.grader.subprocess.run")
    def test_score_is_1_on_exit_0(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        result = check_tests_pass("pytest", "/tmp/workdir")
        self.assertEqual(result.score, 1.0)

    @patch("evals.framework.grader.subprocess.run")
    def test_type_is_tests_pass(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="ok", stderr="")
        result = check_tests_pass("pytest", "/tmp/workdir")
        self.assertEqual(result.type, "tests_pass")

    @patch("evals.framework.grader.subprocess.run")
    def test_runs_command_in_workdir(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        check_tests_pass("pytest -x", "/my/workdir")
        call_kwargs = mock_run.call_args[1]
        self.assertEqual(call_kwargs.get("cwd"), "/my/workdir")


class TestCheckTestsPassFail(unittest.TestCase):
    """AC-16: passed=False with last 500 chars on non-zero exit."""

    @patch("evals.framework.grader.subprocess.run")
    def test_returns_passed_false_on_exit_1(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stdout="FAIL", stderr="errors")
        result = check_tests_pass("pytest", "/tmp/workdir")
        _assert_check_result(self, result, expected_passed=False)

    @patch("evals.framework.grader.subprocess.run")
    def test_evidence_shows_last_500_chars(self, mock_run):
        long_output = "X" * 1000
        mock_run.return_value = MagicMock(returncode=1, stdout=long_output, stderr="")
        result = check_tests_pass("pytest", "/tmp/workdir")
        # Evidence must contain exactly the last 500 chars, not the full 1000
        self.assertIn("X" * 500, result.evidence)
        self.assertNotIn("X" * 501, result.evidence)

    @patch("evals.framework.grader.subprocess.run")
    def test_evidence_includes_stderr_on_failure(self, mock_run):
        mock_run.return_value = MagicMock(returncode=2, stdout="", stderr="segfault")
        result = check_tests_pass("pytest", "/tmp/workdir")
        # Evidence should include stderr content
        self.assertIn("segfault", result.evidence)

    @patch("evals.framework.grader.subprocess.run")
    def test_score_is_0_on_failure(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stdout="FAIL", stderr="")
        result = check_tests_pass("pytest", "/tmp/workdir")
        self.assertEqual(result.score, 0.0)


class TestCheckTestsPassBoundary(unittest.TestCase):
    """AC-16: Edge cases for check_tests_pass."""

    @patch("evals.framework.grader.subprocess.run")
    def test_different_commands_are_not_hardcoded(self, mock_run):
        """Must actually use the provided command."""
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        check_tests_pass("npm test", "/tmp/w1")
        cmd1 = mock_run.call_args[0][0] if mock_run.call_args[0] else str(mock_run.call_args)

        mock_run.reset_mock()
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        check_tests_pass("cargo test", "/tmp/w2")
        cmd2 = mock_run.call_args[0][0] if mock_run.call_args[0] else str(mock_run.call_args)

        self.assertNotEqual(str(cmd1), str(cmd2))

    @patch("evals.framework.grader.subprocess.run")
    def test_short_output_not_truncated(self, mock_run):
        """When output is under 500 chars, all of it should appear in evidence."""
        short = "short failure"
        mock_run.return_value = MagicMock(returncode=1, stdout=short, stderr="")
        result = check_tests_pass("pytest", "/tmp/workdir")
        self.assertIn("short failure", result.evidence)


# ===========================================================================
# AC-17: check_state
# ===========================================================================

class TestCheckStatePass(unittest.TestCase):
    """AC-17: passed=True when dotted path matches expected value."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        _make_workflow_json(self.workdir, {
            "version": "2.0",
            "currentWork": {
                "status": "building",
                "id": "feature-x",
            },
            "gates": {},
        })

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_true_on_match(self):
        result = check_state("currentWork.status", "building", self.workdir)
        _assert_check_result(self, result, expected_passed=True)

    def test_nested_dotted_path_lookup(self):
        result = check_state("currentWork.id", "feature-x", self.workdir)
        self.assertTrue(result.passed)

    def test_top_level_field_lookup(self):
        result = check_state("version", "2.0", self.workdir)
        self.assertTrue(result.passed)

    def test_score_is_1_on_match(self):
        result = check_state("currentWork.status", "building", self.workdir)
        self.assertEqual(result.score, 1.0)

    def test_type_is_state(self):
        result = check_state("currentWork.status", "building", self.workdir)
        self.assertEqual(result.type, "state")


class TestCheckStateFail(unittest.TestCase):
    """AC-17: passed=False when value does not match expected."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        _make_workflow_json(self.workdir, {
            "currentWork": {"status": "building"},
        })

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_false_on_mismatch(self):
        result = check_state("currentWork.status", "verifying", self.workdir)
        _assert_check_result(self, result, expected_passed=False)

    def test_evidence_shows_actual_value(self):
        result = check_state("currentWork.status", "verifying", self.workdir)
        self.assertIn("building", result.evidence)

    def test_score_is_0_on_mismatch(self):
        result = check_state("currentWork.status", "verifying", self.workdir)
        self.assertEqual(result.score, 0.0)


class TestCheckStateBoundary(unittest.TestCase):
    """AC-17: Error conditions for check_state."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_missing_workflow_json_returns_failed_result(self):
        """No workflow.json at all should return passed=False, not crash."""
        result = check_state("currentWork.status", "building", self.workdir)
        self.assertFalse(result.passed)

    def test_missing_workflow_json_evidence_explains_error(self):
        result = check_state("currentWork.status", "building", self.workdir)
        self.assertTrue(len(result.evidence) > 0)

    def test_missing_dotted_path_returns_failed_result(self):
        """Path exists in JSON but requested sub-path doesn't."""
        _make_workflow_json(self.workdir, {"currentWork": {"status": "building"}})
        result = check_state("currentWork.nonexistent.deep", "x", self.workdir)
        self.assertFalse(result.passed)

    def test_null_value_matches_none(self):
        """JSON null should match Python None."""
        _make_workflow_json(self.workdir, {"currentWork": None})
        result = check_state("currentWork", None, self.workdir)
        self.assertTrue(result.passed)

    def test_different_field_values_not_hardcoded(self):
        """Guards against returning True for any input."""
        _make_workflow_json(self.workdir, {"currentWork": {"status": "designing"}})
        result_match = check_state("currentWork.status", "designing", self.workdir)
        result_mismatch = check_state("currentWork.status", "building", self.workdir)
        self.assertTrue(result_match.passed)
        self.assertFalse(result_mismatch.passed)


# ===========================================================================
# AC-18: check_state_transition
# ===========================================================================

class TestCheckStateTransitionPass(unittest.TestCase):
    """AC-18: validates transitions against protocol table."""

    def test_valid_none_to_designing(self):
        snapshots = [
            {"workflow_state": None},
            {"workflow_state": {"currentWork": {"status": "designing"}}},
        ]
        result = check_state_transition([None, "designing"], snapshots)
        _assert_check_result(self, result, expected_passed=True)

    def test_valid_designing_to_planning(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "designing"}}},
            {"workflow_state": {"currentWork": {"status": "planning"}}},
        ]
        result = check_state_transition(["designing", "planning"], snapshots)
        self.assertTrue(result.passed)

    def test_valid_multi_step_sequence(self):
        snapshots = [
            {"workflow_state": None},
            {"workflow_state": {"currentWork": {"status": "designing"}}},
            {"workflow_state": {"currentWork": {"status": "planning"}}},
            {"workflow_state": {"currentWork": {"status": "building"}}},
        ]
        result = check_state_transition(
            [None, "designing", "planning", "building"], snapshots
        )
        self.assertTrue(result.passed)

    def test_valid_verifying_to_shipped(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "verifying"}}},
            {"workflow_state": {"currentWork": {"status": "shipped"}}},
        ]
        result = check_state_transition(["verifying", "shipped"], snapshots)
        self.assertTrue(result.passed)

    def test_score_is_1_on_valid_transition(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "building"}}},
            {"workflow_state": {"currentWork": {"status": "verifying"}}},
        ]
        result = check_state_transition(["building", "verifying"], snapshots)
        self.assertEqual(result.score, 1.0)

    def test_type_is_state_transition(self):
        snapshots = [
            {"workflow_state": None},
            {"workflow_state": {"currentWork": {"status": "designing"}}},
        ]
        result = check_state_transition([None, "designing"], snapshots)
        self.assertEqual(result.type, "state_transition")


class TestCheckStateTransitionFail(unittest.TestCase):
    """AC-18: Invalid transitions return passed=False."""

    def test_invalid_designing_to_verifying(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "designing"}}},
            {"workflow_state": {"currentWork": {"status": "verifying"}}},
        ]
        result = check_state_transition(["designing", "verifying"], snapshots)
        self.assertFalse(result.passed)

    def test_invalid_building_to_shipped_skips_verifying(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "building"}}},
            {"workflow_state": {"currentWork": {"status": "shipped"}}},
        ]
        result = check_state_transition(["building", "shipped"], snapshots)
        self.assertFalse(result.passed)

    def test_invalid_planning_to_designing_is_not_in_table(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "planning"}}},
            {"workflow_state": {"currentWork": {"status": "designing"}}},
        ]
        result = check_state_transition(["planning", "designing"], snapshots)
        self.assertFalse(result.passed)

    def test_evidence_shows_invalid_transition(self):
        snapshots = [
            {"workflow_state": {"currentWork": {"status": "designing"}}},
            {"workflow_state": {"currentWork": {"status": "shipped"}}},
        ]
        result = check_state_transition(["designing", "shipped"], snapshots)
        # Evidence should mention the invalid pair
        self.assertIn("designing", result.evidence)
        self.assertIn("shipped", result.evidence)


class TestCheckStateTransitionBoundary(unittest.TestCase):
    """AC-18: Edge cases for check_state_transition."""

    def test_fewer_than_2_snapshots_fails(self):
        result = check_state_transition(["designing"], [{"workflow_state": None}])
        self.assertFalse(result.passed)

    def test_empty_snapshots_fails(self):
        result = check_state_transition([], [])
        self.assertFalse(result.passed)

    def test_sequence_length_must_match_snapshots(self):
        """Mismatch between expected_sequence and snapshots count should fail."""
        snapshots = [
            {"workflow_state": None},
            {"workflow_state": {"currentWork": {"status": "designing"}}},
        ]
        # 3 expected but only 2 snapshots
        result = check_state_transition(
            [None, "designing", "planning"], snapshots
        )
        self.assertFalse(result.passed)

    def test_actual_snapshot_status_must_match_expected(self):
        """Even if transitions are valid, actual status must match expected."""
        snapshots = [
            {"workflow_state": None},
            {"workflow_state": {"currentWork": {"status": "planning"}}},
        ]
        # None->planning is NOT valid
        result = check_state_transition([None, "planning"], snapshots)
        self.assertFalse(result.passed)

    def test_valid_transitions_constant_matches_spec(self):
        """Verify the VALID_TRANSITIONS set matches the spec exactly."""
        expected = {
            (None, "designing"),
            ("designing", "planning"),
            ("designing", "building"),
            ("planning", "building"),
            ("building", "verifying"),
            ("verifying", "building"),
            ("verifying", "shipped"),
            ("shipped", "building"),
        }
        self.assertEqual(VALID_TRANSITIONS, expected)


# ===========================================================================
# AC-19: check_artifact_reference
# ===========================================================================

class TestCheckArtifactReferenceHeadings(unittest.TestCase):
    """AC-19: headings_referenced extracts ## headings from source, checks target."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        # Source has headings (design.md is the source of headings)
        source_content = "## Architecture\n\nSome text.\n\n## Security\n\nMore text.\n"
        os.makedirs(os.path.join(self.workdir, "docs"), exist_ok=True)
        with open(os.path.join(self.workdir, "docs", "design.md"), "w") as f:
            f.write(source_content)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_pass_when_target_references_all_headings(self):
        target_content = "Refs Architecture and Security sections.\n"
        with open(os.path.join(self.workdir, "spec.md"), "w") as f:
            f.write(target_content)
        result = check_artifact_reference(
            "docs/design.md", "spec.md", "headings_referenced", self.workdir
        )
        _assert_check_result(self, result, expected_passed=True)

    def test_fail_when_target_references_no_headings(self):
        target_content = "Nothing relevant here.\n"
        with open(os.path.join(self.workdir, "spec.md"), "w") as f:
            f.write(target_content)
        result = check_artifact_reference(
            "docs/design.md", "spec.md", "headings_referenced", self.workdir
        )
        self.assertFalse(result.passed)

    def test_type_is_artifact_reference(self):
        with open(os.path.join(self.workdir, "spec.md"), "w") as f:
            f.write("Architecture Security")
        result = check_artifact_reference(
            "docs/design.md", "spec.md", "headings_referenced", self.workdir
        )
        self.assertEqual(result.type, "artifact_reference")


class TestCheckArtifactReferenceIds(unittest.TestCase):
    """AC-19: ids_referenced extracts AC-\\d+ from source, checks target."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        # Source has the AC IDs (spec.md is the source of criteria)
        source_content = "AC-1: Do thing\nAC-2: Do other\nAC-15: Complex\n"
        with open(os.path.join(self.workdir, "spec.md"), "w") as f:
            f.write(source_content)

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_pass_when_target_references_all_ids(self):
        target_content = "Covers AC-1, AC-2, and AC-15.\n"
        with open(os.path.join(self.workdir, "plan.md"), "w") as f:
            f.write(target_content)
        result = check_artifact_reference(
            "spec.md", "plan.md", "ids_referenced", self.workdir
        )
        self.assertTrue(result.passed)

    def test_fail_when_target_misses_some_ids(self):
        target_content = "Only covers AC-1.\n"
        with open(os.path.join(self.workdir, "plan.md"), "w") as f:
            f.write(target_content)
        result = check_artifact_reference(
            "spec.md", "plan.md", "ids_referenced", self.workdir
        )
        self.assertFalse(result.passed)

    def test_evidence_shows_missing_ids(self):
        target_content = "Only covers AC-1.\n"
        with open(os.path.join(self.workdir, "plan.md"), "w") as f:
            f.write(target_content)
        result = check_artifact_reference(
            "spec.md", "plan.md", "ids_referenced", self.workdir
        )
        # Evidence should mention AC-2 and AC-15 as missing
        self.assertIn("AC-2", result.evidence)
        self.assertIn("AC-15", result.evidence)


class TestCheckArtifactReferenceBoundary(unittest.TestCase):
    """AC-19: Edge cases for check_artifact_reference."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_zero_refs_in_source_is_fail(self):
        """If source has no headings/ids to extract, result is fail."""
        with open(os.path.join(self.workdir, "source.md"), "w") as f:
            f.write("No headings or IDs here.\n")
        with open(os.path.join(self.workdir, "target.md"), "w") as f:
            f.write("Some content.\n")
        result = check_artifact_reference(
            "source.md", "target.md", "headings_referenced", self.workdir
        )
        self.assertFalse(result.passed)

    def test_missing_source_file_fails(self):
        with open(os.path.join(self.workdir, "target.md"), "w") as f:
            f.write("content")
        result = check_artifact_reference(
            "missing_source.md", "target.md", "headings_referenced", self.workdir
        )
        self.assertFalse(result.passed)

    def test_missing_target_file_fails(self):
        with open(os.path.join(self.workdir, "source.md"), "w") as f:
            f.write("## Heading\n")
        result = check_artifact_reference(
            "source.md", "missing_target.md", "ids_referenced", self.workdir
        )
        self.assertFalse(result.passed)

    def test_zero_ids_in_source_is_fail(self):
        """Source with no AC-\\d+ patterns means nothing to reference."""
        with open(os.path.join(self.workdir, "source.md"), "w") as f:
            f.write("No acceptance criteria IDs.\n")
        with open(os.path.join(self.workdir, "target.md"), "w") as f:
            f.write("AC-1 mentioned but irrelevant.\n")
        result = check_artifact_reference(
            "source.md", "target.md", "ids_referenced", self.workdir
        )
        self.assertFalse(result.passed)


# ===========================================================================
# AC-20: check_git
# ===========================================================================

class TestCheckGitBranchExists(unittest.TestCase):
    """AC-20: check_git('branch_exists', ...) verifies branch existence."""

    @patch("evals.framework.grader.subprocess.run")
    def test_pass_when_branch_exists(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="ref/heads/feature\n", stderr="")
        result = check_git("branch_exists", "/tmp/workdir", branch="feature")
        _assert_check_result(self, result, expected_passed=True)

    @patch("evals.framework.grader.subprocess.run")
    def test_fail_when_branch_missing(self, mock_run):
        mock_run.return_value = MagicMock(returncode=1, stdout="", stderr="not found")
        result = check_git("branch_exists", "/tmp/workdir", branch="nonexistent")
        self.assertFalse(result.passed)

    @patch("evals.framework.grader.subprocess.run")
    def test_type_is_git(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        result = check_git("branch_exists", "/tmp/workdir", branch="main")
        self.assertEqual(result.type, "git")

    @patch("evals.framework.grader.subprocess.run")
    def test_uses_workdir_as_cwd(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        check_git("branch_exists", "/my/repo", branch="main")
        call_kwargs = mock_run.call_args[1]
        self.assertEqual(call_kwargs.get("cwd"), "/my/repo")


class TestCheckGitCommitCount(unittest.TestCase):
    """AC-20: check_git('commit_count', ...) verifies exact commit count."""

    @patch("evals.framework.grader.subprocess.run")
    def test_pass_when_count_matches_expected(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="5\n", stderr="")
        result = check_git("commit_count", "/tmp/workdir", expected=5)
        self.assertTrue(result.passed)

    @patch("evals.framework.grader.subprocess.run")
    def test_fail_when_count_below_expected(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="1\n", stderr="")
        result = check_git("commit_count", "/tmp/workdir", expected=5)
        self.assertFalse(result.passed)

    @patch("evals.framework.grader.subprocess.run")
    def test_fail_when_count_above_expected(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="8\n", stderr="")
        result = check_git("commit_count", "/tmp/workdir", expected=5)
        self.assertFalse(result.passed)

    @patch("evals.framework.grader.subprocess.run")
    def test_evidence_includes_actual_count(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="2\n", stderr="")
        result = check_git("commit_count", "/tmp/workdir", expected=5)
        self.assertIn("2", result.evidence)


class TestCheckGitNoUncommittedChanges(unittest.TestCase):
    """AC-20: check_git('no_uncommitted_changes', ...) verifies clean tree."""

    @patch("evals.framework.grader.subprocess.run")
    def test_pass_when_working_tree_clean(self, mock_run):
        mock_run.return_value = MagicMock(returncode=0, stdout="", stderr="")
        result = check_git("no_uncommitted_changes", "/tmp/workdir")
        self.assertTrue(result.passed)

    @patch("evals.framework.grader.subprocess.run")
    def test_fail_when_uncommitted_changes_exist(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0, stdout=" M src/main.py\n?? new.txt\n", stderr=""
        )
        result = check_git("no_uncommitted_changes", "/tmp/workdir")
        self.assertFalse(result.passed)

    @patch("evals.framework.grader.subprocess.run")
    def test_evidence_shows_dirty_files(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0, stdout=" M dirty.py\n", stderr=""
        )
        result = check_git("no_uncommitted_changes", "/tmp/workdir")
        self.assertIn("dirty.py", result.evidence)


# ===========================================================================
# AC-21: check_gate_results
# ===========================================================================

class TestCheckGateResultsPass(unittest.TestCase):
    """AC-21: passed=True when gates[name].status matches expected."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        _make_workflow_json(self.workdir, {
            "gates": {
                "lint": {"status": "PASS", "lastRun": "2026-01-01T00:00:00Z"},
                "test": {"status": "PASS", "lastRun": "2026-01-01T00:00:00Z"},
            },
        })

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_true_when_all_gates_match(self):
        result = check_gate_results(
            {"lint": "PASS", "test": "PASS"}, self.workdir
        )
        _assert_check_result(self, result, expected_passed=True)

    def test_score_is_1_when_all_match(self):
        result = check_gate_results({"lint": "PASS"}, self.workdir)
        self.assertEqual(result.score, 1.0)

    def test_type_is_gate_results(self):
        result = check_gate_results({"lint": "PASS"}, self.workdir)
        self.assertEqual(result.type, "gate_results")


class TestCheckGateResultsFail(unittest.TestCase):
    """AC-21: passed=False when gates[name].status does not match."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        _make_workflow_json(self.workdir, {
            "gates": {
                "lint": {"status": "PASS"},
                "test": {"status": "FAIL"},
            },
        })

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_passed_false_on_status_mismatch(self):
        result = check_gate_results({"test": "PASS"}, self.workdir)
        self.assertFalse(result.passed)

    def test_evidence_shows_mismatched_gate(self):
        result = check_gate_results({"test": "PASS"}, self.workdir)
        self.assertIn("test", result.evidence)
        self.assertIn("FAIL", result.evidence)

    def test_returns_passed_false_when_gate_missing(self):
        result = check_gate_results({"security": "PASS"}, self.workdir)
        self.assertFalse(result.passed)


class TestCheckGateResultsBoundary(unittest.TestCase):
    """AC-21: Edge cases for check_gate_results."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_missing_workflow_json_returns_failed(self):
        result = check_gate_results({"lint": "PASS"}, self.workdir)
        self.assertFalse(result.passed)

    def test_empty_gates_section_fails_when_expected_nonempty(self):
        _make_workflow_json(self.workdir, {"gates": {}})
        result = check_gate_results({"lint": "PASS"}, self.workdir)
        self.assertFalse(result.passed)

    def test_partial_match_is_still_fail(self):
        """If 2 gates expected but only 1 matches, result is fail."""
        _make_workflow_json(self.workdir, {
            "gates": {
                "lint": {"status": "PASS"},
                "test": {"status": "FAIL"},
            },
        })
        result = check_gate_results({"lint": "PASS", "test": "PASS"}, self.workdir)
        self.assertFalse(result.passed)


# ===========================================================================
# verdict/status compatibility
# ===========================================================================

class TestGateResultsVerdictStatus(unittest.TestCase):
    """check_gate_results reads verdict field with status fallback."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_reads_verdict_field(self):
        _make_workflow_json(self.workdir, {
            "gates": {"security": {"verdict": "FAIL"}},
        })
        result = check_gate_results({"security": "FAIL"}, self.workdir)
        self.assertTrue(result.passed)

    def test_falls_back_to_status_field(self):
        _make_workflow_json(self.workdir, {
            "gates": {"security": {"status": "PASS"}},
        })
        result = check_gate_results({"security": "PASS"}, self.workdir)
        self.assertTrue(result.passed)

    def test_verdict_takes_precedence_over_status(self):
        _make_workflow_json(self.workdir, {
            "gates": {"security": {"verdict": "FAIL", "status": "PASS"}},
        })
        result = check_gate_results({"security": "FAIL"}, self.workdir)
        self.assertTrue(result.passed)

    def test_verdict_mismatch_fails(self):
        _make_workflow_json(self.workdir, {
            "gates": {"security": {"verdict": "WARN"}},
        })
        result = check_gate_results({"security": "FAIL"}, self.workdir)
        self.assertFalse(result.passed)


# ===========================================================================
# AC-22: grade_eval
# ===========================================================================

class TestGradeEvalStructure(unittest.TestCase):
    """AC-22: grade_eval returns grading.json dict with expected structure."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        _make_workdir_with_file("target.py", "print('hello')")
        _make_workflow_json(self.workdir, {
            "currentWork": {"status": "building"},
            "gates": {},
        })

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_returns_dict_with_expectations_list(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "target.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertIsInstance(result, dict)
        self.assertIn("expectations", result)
        self.assertIsInstance(result["expectations"], list)

    def test_returns_dict_with_summary(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "target.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertIn("summary", result)
        summary = result["summary"]
        self.assertIn("total", summary)
        self.assertIn("passed", summary)
        self.assertIn("failed", summary)

    def test_returns_dict_with_timing(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "target.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertIn("timing", result)

    def test_expectations_count_matches_input(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "a.py"},
                {"type": "file_exists", "path": "b.py"},
                {"type": "file_exists", "path": "c.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertEqual(len(result["expectations"]), 3)

    def test_summary_total_equals_expectation_count(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "a.py"},
                {"type": "file_exists", "path": "b.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertEqual(result["summary"]["total"], 2)


class TestGradeEvalDispatch(unittest.TestCase):
    """AC-22: grade_eval dispatches to correct check functions."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        # Create files for the checks
        os.makedirs(os.path.join(self.workdir, ".specwright", "state"), exist_ok=True)
        with open(os.path.join(self.workdir, "exists.py"), "w") as f:
            f.write("content here")
        _make_workflow_json(self.workdir, {
            "currentWork": {"status": "building"},
            "gates": {"lint": {"status": "PASS"}},
        })

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_file_exists_expectation_dispatches_correctly(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "exists.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        exp = result["expectations"][0]
        self.assertTrue(exp["passed"])

    def test_file_exists_fail_dispatches_correctly(self):
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "nope.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        exp = result["expectations"][0]
        self.assertFalse(exp["passed"])

    def test_state_expectation_dispatches_correctly(self):
        eval_case = {
            "expectations": [
                {"type": "state", "field": "currentWork.status", "expected": "building"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        exp = result["expectations"][0]
        self.assertTrue(exp["passed"])

    def test_gate_results_expectation_dispatches_correctly(self):
        eval_case = {
            "expectations": [
                {"type": "gate_results", "expected": {"lint": "PASS"}},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        exp = result["expectations"][0]
        self.assertTrue(exp["passed"])

    def test_mixed_pass_and_fail(self):
        """Summary counts must reflect actual pass/fail results."""
        eval_case = {
            "expectations": [
                {"type": "file_exists", "path": "exists.py"},
                {"type": "file_exists", "path": "missing.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertEqual(result["summary"]["passed"], 1)
        self.assertEqual(result["summary"]["failed"], 1)


class TestGradeEvalTiming(unittest.TestCase):
    """AC-22: grade_eval includes timing information."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_timing_has_duration_field(self):
        eval_case = {"expectations": []}
        result = grade_eval(eval_case, self.workdir)
        timing = result.get("timing", {})
        # Should have some duration metric
        self.assertTrue(
            "duration_ms" in timing or "duration_s" in timing or "elapsed" in timing,
            f"timing must include a duration field, got: {timing}",
        )

    def test_timing_duration_is_numeric(self):
        eval_case = {"expectations": []}
        result = grade_eval(eval_case, self.workdir)
        timing = result.get("timing", {})
        duration_key = None
        for key in ("duration_ms", "duration_s", "elapsed"):
            if key in timing:
                duration_key = key
                break
        self.assertIsNotNone(duration_key, "Must have a duration field")
        self.assertIsInstance(timing[duration_key], (int, float))


class TestGradeEvalWithSnapshots(unittest.TestCase):
    """AC-22: grade_eval passes snapshots to state_transition checks."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_state_transition_with_valid_snapshots(self):
        snapshots = [
            {"workflow_state": None},
            {"workflow_state": {"currentWork": {"status": "designing"}}},
        ]
        eval_case = {
            "expectations": [
                {
                    "type": "state_transition",
                    "expected_sequence": [None, "designing"],
                },
            ],
        }
        result = grade_eval(eval_case, self.workdir, snapshots=snapshots)
        exp = result["expectations"][0]
        self.assertTrue(exp["passed"])


# ===========================================================================
# AC-23: model_grade expectation type skipped
# ===========================================================================

class TestModelGradeSkip(unittest.TestCase):
    """AC-23: model_grade falls back to skip when model_grader import fails."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_model_grade_delegates_to_model_grader(self, mock_run):
        """When model_grader is available, grade_eval delegates to it."""
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout='{"score": 0.9, "passed": true, "evidence": "Looks good"}',
            stderr="",
        )
        eval_case = {
            "expectations": [
                {"type": "model_grade", "rubric": "Is code good?", "target": "missing.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        exp = result["expectations"][0]
        self.assertEqual(exp["type"], "model_grade")
        # Model grader was invoked (not skipped)
        mock_run.assert_called_once()

    @patch("evals.framework.model_grader.subprocess.run")
    def test_model_grade_counts_as_pass_when_score_high(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=_wrap_as_stream_json('{"score": 0.9, "passed": true, "evidence": "Good"}'),
            stderr="",
        )
        eval_case = {
            "expectations": [
                {"type": "model_grade", "rubric": "Quality?", "target": "x.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertEqual(result["summary"]["passed"], 1)
        self.assertEqual(result["summary"]["failed"], 0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_model_grade_counts_as_fail_when_score_low(self, mock_run):
        mock_run.return_value = MagicMock(
            returncode=0,
            stdout=_wrap_as_stream_json('{"score": 0.3, "passed": false, "evidence": "Poor"}'),
            stderr="",
        )
        eval_case = {
            "expectations": [
                {"type": "model_grade", "rubric": "Quality?", "target": "x.py"},
            ],
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertEqual(result["summary"]["passed"], 0)
        self.assertEqual(result["summary"]["failed"], 1)

    def test_model_grade_counted_in_total(self):
        """model_grade expectations are always counted in total."""
        eval_case = {
            "expectations": [
                {"type": "model_grade", "rubric": "Check quality", "target": "x.py"},
            ],
        }
        with patch("evals.framework.model_grader.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=_wrap_as_stream_json('{"score": 0.9, "passed": true, "evidence": "OK"}'),
                stderr="",
            )
            result = grade_eval(eval_case, self.workdir)
        self.assertEqual(result["summary"]["total"], 1)


# ===========================================================================
# CheckResult contract
# ===========================================================================

class TestCheckResultContract(unittest.TestCase):
    """CheckResult must have all required fields with correct types."""

    def test_check_result_has_all_fields(self):
        r = CheckResult(
            type="test", description="desc", passed=True, evidence="ev", score=1.0
        )
        self.assertEqual(r.type, "test")
        self.assertEqual(r.description, "desc")
        self.assertTrue(r.passed)
        self.assertEqual(r.evidence, "ev")
        self.assertEqual(r.score, 1.0)

    def test_check_result_passed_can_be_none(self):
        r = CheckResult(type="model_grade", description="d", passed=None, evidence="e", score=0.0)
        self.assertIsNone(r.passed)

    def test_check_result_defaults(self):
        r = CheckResult()
        self.assertEqual(r.type, "")
        self.assertEqual(r.description, "")
        self.assertIsNone(r.passed)
        self.assertEqual(r.evidence, "")
        self.assertEqual(r.score, 0.0)


# ===========================================================================
# $TRANSCRIPT dispatch path
# ===========================================================================

class TestTranscriptDispatch(unittest.TestCase):
    """model_grade with $TRANSCRIPT target forwards transcript data correctly."""

    @patch("evals.framework.model_grader.grade_with_model")
    def test_transcript_target_passes_transcript(self, mock_grade):
        """When target is $TRANSCRIPT, the actual transcript should be forwarded."""
        mock_grade.return_value = CheckResult(
            type="model_grade", passed=True, evidence="ok", score=0.8
        )
        expectation = {
            "type": "model_grade",
            "rubric": "Check transcript quality",
            "target": "$TRANSCRIPT",
        }
        transcript = [{"type": "assistant", "content": "test data"}]
        workdir = tempfile.mkdtemp()
        try:
            from evals.framework.grader import _dispatch_expectation
            _dispatch_expectation(expectation, workdir, None, transcript=transcript)
            mock_grade.assert_called_once()
            call_kwargs = mock_grade.call_args
            self.assertIn("transcript", call_kwargs.kwargs)
            self.assertEqual(call_kwargs.kwargs["transcript"], transcript)
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    @patch("evals.framework.model_grader.grade_with_model")
    def test_transcript_target_falls_back_to_step_transcripts(self, mock_grade):
        """Chain evals should forward step transcripts when no final transcript is provided."""
        mock_grade.return_value = CheckResult(
            type="model_grade", passed=True, evidence="ok", score=0.8
        )
        expectation = {
            "type": "model_grade",
            "rubric": "Check transcript quality",
            "target": "$TRANSCRIPT",
        }
        step_transcripts = [[{"type": "assistant", "content": "step one"}]]
        workdir = tempfile.mkdtemp()
        try:
            from evals.framework.grader import _dispatch_expectation
            _dispatch_expectation(
                expectation,
                workdir,
                None,
                transcript=None,
                step_transcripts=step_transcripts,
            )
            call_kwargs = mock_grade.call_args
            self.assertEqual(call_kwargs.kwargs["transcript"], step_transcripts)
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    @patch("evals.framework.model_grader.grade_with_model")
    def test_transcript_target_prefers_step_transcripts_when_both_exist(self, mock_grade):
        """Chain evals should send the full step list even when final transcript exists."""
        mock_grade.return_value = CheckResult(
            type="model_grade", passed=True, evidence="ok", score=0.8
        )
        expectation = {
            "type": "model_grade",
            "rubric": "Check transcript quality",
            "target": "$TRANSCRIPT",
        }
        transcript = [{"type": "assistant", "content": "final"}]
        step_transcripts = [
            [{"type": "assistant", "content": "first"}],
            [{"type": "assistant", "content": "second"}],
        ]
        workdir = tempfile.mkdtemp()
        try:
            from evals.framework.grader import _dispatch_expectation
            _dispatch_expectation(
                expectation,
                workdir,
                None,
                transcript=transcript,
                step_transcripts=step_transcripts,
            )
            call_kwargs = mock_grade.call_args
            self.assertEqual(call_kwargs.kwargs["transcript"], step_transcripts)
        finally:
            shutil.rmtree(workdir, ignore_errors=True)

    @patch("evals.framework.model_grader.grade_with_model")
    def test_non_transcript_target_does_not_pass_snapshots(self, mock_grade):
        """When target is a file path, snapshots should NOT be forwarded."""
        mock_grade.return_value = CheckResult(
            type="model_grade", passed=True, evidence="ok", score=0.8
        )
        workdir = tempfile.mkdtemp()
        target_file = os.path.join(workdir, "report.md")
        with open(target_file, "w") as f:
            f.write("test content")
        try:
            expectation = {
                "type": "model_grade",
                "rubric": "Check quality",
                "target": "report.md",
            }
            snapshots = [{"event": "data"}]
            from evals.framework.grader import _dispatch_expectation
            _dispatch_expectation(expectation, workdir, snapshots)
            call_kwargs = mock_grade.call_args
            self.assertNotIn("transcript", call_kwargs.kwargs)
        finally:
            shutil.rmtree(workdir, ignore_errors=True)


# ===========================================================================
# AC-24: check_transcript_final_block — structural assertion on final output
#
# Used by Unit 01 of the legibility recovery to verify pipeline skills emit
# the three-line gate handoff format. Replaces the deferred AC-8 with a real
# automated check.
# ===========================================================================

def _make_result_event(text: str) -> dict:
    """Build a stream-json 'result' event with the given final text."""
    return {"type": "result", "result": text, "subtype": "success"}


def _make_assistant_text_event(text: str) -> dict:
    """Build a stream-json 'assistant' event with text-type content."""
    return {
        "type": "assistant",
        "message": {"content": [{"type": "text", "text": text}]},
    }


HANDOFF_PATTERNS = [
    r"^Done\.\s+.+\.$",
    r"^Artifacts:\s+.+/$",
    r"^Next:\s+/sw-[a-z\-]+$",
]

HANDOFF_FORBIDDEN = [
    "Decision Digest",
    "Quality Checks",
    "Deficiencies",
    "### Recommendation",
]


class TestExtractFinalAssistantText(unittest.TestCase):
    """The transcript-walking helper picks the right text source."""

    def test_returns_result_event_text_when_present(self):
        from evals.framework.grader import _extract_final_assistant_text
        transcript = [
            _make_assistant_text_event("intermediate work"),
            _make_result_event("final outcome\nArtifacts: x/\nNext: /sw-foo"),
        ]
        text = _extract_final_assistant_text(transcript)
        self.assertEqual(text, "final outcome\nArtifacts: x/\nNext: /sw-foo")

    def test_falls_back_to_last_assistant_text_when_no_result_event(self):
        from evals.framework.grader import _extract_final_assistant_text
        transcript = [
            _make_assistant_text_event("first"),
            _make_assistant_text_event("last"),
        ]
        self.assertEqual(_extract_final_assistant_text(transcript), "last")

    def test_returns_empty_string_for_empty_transcript(self):
        from evals.framework.grader import _extract_final_assistant_text
        self.assertEqual(_extract_final_assistant_text([]), "")

    def test_skips_result_event_with_empty_result_field(self):
        from evals.framework.grader import _extract_final_assistant_text
        transcript = [
            _make_assistant_text_event("the assistant message"),
            {"type": "result", "result": "", "subtype": "success"},
        ]
        self.assertEqual(_extract_final_assistant_text(transcript), "the assistant message")


class TestFinalNonEmptyBlock(unittest.TestCase):
    """The block-extraction helper isolates the trailing non-empty lines."""

    def test_simple_three_line_block(self):
        from evals.framework.grader import _final_non_empty_block
        text = "preamble\n\nDone. yes.\nArtifacts: x/\nNext: /sw-foo"
        self.assertEqual(
            _final_non_empty_block(text),
            ["Done. yes.", "Artifacts: x/", "Next: /sw-foo"],
        )

    def test_strips_trailing_whitespace(self):
        from evals.framework.grader import _final_non_empty_block
        text = "Done. yes.\nArtifacts: x/\nNext: /sw-foo\n\n  \n"
        self.assertEqual(
            _final_non_empty_block(text),
            ["Done. yes.", "Artifacts: x/", "Next: /sw-foo"],
        )

    def test_returns_empty_list_for_empty_text(self):
        from evals.framework.grader import _final_non_empty_block
        self.assertEqual(_final_non_empty_block(""), [])
        self.assertEqual(_final_non_empty_block("\n\n  \n"), [])

    def test_single_line_block(self):
        from evals.framework.grader import _final_non_empty_block
        self.assertEqual(_final_non_empty_block("only one line"), ["only one line"])

    def test_separates_blocks_by_blank_line(self):
        from evals.framework.grader import _final_non_empty_block
        text = "block one\nblock one continued\n\nblock two\n"
        self.assertEqual(_final_non_empty_block(text), ["block two"])


class TestCheckTranscriptFinalBlockHappyPath(unittest.TestCase):
    """Three-line handoff format is recognised cleanly."""

    def test_canonical_three_line_handoff_passes(self):
        transcript = [
            _make_result_event(
                "Some prose explaining the work...\n\n"
                "Done. Unit 01 verified.\n"
                "Artifacts: .specwright/work/foo/\n"
                "Next: /sw-ship"
            ),
        ]
        result = check_transcript_final_block(
            HANDOFF_PATTERNS, transcript, forbidden_substrings=HANDOFF_FORBIDDEN
        )
        _assert_check_result(self, result, expected_passed=True,
                             expected_type="transcript_final_block")
        self.assertEqual(result.score, 1.0)

    def test_handoff_in_assistant_event_when_no_result_event(self):
        transcript = [
            _make_assistant_text_event(
                "Done. shipped.\n"
                "Artifacts: .specwright/work/bar/\n"
                "Next: /sw-learn"
            ),
        ]
        result = check_transcript_final_block(HANDOFF_PATTERNS, transcript)
        self.assertTrue(result.passed)

    def test_passes_when_no_forbidden_substrings_specified(self):
        transcript = [
            _make_result_event(
                "Done. ok.\nArtifacts: x/\nNext: /sw-plan"
            )
        ]
        result = check_transcript_final_block(HANDOFF_PATTERNS, transcript)
        self.assertTrue(result.passed)


class TestCheckTranscriptFinalBlockFailure(unittest.TestCase):
    """Failure modes — every way the handoff can be wrong is caught."""

    def test_none_transcript_fails(self):
        result = check_transcript_final_block(HANDOFF_PATTERNS, None)
        self.assertFalse(result.passed)
        self.assertIn("None", result.evidence)

    def test_empty_transcript_fails(self):
        result = check_transcript_final_block(HANDOFF_PATTERNS, [])
        self.assertFalse(result.passed)
        self.assertIn("no extractable", result.evidence)

    def test_too_few_lines_fails(self):
        transcript = [
            _make_result_event("Done. yes.\nArtifacts: x/")
        ]
        result = check_transcript_final_block(HANDOFF_PATTERNS, transcript)
        self.assertFalse(result.passed)
        self.assertIn("Expected 3 lines", result.evidence)
        self.assertIn("got 2", result.evidence)

    def test_too_many_lines_fails(self):
        transcript = [
            _make_result_event(
                "Done. yes.\nArtifacts: x/\nNext: /sw-foo\nExtra rambling line."
            )
        ]
        result = check_transcript_final_block(HANDOFF_PATTERNS, transcript)
        self.assertFalse(result.passed)
        self.assertIn("got 4", result.evidence)

    def test_pattern_mismatch_on_first_line_fails(self):
        transcript = [
            _make_result_event(
                "Completed.\nArtifacts: x/\nNext: /sw-plan"
            )
        ]
        result = check_transcript_final_block(HANDOFF_PATTERNS, transcript)
        self.assertFalse(result.passed)
        self.assertIn("Line 1 does not match", result.evidence)

    def test_pattern_mismatch_on_artifacts_line_fails(self):
        transcript = [
            _make_result_event(
                "Done. ok.\nArtifacts: x\nNext: /sw-plan"  # missing trailing slash
            )
        ]
        result = check_transcript_final_block(HANDOFF_PATTERNS, transcript)
        self.assertFalse(result.passed)
        self.assertIn("Line 2", result.evidence)

    def test_forbidden_substring_anywhere_in_text_fails_even_if_block_matches(self):
        # The block IS the three-line format. But the preamble leaks
        # 'Decision Digest'. The check must catch this.
        transcript = [
            _make_result_event(
                "## Gate handoff\n"
                "### Decision Digest\n"
                "8 decisions\n\n"
                "Done. yes.\n"
                "Artifacts: x/\n"
                "Next: /sw-plan"
            )
        ]
        result = check_transcript_final_block(
            HANDOFF_PATTERNS, transcript, forbidden_substrings=HANDOFF_FORBIDDEN
        )
        self.assertFalse(result.passed)
        self.assertIn("Decision Digest", result.evidence)

    def test_multiple_forbidden_substrings_all_reported(self):
        transcript = [
            _make_result_event(
                "Quality Checks: ok\n"
                "### Recommendation: ship\n"
                "Done. ok.\nArtifacts: x/\nNext: /sw-plan"
            )
        ]
        result = check_transcript_final_block(
            HANDOFF_PATTERNS, transcript, forbidden_substrings=HANDOFF_FORBIDDEN
        )
        self.assertFalse(result.passed)
        self.assertIn("Quality Checks", result.evidence)
        self.assertIn("Recommendation", result.evidence)


class TestGradeEvalWithTranscript(unittest.TestCase):
    """grade_eval threads transcript through to transcript_final_block checks."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)

    def test_dispatch_passes_transcript_to_check(self):
        transcript = [
            _make_result_event(
                "Done. unit complete.\n"
                "Artifacts: .specwright/work/x/\n"
                "Next: /sw-verify"
            )
        ]
        eval_case = {
            "expectations": [
                {
                    "type": "transcript_final_block",
                    "line_patterns": HANDOFF_PATTERNS,
                    "forbidden_substrings": HANDOFF_FORBIDDEN,
                }
            ]
        }
        result = grade_eval(eval_case, self.workdir, transcript=transcript)
        self.assertEqual(result["summary"]["passed"], 1)
        self.assertEqual(result["summary"]["failed"], 0)
        self.assertTrue(result["expectations"][0]["passed"])

    def test_no_transcript_provided_fails_check(self):
        eval_case = {
            "expectations": [
                {
                    "type": "transcript_final_block",
                    "line_patterns": HANDOFF_PATTERNS,
                }
            ]
        }
        result = grade_eval(eval_case, self.workdir)
        self.assertEqual(result["summary"]["failed"], 1)


class TestSnapshotExpectations(unittest.TestCase):
    """Snapshot-aware expectations support per-step behavioral assertions."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.snapshot_dir = os.path.join(self.tmpdir, "snapshot-0")
        os.makedirs(os.path.join(self.snapshot_dir, ".specwright", "work", "test-work"), exist_ok=True)
        with open(
            os.path.join(self.snapshot_dir, ".specwright", "work", "test-work", "stage-report.md"),
            "w",
        ) as f:
            f.write("Attention required: none\n\n## Recommendation\n- Next\n")
        self.snapshots = [
            {
                "workflow_state": {"currentWork": {"status": "verifying"}},
                "snapshot_dir": self.snapshot_dir,
            }
        ]

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_snapshot_state_passes(self):
        from evals.framework.grader import check_snapshot_state
        result = check_snapshot_state("currentWork.status", "verifying", 0, self.snapshots)
        self.assertTrue(result.passed)

    def test_snapshot_state_supports_list_indexes(self):
        from evals.framework.grader import check_snapshot_state
        self.snapshots[0]["workflow_state"]["workUnits"] = [
            {"id": "u1", "status": "shipped", "prNumber": None},
            {"id": "u2", "status": "building", "prNumber": 157},
        ]
        result = check_snapshot_state("workUnits.0.status", "shipped", 0, self.snapshots)
        self.assertTrue(result.passed)

    def test_snapshot_state_reports_invalid_list_index(self):
        from evals.framework.grader import check_snapshot_state
        self.snapshots[0]["workflow_state"]["workUnits"] = [{"status": "shipped"}]
        result = check_snapshot_state("workUnits.4.status", "shipped", 0, self.snapshots)
        self.assertFalse(result.passed)
        self.assertIn("List index out of range", result.evidence)

    def test_snapshot_file_exists_passes(self):
        from evals.framework.grader import check_snapshot_file_exists
        result = check_snapshot_file_exists(
            ".specwright/work/test-work/stage-report.md",
            0,
            self.snapshots,
        )
        self.assertTrue(result.passed)

    def test_snapshot_file_contains_passes(self):
        from evals.framework.grader import check_snapshot_file_contains
        result = check_snapshot_file_contains(
            ".specwright/work/test-work/stage-report.md",
            r"^Attention required:",
            0,
            self.snapshots,
        )
        self.assertTrue(result.passed)

    def test_snapshot_file_line_count_lte_passes(self):
        from evals.framework.grader import check_snapshot_file_line_count_lte
        result = check_snapshot_file_line_count_lte(
            ".specwright/work/test-work/stage-report.md",
            10,
            0,
            self.snapshots,
        )
        self.assertTrue(result.passed)

    def test_snapshot_file_contains_rejects_path_traversal(self):
        from evals.framework.grader import check_snapshot_file_contains
        escaped_path = os.path.join(self.tmpdir, "escaped.txt")
        with open(escaped_path, "w") as f:
            f.write("outside\n")
        result = check_snapshot_file_contains("../escaped.txt", r"outside", 0, self.snapshots)
        self.assertFalse(result.passed)
        self.assertIn("escaped snapshot root", result.evidence)

    def test_snapshot_file_helpers_read_utf8_with_replacement(self):
        from evals.framework.grader import (
            check_snapshot_file_contains,
            check_snapshot_file_line_count_lte,
        )
        binary_path = os.path.join(
            self.snapshot_dir,
            ".specwright",
            "work",
            "test-work",
            "non-utf8.txt",
        )
        with open(binary_path, "wb") as f:
            f.write(b"alpha\xff\nbeta\n")

        contains_result = check_snapshot_file_contains(
            ".specwright/work/test-work/non-utf8.txt",
            r"alpha",
            0,
            self.snapshots,
        )
        line_count_result = check_snapshot_file_line_count_lte(
            ".specwright/work/test-work/non-utf8.txt",
            2,
            0,
            self.snapshots,
        )

        self.assertTrue(contains_result.passed)
        self.assertTrue(line_count_result.passed)


class TestStepTranscriptExpectations(unittest.TestCase):
    """Chain-step transcript expectations inspect intermediate skill behavior."""

    def test_step_transcript_contains_passes(self):
        from evals.framework.grader import check_step_transcript_contains
        transcripts = [[_make_result_event("Run /sw-status --repair 05-state-drift-and-stage-report")]]
        result = check_step_transcript_contains(0, r"sw-status --repair", transcripts)
        self.assertTrue(result.passed)

    def test_step_transcript_final_block_passes(self):
        from evals.framework.grader import check_step_transcript_final_block
        transcripts = [[
            _make_result_event(
                "Done. verified.\nArtifacts: .specwright/work/test/\nNext: /sw-ship"
            )
        ]]
        result = check_step_transcript_final_block(
            0,
            HANDOFF_PATTERNS,
            transcripts,
            forbidden_substrings=HANDOFF_FORBIDDEN,
        )
        self.assertTrue(result.passed)


if __name__ == "__main__":
    unittest.main()
