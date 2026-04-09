"""Tests for evals.framework.runner — Claude/Codex runners and RunResult.

RED phase: all tests must fail because the implementation is stubbed.

Acceptance criteria covered:
  AC-1: run_skill() invokes claude with correct args, returns RunResult
  AC-2: CLAUDECODE env var set to "" in subprocess, parent env unmodified
  AC-3: Timeout terminates subprocess, returns non-zero exit_code
  AC-4: RunResult extracts tokens/duration_ms from stream-json events
  AC-5: FileNotFoundError when claude binary not on PATH
"""

import json
import os
import subprocess
import unittest
from unittest.mock import MagicMock, patch, ANY

from evals.framework.runner import (
    AutoRunner,
    ClaudeCodeRunner,
    CodexRunner,
    RunResult,
    ToolRunner,
    create_runner,
)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_stream_json_stdout(*events):
    """Build newline-delimited JSON matching claude --output-format stream-json."""
    return "\n".join(json.dumps(e) for e in events) + "\n"


SIMPLE_STDOUT = _make_stream_json_stdout(
    {"type": "assistant", "content": "hello"},
)

STDOUT_WITH_USAGE = _make_stream_json_stdout(
    {"type": "assistant", "content": "hello"},
    {
        "type": "result",
        "duration_ms": 1234,
        "usage": {"input_tokens": 100, "output_tokens": 50},
    },
)

STDOUT_WITHOUT_USAGE = _make_stream_json_stdout(
    {"type": "assistant", "content": "hello"},
    {"type": "result"},
)

CODEX_STDOUT = _make_stream_json_stdout(
    {"type": "thread.started", "thread_id": "t-1"},
    {"type": "turn.started"},
    {"type": "item.completed", "item": {"id": "item_0", "type": "agent_message", "text": "hello from codex"}},
    {"type": "turn.completed", "usage": {"input_tokens": 120, "cached_input_tokens": 30, "output_tokens": 40}},
)


def _mock_popen(stdout="", stderr="", returncode=0, pid=12345):
    """Return a MagicMock configured to behave like subprocess.Popen."""
    proc = MagicMock()
    proc.communicate.return_value = (stdout, stderr)
    proc.returncode = returncode
    proc.pid = pid
    proc.wait.return_value = returncode
    proc.kill = MagicMock()
    proc.terminate = MagicMock()
    return proc


def _mock_run(stdout="", stderr="", returncode=0):
    """Return a MagicMock configured like subprocess.CompletedProcess."""
    result = MagicMock(spec=subprocess.CompletedProcess)
    result.stdout = stdout
    result.stderr = stderr
    result.returncode = returncode
    return result


# ===========================================================================
# AC-1: run_skill() invokes claude with correct args, returns RunResult
# ===========================================================================

class TestRunSkillInvocation(unittest.TestCase):
    """AC-1: run_skill() calls claude subprocess and returns RunResult."""

    @patch("evals.framework.runner.subprocess.Popen")
    def test_returns_run_result_instance(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="initialize project")
        self.assertIsInstance(result, RunResult)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_result_has_exit_code(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT, returncode=0)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="initialize project")
        self.assertEqual(result.exit_code, 0)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_result_has_nonzero_exit_code_on_failure(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(
            stdout="", stderr="error happened", returncode=1
        )
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="initialize project")
        self.assertEqual(result.exit_code, 1)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_result_captures_stdout(self, mock_popen_cls):
        expected_stdout = SIMPLE_STDOUT
        mock_popen_cls.return_value = _mock_popen(stdout=expected_stdout)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="initialize project")
        self.assertEqual(result.stdout, expected_stdout)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_result_captures_stderr(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(
            stdout=SIMPLE_STDOUT, stderr="warning: something"
        )
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="initialize project")
        self.assertEqual(result.stderr, "warning: something")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_result_captures_transcript(self, mock_popen_cls):
        """Transcript should contain the full stream-json output for later analysis."""
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITH_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="initialize project")
        # Transcript must be a list of parsed JSON events, not raw text
        self.assertIsInstance(result.transcript, list)
        self.assertGreater(len(result.transcript), 0)
        # Each entry should be a dict (parsed from the stream-json lines)
        for entry in result.transcript:
            self.assertIsInstance(entry, dict)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_invokes_claude_with_stream_json_flag(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="do stuff")

        mock_popen_cls.assert_called_once()
        cmd = mock_popen_cls.call_args[0][0]  # positional arg: the command list
        self.assertIn("--output-format", cmd)
        fmt_idx = cmd.index("--output-format")
        self.assertEqual(cmd[fmt_idx + 1], "stream-json")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_invokes_claude_with_prompt_via_dash_p(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="my prompt text")

        cmd = mock_popen_cls.call_args[0][0]
        self.assertIn("-p", cmd)
        p_idx = cmd.index("-p")
        self.assertEqual(cmd[p_idx + 1], "my prompt text")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_invokes_claude_binary_as_first_arg(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="hello")

        cmd = mock_popen_cls.call_args[0][0]
        self.assertEqual(cmd[0], "claude")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_different_prompts_produce_different_commands(self, mock_popen_cls):
        """Guards against hardcoded prompt values."""
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()

        runner.run_skill("sw-init", prompt="first prompt")
        cmd1 = mock_popen_cls.call_args[0][0][:]

        mock_popen_cls.reset_mock()
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)

        runner.run_skill("sw-build", prompt="second prompt")
        cmd2 = mock_popen_cls.call_args[0][0][:]

        # Prompts differ so commands must differ
        self.assertNotEqual(cmd1, cmd2)
        p_idx1 = cmd1.index("-p")
        p_idx2 = cmd2.index("-p")
        self.assertEqual(cmd1[p_idx1 + 1], "first prompt")
        self.assertEqual(cmd2[p_idx2 + 1], "second prompt")


