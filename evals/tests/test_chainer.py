"""Tests for evals.framework.chainer — sequential skill execution.

AC-24: run_sequence invokes skills sequentially, captures snapshots between
AC-25: Stops chain on non-zero exit, sets failed_at
"""

import unittest
from unittest.mock import MagicMock, patch, call

from evals.framework.chainer import ChainResult, run_sequence
from evals.framework.runner import RunResult, ToolRunner


def _make_run_result(exit_code=0, stdout="", stderr="", transcript=None,
                     tokens=None, duration_ms=None):
    return RunResult(
        exit_code=exit_code,
        stdout=stdout,
        stderr=stderr,
        transcript=transcript or [],
        tokens=tokens,
        duration_ms=duration_ms,
    )


def _make_mock_runner(results=None):
    """Create a mock ToolRunner that returns sequential results."""
    runner = MagicMock(spec=ToolRunner)
    if results:
        runner.run_skill.side_effect = results
    else:
        runner.run_skill.return_value = _make_run_result()
    return runner


class TestRunSequenceBasic(unittest.TestCase):
    """AC-24: run_sequence invokes skills sequentially."""

    def test_invokes_each_skill_in_order(self):
        runner = _make_mock_runner([
            _make_run_result(), _make_run_result(), _make_run_result()
        ])
        prompts = {"a": "do a", "b": "do b", "c": "do c"}
        run_sequence(runner, ["a", "b", "c"], prompts, "/tmp/work")
        self.assertEqual(runner.run_skill.call_count, 3)

    def test_passes_correct_prompt_per_skill(self):
        runner = _make_mock_runner([_make_run_result(), _make_run_result()])
        prompts = {"design": "run design", "plan": "run plan"}
        run_sequence(runner, ["design", "plan"], prompts, "/tmp/work")
        calls = runner.run_skill.call_args_list
        self.assertEqual(calls[0][1].get("prompt") or calls[0][0][1], "run design")
        self.assertEqual(calls[1][1].get("prompt") or calls[1][0][1], "run plan")

    def test_returns_chain_result(self):
        runner = _make_mock_runner([_make_run_result()])
        result = run_sequence(runner, ["a"], {"a": "prompt"}, "/tmp/work")
        self.assertIsInstance(result, ChainResult)

    def test_steps_contains_all_run_results(self):
        r1 = _make_run_result(exit_code=0)
        r2 = _make_run_result(exit_code=0)
        runner = _make_mock_runner([r1, r2])
        result = run_sequence(runner, ["a", "b"], {"a": "p1", "b": "p2"}, "/tmp/work")
        self.assertEqual(len(result.steps), 2)

    def test_failed_at_is_none_on_success(self):
        runner = _make_mock_runner([_make_run_result()])
        result = run_sequence(runner, ["a"], {"a": "p"}, "/tmp/work")
        self.assertIsNone(result.failed_at)


class TestRunSequenceEmptySkills(unittest.TestCase):
    """AC-24: Empty skills list returns empty ChainResult."""

    def test_empty_skills_returns_empty_steps(self):
        runner = _make_mock_runner()
        result = run_sequence(runner, [], {}, "/tmp/work")
        self.assertEqual(result.steps, [])

    def test_empty_skills_returns_empty_snapshots(self):
        runner = _make_mock_runner()
        result = run_sequence(runner, [], {}, "/tmp/work")
        self.assertEqual(result.snapshots, [])

    def test_empty_skills_failed_at_is_none(self):
        runner = _make_mock_runner()
        result = run_sequence(runner, [], {}, "/tmp/work")
        self.assertIsNone(result.failed_at)


class TestRunSequenceSnapshots(unittest.TestCase):
    """AC-24: Captures snapshots between skills when capture_between=True."""

    @patch("evals.framework.chainer.capture_snapshot")
    def test_captures_snapshot_after_each_skill(self, mock_capture):
        mock_capture.return_value = {"workflow_state": None, "timestamp": "t"}
        runner = _make_mock_runner([_make_run_result(), _make_run_result()])
        result = run_sequence(
            runner, ["a", "b"], {"a": "p1", "b": "p2"}, "/tmp/work",
            capture_between=True,
        )
        self.assertEqual(mock_capture.call_count, 2)
        self.assertEqual(len(result.snapshots), 2)

    @patch("evals.framework.chainer.capture_snapshot")
    def test_no_snapshots_when_capture_between_false(self, mock_capture):
        runner = _make_mock_runner([_make_run_result()])
        result = run_sequence(
            runner, ["a"], {"a": "p"}, "/tmp/work",
            capture_between=False,
        )
        mock_capture.assert_not_called()
        self.assertEqual(result.snapshots, [])


class TestRunSequenceFailure(unittest.TestCase):
    """AC-25: Stops chain on non-zero exit, sets failed_at."""

    def test_stops_on_nonzero_exit(self):
        runner = _make_mock_runner([
            _make_run_result(exit_code=0),
            _make_run_result(exit_code=1),
            _make_run_result(exit_code=0),
        ])
        result = run_sequence(
            runner, ["a", "b", "c"], {"a": "p", "b": "p", "c": "p"}, "/tmp/work"
        )
        # Should have stopped after "b" — "c" never called
        self.assertEqual(runner.run_skill.call_count, 2)

    def test_failed_at_set_to_failing_skill(self):
        runner = _make_mock_runner([
            _make_run_result(exit_code=0),
            _make_run_result(exit_code=1),
        ])
        result = run_sequence(
            runner, ["a", "b", "c"], {"a": "p", "b": "p", "c": "p"}, "/tmp/work"
        )
        self.assertEqual(result.failed_at, "b")

    @patch("evals.framework.chainer.capture_snapshot")
    def test_captures_snapshots_up_to_failure(self, mock_capture):
        mock_capture.return_value = {"workflow_state": None, "timestamp": "t"}
        runner = _make_mock_runner([
            _make_run_result(exit_code=0),
            _make_run_result(exit_code=1),
        ])
        result = run_sequence(
            runner, ["a", "b", "c"], {"a": "p", "b": "p", "c": "p"}, "/tmp/work",
            capture_between=True,
        )
        self.assertEqual(len(result.snapshots), 2)
        self.assertEqual(len(result.steps), 2)

    def test_first_skill_failure_stops_immediately(self):
        runner = _make_mock_runner([_make_run_result(exit_code=1)])
        result = run_sequence(
            runner, ["a", "b"], {"a": "p", "b": "p"}, "/tmp/work"
        )
        self.assertEqual(runner.run_skill.call_count, 1)
        self.assertEqual(result.failed_at, "a")


if __name__ == "__main__":
    unittest.main()
