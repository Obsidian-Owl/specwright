"""Tests for evals.framework.model_grader — model-based grading via claude CLI.

RED phase: all tests must fail because the implementation is stubbed.

Acceptance criteria covered:
  AC-6: grade_with_model(rubric, target_content, transcript) invokes claude -p,
        parses JSON response (score, passed, evidence), handles failures.
  AC-7: Uses --max-turns 1. Prompt instructs JSON-only response, no preamble.
"""

import json
import subprocess
import unittest
from unittest.mock import patch, MagicMock

from evals.framework.grader import CheckResult
from evals.framework.model_grader import grade_with_model, _extract_json


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mock_run(stdout="", stderr="", returncode=0):
    """Return a MagicMock configured like subprocess.CompletedProcess."""
    result = MagicMock(spec=subprocess.CompletedProcess)
    result.stdout = stdout
    result.stderr = stderr
    result.returncode = returncode
    return result


def _wrap_as_stream_json(text: str) -> str:
    """Wrap a text response in NDJSON stream-json format matching claude -p output."""
    assistant_event = {
        "type": "assistant",
        "message": {
            "content": [
                {"type": "text", "text": text}
            ]
        }
    }
    result_event = {"type": "result", "duration_ms": 1000}
    return json.dumps(assistant_event) + "\n" + json.dumps(result_event) + "\n"


def _valid_model_response(score=0.85, evidence="Criteria met"):
    """Return NDJSON stream matching expected model grader output format."""
    response_json = json.dumps({
        "score": score,
        "evidence": evidence,
    })
    return _wrap_as_stream_json(response_json)


# ===========================================================================
# AC-6: Return type is CheckResult
# ===========================================================================

class TestGradeWithModelReturnsCheckResult(unittest.TestCase):
    """grade_with_model must return a CheckResult instance."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_returns_check_result_instance(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.9)
        )
        result = grade_with_model("rubric text", "target content")
        self.assertIsInstance(result, CheckResult)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_check_result_has_all_fields(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8, evidence="Looks good")
        )
        result = grade_with_model("rubric text", "target content")
        # Every CheckResult field must be populated, not left as default
        self.assertIsNotNone(result.type)
        self.assertIsNotNone(result.description)
        self.assertIsNotNone(result.passed)
        self.assertIsNotNone(result.evidence)
        self.assertIsNotNone(result.score)


# ===========================================================================
# AC-6: Score parsing and threshold (passed = score >= 0.7)
# ===========================================================================

class TestScoreThreshold(unittest.TestCase):
    """Score >= 0.7 means passed=True, below means passed=False."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_above_threshold_passes(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.85)
        )
        result = grade_with_model("check quality", "some content")
        self.assertTrue(result.passed)
        self.assertAlmostEqual(result.score, 0.85)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_exactly_at_threshold_passes(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.7)
        )
        result = grade_with_model("check quality", "some content")
        self.assertTrue(result.passed)
        self.assertAlmostEqual(result.score, 0.7)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_below_threshold_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.69)
        )
        result = grade_with_model("check quality", "some content")
        self.assertFalse(result.passed)
        self.assertAlmostEqual(result.score, 0.69)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_zero_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.0)
        )
        result = grade_with_model("check quality", "some content")
        self.assertFalse(result.passed)
        self.assertAlmostEqual(result.score, 0.0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_one_passes(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=1.0)
        )
        result = grade_with_model("check quality", "some content")
        self.assertTrue(result.passed)
        self.assertAlmostEqual(result.score, 1.0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_different_scores_produce_different_results(self, mock_run):
        """Guards against hardcoded score or passed values."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.5)
        )
        result_low = grade_with_model("rubric", "content")

        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.9)
        )
        result_high = grade_with_model("rubric", "content")

        self.assertFalse(result_low.passed)
        self.assertTrue(result_high.passed)
        self.assertNotAlmostEqual(result_low.score, result_high.score)


# ===========================================================================
# Custom threshold parameter
# ===========================================================================

class TestCustomThreshold(unittest.TestCase):
    """Custom threshold changes pass/fail determination."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_default_threshold_unchanged(self, mock_run):
        """Default behavior (0.7) is preserved when threshold not passed."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.69)
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_custom_threshold_lowers_bar(self, mock_run):
        """threshold=0.5 passes a 0.6 score that would fail at default 0.7."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.6)
        )
        result = grade_with_model("rubric", "content", threshold=0.5)
        self.assertTrue(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_custom_threshold_raises_bar(self, mock_run):
        """threshold=1.0 fails a 0.9 score that would pass at default 0.7."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.9)
        )
        result = grade_with_model("rubric", "content", threshold=1.0)
        self.assertFalse(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_exact_threshold_passes(self, mock_run):
        """Score exactly equal to custom threshold passes."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.5)
        )
        result = grade_with_model("rubric", "content", threshold=0.5)
        self.assertTrue(result.passed)