# ===========================================================================
# AC-2: CLAUDECODE env var handling
# ===========================================================================

class TestClaudeCodeEnvVar(unittest.TestCase):
    """AC-2: CLAUDECODE env var set to '' in subprocess, parent unmodified."""

    @patch("evals.framework.runner.subprocess.Popen")
    def test_subprocess_receives_claudecode_empty_string(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="test")

        call_kwargs = mock_popen_cls.call_args[1]  # keyword args
        env = call_kwargs.get("env")
        self.assertIsNotNone(env, "Popen must be called with explicit env")
        self.assertIn("CLAUDECODE", env)
        self.assertEqual(env["CLAUDECODE"], "")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_parent_env_not_modified(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)

        original_env = os.environ.copy()
        # Ensure CLAUDECODE is not in parent env before the call
        os.environ.pop("CLAUDECODE", None)

        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="test")

        # Parent environment must not have CLAUDECODE injected
        self.assertNotIn("CLAUDECODE", os.environ)
        # Restore (safety)
        os.environ.update(original_env)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_subprocess_env_inherits_parent_env(self, mock_popen_cls):
        """Subprocess env should be based on parent env (plus CLAUDECODE override)."""
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="test")

        call_kwargs = mock_popen_cls.call_args[1]
        env = call_kwargs.get("env", {})
        # PATH must be inherited so claude binary can be found
        self.assertIn("PATH", env)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_claudecode_env_is_empty_string_not_missing(self, mock_popen_cls):
        """Specifically distinguish between '' and not being set at all."""
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT)
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="test")

        env = mock_popen_cls.call_args[1].get("env", {})
        # Must be exactly empty string, not None or "0" or "false"
        self.assertIs(type(env.get("CLAUDECODE")), str)
        self.assertEqual(len(env["CLAUDECODE"]), 0)


# ===========================================================================
# AC-3: Timeout handling
# ===========================================================================

class TestTimeout(unittest.TestCase):
    """AC-3: Terminate subprocess on timeout, return non-zero exit_code."""

    @patch("evals.framework.runner.subprocess.Popen")
    def test_default_timeout_is_300_seconds(self, mock_popen_cls):
        proc = _mock_popen(stdout=SIMPLE_STDOUT)
        mock_popen_cls.return_value = proc
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="test")

        # communicate() must be called with timeout=300
        proc.communicate.assert_called_once()
        call_kwargs = proc.communicate.call_args[1]
        self.assertEqual(call_kwargs.get("timeout"), 300)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_custom_timeout_is_forwarded(self, mock_popen_cls):
        proc = _mock_popen(stdout=SIMPLE_STDOUT)
        mock_popen_cls.return_value = proc
        runner = ClaudeCodeRunner()
        runner.run_skill("sw-init", prompt="test", timeout=60)

        call_kwargs = proc.communicate.call_args[1]
        self.assertEqual(call_kwargs.get("timeout"), 60)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_timeout_kills_process_and_returns_nonzero(self, mock_popen_cls):
        proc = _mock_popen(stdout="", returncode=0)
        proc.communicate.side_effect = [
            subprocess.TimeoutExpired(cmd="claude", timeout=300),
            ("", "timed out"),  # second call after kill
        ]
        proc.returncode = -9  # killed
        mock_popen_cls.return_value = proc
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="slow task")

        # Process must be killed/terminated
        self.assertTrue(
            proc.kill.called or proc.terminate.called,
            "Process must be killed or terminated on timeout",
        )
        self.assertNotEqual(result.exit_code, 0)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_timeout_result_is_still_run_result(self, mock_popen_cls):
        proc = _mock_popen()
        proc.communicate.side_effect = [
            subprocess.TimeoutExpired(cmd="claude", timeout=10),
            ("partial output", "timeout stderr"),
        ]
        proc.returncode = -15
        mock_popen_cls.return_value = proc
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="slow", timeout=10)

        self.assertIsInstance(result, RunResult)
        self.assertIsNotNone(result.exit_code)
        # Should still have whatever stdout/stderr was captured
        self.assertIsInstance(result.stdout, str)
        self.assertIsInstance(result.stderr, str)


