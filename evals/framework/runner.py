"""Eval framework runner — subprocess-based tool runner for Claude Code skills."""

import json
import os
import subprocess
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, List, Optional

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_CLAUDE_BINARY = "claude"
_CLAUDECODE_ENV_KEY = "CLAUDECODE"
_CLAUDECODE_ENV_VALUE = ""
_OUTPUT_FORMAT_FLAG = "--output-format"
_OUTPUT_FORMAT_VALUE = "stream-json"
_PROMPT_FLAG = "-p"
DEFAULT_TIMEOUT_SECONDS = 300
_RESULT_EVENT_TYPE = "result"
_RESULT_DURATION_FIELD = "duration_ms"
_RESULT_USAGE_FIELD = "usage"


# ---------------------------------------------------------------------------
# Data
# ---------------------------------------------------------------------------

@dataclass
class RunResult:
    """Immutable result from a single skill invocation."""

    exit_code: int
    stdout: str
    stderr: str
    transcript: List[Dict]
    tokens: Optional[Dict] = None
    duration_ms: Optional[int] = None
    tool_calls: Dict = field(default_factory=dict)


# ---------------------------------------------------------------------------
# Abstractions
# ---------------------------------------------------------------------------

class ToolRunner(ABC):
    """Abstract base for all skill runners."""

    @abstractmethod
    def run_skill(
        self,
        skill: str,
        prompt: str,
        workdir: Optional[str] = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS,
    ) -> RunResult:
        """Run a skill with the given prompt and return a RunResult."""


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_command(prompt: str) -> List[str]:
    """Build the claude subprocess command list."""
    return [
        _CLAUDE_BINARY,
        _PROMPT_FLAG,
        prompt,
        _OUTPUT_FORMAT_FLAG,
        _OUTPUT_FORMAT_VALUE,
    ]


def _build_env() -> Dict[str, str]:
    """Build subprocess environment: parent env plus CLAUDECODE override."""
    env = os.environ.copy()
    env[_CLAUDECODE_ENV_KEY] = _CLAUDECODE_ENV_VALUE
    return env


def _parse_transcript(stdout: str) -> List[Dict]:
    """Parse newline-delimited JSON stream into a list of event dicts."""
    events = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            events.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return events


def _extract_result_event(transcript: List[Dict]) -> Optional[Dict]:
    """Return the first 'result' type event from the transcript, or None."""
    for event in transcript:
        if event.get("type") == _RESULT_EVENT_TYPE:
            return event
    return None


def _extract_tokens(result_event: Optional[Dict]) -> Optional[Dict]:
    """Extract usage dict from a result event, or None if absent."""
    if result_event is None:
        return None
    return result_event.get(_RESULT_USAGE_FIELD) or None


def _extract_duration_ms(result_event: Optional[Dict]) -> Optional[int]:
    """Extract duration_ms from a result event, or None if absent."""
    if result_event is None:
        return None
    value = result_event.get(_RESULT_DURATION_FIELD)
    if value is None:
        return None
    return int(value)


def _run_subprocess(
    cmd: List[str], env: Dict[str, str], timeout: int, cwd: Optional[str] = None
):
    """Launch subprocess and communicate with timeout handling.

    Returns (stdout, stderr, exit_code).
    """
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        cwd=cwd,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return stdout, stderr, proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        return stdout or "", stderr or "", proc.returncode


# ---------------------------------------------------------------------------
# Concrete runner
# ---------------------------------------------------------------------------

class ClaudeCodeRunner(ToolRunner):
    """Runs Claude Code skills via the `claude` CLI binary."""

    def run_skill(
        self,
        skill: str,
        prompt: str,
        workdir: Optional[str] = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS,
    ) -> RunResult:
        """Invoke the claude binary for the given skill and return a RunResult.

        Raises FileNotFoundError if the claude binary is not on PATH.
        """
        cmd = _build_command(prompt)
        env = _build_env()

        try:
            stdout, stderr, exit_code = _run_subprocess(cmd, env, timeout, cwd=workdir)
        except FileNotFoundError:
            raise FileNotFoundError(
                f"Claude CLI is required but '{_CLAUDE_BINARY}' was not found on PATH. "
                "Install it from https://docs.anthropic.com/en/docs/claude-code"
            )

        transcript = _parse_transcript(stdout)
        result_event = _extract_result_event(transcript)
        tokens = _extract_tokens(result_event)
        duration_ms = _extract_duration_ms(result_event)

        return RunResult(
            exit_code=exit_code,
            stdout=stdout,
            stderr=stderr,
            transcript=transcript,
            tokens=tokens,
            duration_ms=duration_ms,
        )