# ===========================================================================
# AC-6: Evidence extraction from model response
# ===========================================================================

class TestEvidenceExtraction(unittest.TestCase):
    """Evidence string from model JSON must appear in CheckResult.evidence."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_evidence_from_model_response_included(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8, evidence="All criteria met fully")
        )
        result = grade_with_model("rubric", "content")
        self.assertIn("All criteria met fully", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_different_evidence_strings_reflected(self, mock_run):
        """Guards against hardcoded evidence."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.4, evidence="Missing section headers")
        )
        result = grade_with_model("rubric", "content")
        self.assertIn("Missing section headers", result.evidence)

        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.9, evidence="Excellent coverage")
        )
        result2 = grade_with_model("rubric", "content")
        self.assertIn("Excellent coverage", result2.evidence)
        self.assertNotEqual(result.evidence, result2.evidence)


# ===========================================================================
# AC-6: Unparseable JSON response
# ===========================================================================

class TestUnparseableResponse(unittest.TestCase):
    """Unparseable model output must yield passed=False with specific message."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_non_json_response_fails(self, mock_run):
        """Non-NDJSON stdout has no assistant events — fails with no-text error."""
        mock_run.return_value = _mock_run(
            stdout="I think the score should be about 0.8"
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("no assistant text", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_non_json_response_includes_raw_output(self, mock_run):
        raw_text = "Here is my evaluation: good work"
        mock_run.return_value = _mock_run(stdout=_wrap_as_stream_json(raw_text))
        result = grade_with_model("rubric", "content")
        self.assertIn(raw_text, result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_partial_json_response_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json('{"score": 0.8, "evidence":')
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("unparseable response", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_json_missing_score_field_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json(json.dumps({"evidence": "looks fine"}))
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("unparseable response", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_json_missing_evidence_field_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json(json.dumps({"score": 0.9}))
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("unparseable response", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_empty_stdout_fails(self, mock_run):
        mock_run.return_value = _mock_run(stdout="")
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("no assistant text", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_json_with_preamble_text_now_parses(self, mock_run):
        """Model adds text before JSON -- _extract_json handles this."""
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json(
                'Here is my assessment:\n{"score": 0.8, "evidence": "ok"}'
            )
        )
        result = grade_with_model("rubric", "content")
        self.assertTrue(result.passed)
        self.assertAlmostEqual(result.score, 0.8)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_not_a_number_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json(
                json.dumps({"score": "high", "evidence": "great"})
            )
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("unparseable response", result.evidence)


# ===========================================================================
# AC-6: Claude failure (non-zero exit, timeout, binary not found)
# ===========================================================================

class TestClaudeFailure(unittest.TestCase):
    """Claude CLI failures must yield passed=False with failure description."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_nonzero_exit_code_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout="", stderr="Error: rate limited", returncode=1
        )
        result = grade_with_model("rubric", "content")
        self.assertIsInstance(result, CheckResult)
        self.assertFalse(result.passed)
        # Evidence must describe the failure, not be empty
        self.assertTrue(len(result.evidence) > 0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_nonzero_exit_includes_stderr_in_evidence(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout="", stderr="API key invalid", returncode=2
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)
        self.assertIn("API key invalid", result.evidence)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_timeout_fails(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(
            cmd="claude", timeout=30
        )
        result = grade_with_model("rubric", "content")
        self.assertIsInstance(result, CheckResult)
        self.assertFalse(result.passed)
        self.assertTrue(len(result.evidence) > 0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_binary_not_found_fails(self, mock_run):
        mock_run.side_effect = FileNotFoundError(
            "[Errno 2] No such file or directory: 'claude'"
        )
        result = grade_with_model("rubric", "content")
        self.assertIsInstance(result, CheckResult)
        self.assertFalse(result.passed)
        self.assertTrue(len(result.evidence) > 0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_nonzero_exit_score_is_zero(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout="", stderr="crash", returncode=1
        )
        result = grade_with_model("rubric", "content")
        self.assertAlmostEqual(result.score, 0.0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_timeout_score_is_zero(self, mock_run):
        mock_run.side_effect = subprocess.TimeoutExpired(
            cmd="claude", timeout=30
        )
        result = grade_with_model("rubric", "content")
        self.assertAlmostEqual(result.score, 0.0)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_binary_not_found_score_is_zero(self, mock_run):
        mock_run.side_effect = FileNotFoundError("claude not found")
        result = grade_with_model("rubric", "content")
        self.assertAlmostEqual(result.score, 0.0)


# ===========================================================================
# AC-7: Invocation uses --max-turns 1
# ===========================================================================

class TestMaxTurnsFlag(unittest.TestCase):
    """grade_with_model must pass --max-turns 1 to claude."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_command_includes_max_turns_1(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("rubric", "content")

        mock_run.assert_called_once()
        cmd = mock_run.call_args[0][0]
        self.assertIn("--max-turns", cmd)
        mt_idx = cmd.index("--max-turns")
        self.assertEqual(cmd[mt_idx + 1], "1")


# ===========================================================================
# AC-7: Prompt instructs JSON-only response
# ===========================================================================

class TestPromptStructure(unittest.TestCase):
    """The prompt sent to claude must contain rubric, target, JSON instruction."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_prompt_contains_rubric(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("Evaluate code quality and test coverage", "def foo(): pass")

        cmd = mock_run.call_args[0][0]
        self.assertIn("-p", cmd)
        p_idx = cmd.index("-p")
        prompt = cmd[p_idx + 1]
        self.assertIn("Evaluate code quality and test coverage", prompt)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_prompt_contains_target_content(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("any rubric", "TARGET_CONTENT_XYZ_12345")

        cmd = mock_run.call_args[0][0]
        p_idx = cmd.index("-p")
        prompt = cmd[p_idx + 1]
        self.assertIn("TARGET_CONTENT_XYZ_12345", prompt)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_prompt_instructs_json_only(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("rubric", "content")

        cmd = mock_run.call_args[0][0]
        p_idx = cmd.index("-p")
        prompt = cmd[p_idx + 1].lower()
        self.assertIn("json", prompt)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_prompt_different_rubrics_produce_different_prompts(self, mock_run):
        """Guards against hardcoded prompt text."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )

        grade_with_model("RUBRIC_ALPHA", "content")
        cmd1 = mock_run.call_args[0][0]
        p1 = cmd1[cmd1.index("-p") + 1]

        mock_run.reset_mock()
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )

        grade_with_model("RUBRIC_BETA", "content")
        cmd2 = mock_run.call_args[0][0]
        p2 = cmd2[cmd2.index("-p") + 1]

        self.assertNotEqual(p1, p2)
        self.assertIn("RUBRIC_ALPHA", p1)
        self.assertIn("RUBRIC_BETA", p2)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_prompt_different_targets_produce_different_prompts(self, mock_run):
        """Guards against hardcoded target content."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )

        grade_with_model("rubric", "CONTENT_AAA")
        p1 = mock_run.call_args[0][0][mock_run.call_args[0][0].index("-p") + 1]

        mock_run.reset_mock()
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )

        grade_with_model("rubric", "CONTENT_BBB")
        p2 = mock_run.call_args[0][0][mock_run.call_args[0][0].index("-p") + 1]

        self.assertNotEqual(p1, p2)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_invokes_claude_binary(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("rubric", "content")

        cmd = mock_run.call_args[0][0]
        self.assertEqual(cmd[0], "claude")


# ===========================================================================
# AC-6: Transcript parameter forwarding
# ===========================================================================

class TestTranscriptParameter(unittest.TestCase):
    """When transcript is provided, it should be included in the prompt."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_transcript_included_in_prompt_when_provided(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        transcript = [
            {"type": "assistant", "content": "I will create the file"},
            {"type": "tool_use", "name": "write", "content": "done"},
        ]
        grade_with_model("rubric", "content", transcript=transcript)

        cmd = mock_run.call_args[0][0]
        p_idx = cmd.index("-p")
        prompt = cmd[p_idx + 1]
        # Transcript content should appear in the prompt somehow
        self.assertIn("I will create the file", prompt)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_no_transcript_still_works(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        result = grade_with_model("rubric", "content", transcript=None)
        self.assertIsInstance(result, CheckResult)
        self.assertTrue(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_empty_transcript_still_works(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        result = grade_with_model("rubric", "content", transcript=[])
        self.assertIsInstance(result, CheckResult)
        self.assertTrue(result.passed)


# ===========================================================================
# AC-6: CheckResult.type field
# ===========================================================================

class TestCheckResultType(unittest.TestCase):
    """CheckResult.type must identify this as a model grade check."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_type_is_model_grade(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        result = grade_with_model("rubric", "content")
        self.assertEqual(result.type, "model_grade")

    @patch("evals.framework.model_grader.subprocess.run")
    def test_type_is_model_grade_on_failure(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json("not json"), returncode=0
        )
        result = grade_with_model("rubric", "content")
        self.assertEqual(result.type, "model_grade")

    @patch("evals.framework.model_grader.subprocess.run")
    def test_type_is_model_grade_on_claude_error(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout="", stderr="error", returncode=1
        )
        result = grade_with_model("rubric", "content")
        self.assertEqual(result.type, "model_grade")


# ===========================================================================
# AC-7: Command uses -p flag (not stdin)
# ===========================================================================

class TestCommandUsesPromptFlag(unittest.TestCase):
    """Grading prompt must be passed via -p, not piped through stdin."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_uses_dash_p_flag(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("rubric", "content")

        cmd = mock_run.call_args[0][0]
        self.assertIn("-p", cmd)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_no_stdin_input(self, mock_run):
        """subprocess.run should not receive input= kwarg."""
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.8)
        )
        grade_with_model("rubric", "content")

        call_kwargs = mock_run.call_args[1] if mock_run.call_args[1] else {}
        # input kwarg should not be set (prompt goes via -p, not stdin)
        self.assertNotIn("input", call_kwargs)


# ===========================================================================
# Edge: score boundary values
# ===========================================================================

class TestScoreBoundaryValues(unittest.TestCase):
    """Test score values at and near the 0.7 boundary."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_0699_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.699)
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_0701_passes(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response(score=0.701)
        )
        result = grade_with_model("rubric", "content")
        self.assertTrue(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_score_clamped_to_range(self, mock_run):
        """Score outside 0.0-1.0 should still parse, but passed follows threshold."""
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json(json.dumps({"score": 1.5, "evidence": "over max"}))
        )
        result = grade_with_model("rubric", "content")
        # Even if score > 1.0, it should still be > 0.7 so passed=True
        self.assertTrue(result.passed)

    @patch("evals.framework.model_grader.subprocess.run")
    def test_negative_score_fails(self, mock_run):
        mock_run.return_value = _mock_run(
            stdout=_wrap_as_stream_json(json.dumps({"score": -0.5, "evidence": "negative"}))
        )
        result = grade_with_model("rubric", "content")
        self.assertFalse(result.passed)


# ===========================================================================
# _extract_json
# ===========================================================================

class TestExtractJson(unittest.TestCase):
    """Tests for robust JSON extraction from model responses."""

    def test_raw_json(self):
        result = _extract_json('{"score": 0.8, "evidence": "good"}')
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.8)

    def test_markdown_fenced_json(self):
        text = '```json\n{"score": 0.9, "evidence": "great"}\n```'
        result = _extract_json(text)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.9)

    def test_plain_fenced_json(self):
        text = '```\n{"score": 0.7, "evidence": "ok"}\n```'
        result = _extract_json(text)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.7)

    def test_preamble_then_json(self):
        text = 'Here is the result: {"score": 0.5, "evidence": "weak"}'
        result = _extract_json(text)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.5)

    def test_json_with_trailing_explanation(self):
        text = '{"score": 0.6, "evidence": "partial"}\n\nThe above scores reflect...'
        result = _extract_json(text)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.6)

    def test_no_json_returns_none(self):
        result = _extract_json("This is just text with no JSON")
        self.assertIsNone(result)

    def test_empty_string_returns_none(self):
        result = _extract_json("")
        self.assertIsNone(result)

    def test_json_array_returns_none(self):
        """Only dicts are accepted, not arrays."""
        result = _extract_json('[1, 2, 3]')
        self.assertIsNone(result)

    def test_braces_inside_json_strings(self):
        """Braces inside string values must not break brace matching."""
        text = 'Result: {"score": 0.8, "evidence": "The {code} looks correct"}'
        result = _extract_json(text)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.8)
        self.assertIn("{code}", result["evidence"])

    def test_escaped_quotes_in_json_strings(self):
        """Escaped quotes inside strings must not break string tracking."""
        text = r'{"score": 0.9, "evidence": "said \"hello\" to {user}"}'
        result = _extract_json(text)
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["score"], 0.9)


class TestExtractJsonUsedByGrader(unittest.TestCase):
    """grade_with_model uses _extract_json for fenced responses."""

    @patch("evals.framework.model_grader.subprocess.run")
    def test_fenced_response_parses_correctly(self, mock_run):
        fenced = '```json\n{"score": 0.85, "evidence": "found all bugs"}\n```'
        mock_run.return_value = _mock_run(
            stdout=_valid_model_response_raw(fenced)
        )
        result = grade_with_model("rubric", "content")
        self.assertTrue(result.passed)
        self.assertAlmostEqual(result.score, 0.85)


# Helper for raw NDJSON with custom assistant text
def _valid_model_response_raw(assistant_text: str) -> str:
    """Build NDJSON with custom assistant text content."""
    import json as _json
    event = {
        "type": "assistant",
        "message": {
            "content": [{"type": "text", "text": assistant_text}]
        }
    }
    return _json.dumps(event)


if __name__ == "__main__":
    unittest.main()