# ===========================================================================
# AC-4: Token and duration extraction from stream-json
# ===========================================================================

class TestTokenAndDurationExtraction(unittest.TestCase):
    """AC-4: RunResult extracts tokens and duration_ms from stream-json."""

    @patch("evals.framework.runner.subprocess.Popen")
    def test_extracts_duration_ms_from_result_event(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITH_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertEqual(result.duration_ms, 1234)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_extracts_input_tokens_from_usage(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITH_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        # tokens should capture at minimum input + output
        self.assertIsNotNone(result.tokens)
        self.assertIn("input_tokens", result.tokens)
        self.assertEqual(result.tokens["input_tokens"], 100)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_extracts_output_tokens_from_usage(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITH_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIn("output_tokens", result.tokens)
        self.assertEqual(result.tokens["output_tokens"], 50)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_tokens_none_when_usage_absent(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITHOUT_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIsNone(result.tokens)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_duration_ms_none_when_not_in_events(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITHOUT_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIsNone(result.duration_ms)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_tokens_none_when_stdout_is_empty(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout="")
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIsNone(result.tokens)
        self.assertIsNone(result.duration_ms)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_tokens_none_when_stdout_is_not_json(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout="not json at all\nreally\n")
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIsNone(result.tokens)
        self.assertIsNone(result.duration_ms)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_duration_ms_is_integer_not_string(self, mock_popen_cls):
        """Guards against returning the raw string instead of parsed int."""
        mock_popen_cls.return_value = _mock_popen(stdout=STDOUT_WITH_USAGE)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIsInstance(result.duration_ms, int)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_different_usage_values_reflected(self, mock_popen_cls):
        """Guards against hardcoded token counts."""
        custom_stdout = _make_stream_json_stdout(
            {"type": "assistant", "content": "x"},
            {
                "type": "result",
                "duration_ms": 9999,
                "usage": {"input_tokens": 500, "output_tokens": 200},
            },
        )
        mock_popen_cls.return_value = _mock_popen(stdout=custom_stdout)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertEqual(result.duration_ms, 9999)
        self.assertEqual(result.tokens["input_tokens"], 500)
        self.assertEqual(result.tokens["output_tokens"], 200)


# ===========================================================================
# AC-5: FileNotFoundError when claude binary missing
# ===========================================================================

class TestClaudeBinaryNotFound(unittest.TestCase):
    """AC-5: Raises FileNotFoundError if claude not on PATH."""

    @patch("evals.framework.runner.subprocess.Popen")
    def test_raises_file_not_found_when_binary_missing(self, mock_popen_cls):
        mock_popen_cls.side_effect = FileNotFoundError(
            "[Errno 2] No such file or directory: 'claude'"
        )
        runner = ClaudeCodeRunner()
        with self.assertRaises(FileNotFoundError):
            runner.run_skill("sw-init", prompt="test")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_file_not_found_error_propagates_not_swallowed(self, mock_popen_cls):
        """Ensure the error isn't caught and converted to a RunResult."""
        mock_popen_cls.side_effect = FileNotFoundError("claude not found")
        runner = ClaudeCodeRunner()
        raised = False
        try:
            result = runner.run_skill("sw-init", prompt="test")
            # If we get here without raising, fail explicitly:
            # A bad impl might return a RunResult with exit_code != 0 instead of raising
            self.fail(
                "Expected FileNotFoundError but got RunResult; "
                "error must propagate, not be converted to a result"
            )
        except FileNotFoundError:
            raised = True
        self.assertTrue(raised)


# ===========================================================================
# ToolRunner base class contract
# ===========================================================================

class TestToolRunnerContract(unittest.TestCase):
    """ClaudeCodeRunner must be a subclass of ToolRunner."""

    def test_claude_code_runner_is_tool_runner_subclass(self):
        self.assertTrue(issubclass(ClaudeCodeRunner, ToolRunner))

    def test_tool_runner_has_run_skill_method(self):
        """ToolRunner must define run_skill as part of its interface."""
        self.assertTrue(
            hasattr(ToolRunner, "run_skill"),
            "ToolRunner must define a run_skill method",
        )

    def test_codex_runner_is_tool_runner_subclass(self):
        self.assertTrue(issubclass(CodexRunner, ToolRunner))


# ===========================================================================
# RunResult data integrity
# ===========================================================================

class TestRunResultDataIntegrity(unittest.TestCase):
    """RunResult fields are correctly typed and contain expected data."""

    @patch("evals.framework.runner.subprocess.Popen")
    def test_run_result_fields_are_not_none_on_success(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(
            stdout=STDOUT_WITH_USAGE, stderr="", returncode=0
        )
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")

        # All four core fields must be present
        self.assertIsNotNone(result.exit_code)
        self.assertIsNotNone(result.stdout)
        self.assertIsNotNone(result.stderr)
        self.assertIsNotNone(result.transcript)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_transcript_parses_all_json_lines(self, mock_popen_cls):
        stdout = _make_stream_json_stdout(
            {"type": "assistant", "content": "line1"},
            {"type": "assistant", "content": "line2"},
            {"type": "result", "duration_ms": 100},
        )
        mock_popen_cls.return_value = _mock_popen(stdout=stdout)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")

        self.assertEqual(len(result.transcript), 3)
        self.assertEqual(
            result.transcript[0]["message"]["content"][0]["text"],
            "line1",
        )
        self.assertEqual(
            result.transcript[1]["message"]["content"][0]["text"],
            "line2",
        )
        self.assertEqual(result.transcript[2]["type"], "result")

    @patch("evals.framework.runner.subprocess.Popen")
    def test_transcript_empty_list_when_no_output(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout="", returncode=1)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")

        self.assertIsInstance(result.transcript, list)
        self.assertEqual(len(result.transcript), 0)

    @patch("evals.framework.runner.subprocess.Popen")
    def test_exit_code_is_int(self, mock_popen_cls):
        mock_popen_cls.return_value = _mock_popen(stdout=SIMPLE_STDOUT, returncode=42)
        runner = ClaudeCodeRunner()
        result = runner.run_skill("sw-init", prompt="test")
        self.assertIsInstance(result.exit_code, int)
        self.assertEqual(result.exit_code, 42)


class TestCodexRunner(unittest.TestCase):
    """Codex output is normalized into the same transcript contract."""

    @patch("evals.framework.runner.subprocess.run")
    def test_codex_runner_normalizes_agent_message(self, mock_run):
        mock_run.return_value = _mock_run(stdout=CODEX_STDOUT)
        runner = CodexRunner()
        result = runner.run_skill("sw-build", prompt="test")
        self.assertEqual(result.provider, "codex")
        self.assertEqual(
            result.transcript[0]["message"]["content"][0]["text"],
            "hello from codex",
        )

    @patch("evals.framework.runner.subprocess.run")
    def test_codex_runner_extracts_usage(self, mock_run):
        mock_run.return_value = _mock_run(stdout=CODEX_STDOUT)
        runner = CodexRunner()
        result = runner.run_skill("sw-build", prompt="test")
        self.assertEqual(result.tokens["input_tokens"], 120)
        self.assertEqual(result.tokens["cached_input_tokens"], 30)
        self.assertEqual(result.tokens["output_tokens"], 40)

    @patch("evals.framework.runner.subprocess.run")
    def test_codex_runner_uses_danger_full_access_and_tempdir(self, mock_run):
        mock_run.return_value = _mock_run(stdout=CODEX_STDOUT)
        runner = CodexRunner()
        result = runner.run_skill("sw-build", prompt="test", workdir="/tmp/eval-fixture")
        self.assertEqual(result.provider, "codex")

        cmd = mock_run.call_args[0][0]
        self.assertIn("--sandbox", cmd)
        sandbox_index = cmd.index("--sandbox")
        self.assertEqual(cmd[sandbox_index + 1], "danger-full-access")

        env = mock_run.call_args[1]["env"]
        self.assertEqual(env["TMPDIR"], "/tmp/eval-fixture/.tmp")
        self.assertEqual(env["TMP"], "/tmp/eval-fixture/.tmp")
        self.assertEqual(env["TEMP"], "/tmp/eval-fixture/.tmp")


class TestAutoRunner(unittest.TestCase):
    """Auto runner falls back only for Claude availability failures."""

    @patch("evals.framework.runner.CodexRunner.run_skill")
    @patch("evals.framework.runner.ClaudeCodeRunner.run_skill")
    def test_auto_runner_falls_back_on_login_failure(self, mock_claude, mock_codex):
        mock_claude.return_value = RunResult(
            exit_code=0,
            stdout="",
            stderr="",
            transcript=[{"type": "result", "result": "Not logged in · Please run /login"}],
            provider="claude",
        )
        mock_codex.return_value = RunResult(
            exit_code=0,
            stdout="",
            stderr="",
            transcript=[],
            provider="codex",
        )
        runner = AutoRunner()
        result = runner.run_skill("sw-build", "test")
        self.assertEqual(result.provider, "codex")

    def test_create_runner_supports_codex(self):
        self.assertIsInstance(create_runner("codex"), CodexRunner)


if __name__ == "__main__":
    unittest.main()
