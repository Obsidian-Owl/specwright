"""Eval framework runners for Claude Code and Codex CLI."""

import json
import os
import subprocess
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, List, Optional

DEFAULT_TIMEOUT_SECONDS = 300

CLAUDE_PROVIDER = "claude"
CODEX_PROVIDER = "codex"
AUTO_PROVIDER = "auto"
SUPPORTED_PROVIDERS = {CLAUDE_PROVIDER, CODEX_PROVIDER, AUTO_PROVIDER}

_CLAUDE_BINARY = "claude"
_CLAUDECODE_ENV_KEY = "CLAUDECODE"
_CLAUDECODE_ENV_VALUE = ""
_PROMPT_FLAG = "-p"
_OUTPUT_FORMAT_FLAG = "--output-format"
_OUTPUT_FORMAT_VALUE = "stream-json"
_VERBOSE_FLAG = "--verbose"

_CODEX_BINARY = "codex"
_CODEX_EXEC_SUBCOMMAND = "exec"
_CODEX_JSON_FLAG = "--json"
_CODEX_EPHEMERAL_FLAG = "--ephemeral"
_CODEX_SKIP_GIT_CHECK_FLAG = "--skip-git-repo-check"
_CODEX_SANDBOX_FLAG = "--sandbox"
_CODEX_SANDBOX_VALUE = "danger-full-access"

_RESULT_EVENT_TYPE = "result"
_RESULT_DURATION_FIELD = "duration_ms"
_RESULT_USAGE_FIELD = "usage"

_CLAUDE_FALLBACK_PATTERNS = (
    "not logged in",
    "please run /login",
    "run /login",
    "insufficient credits",
    "insufficient credit",
    "insufficient funds",
    "quota exceeded",
    "usage limit",
    "billing",
    "out of funds",
    "tool permission",
    "requires your approval",
    "requires your tool permission",
    "tool use is disabled",
    "approval required",
    "write permission",
    "grant write access",
    "permission to modify",
    "need write access",
)


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
    provider: str = CLAUDE_PROVIDER


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


def _parse_jsonl(stdout: str) -> List[Dict]:
    """Parse newline-delimited JSON into a list of dict events."""
    events: List[Dict] = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(event, dict):
            events.append(event)
    return events


def _text_block(text: str) -> Dict:
    """Return a Claude-style text content block."""
    return {"type": "text", "text": text}


def _assistant_event(text: str) -> Dict:
    """Return a normalized assistant event."""
    return {
        "type": "assistant",
        "message": {
            "content": [_text_block(text)],
        },
    }


def _normalize_assistant_event(event: Dict) -> Dict:
    """Normalize a Claude assistant event into the canonical message shape."""
    if event.get("type") != "assistant":
        return event

    message = event.get("message")
    if isinstance(message, dict):
        content = message.get("content")
        if isinstance(content, list):
            return {
                "type": "assistant",
                "message": {"content": content},
            }

    content = event.get("content")
    if isinstance(content, str):
        return _assistant_event(content)
    if isinstance(content, list):
        return {"type": "assistant", "message": {"content": content}}
    return {"type": "assistant", "message": {"content": []}}


def _normalize_claude_events(events: List[Dict]) -> List[Dict]:
    """Normalize Claude stream-json events into the canonical transcript shape."""
    normalized: List[Dict] = []
    for event in events:
        event_type = event.get("type")
        if event_type == "assistant":
            normalized.append(_normalize_assistant_event(event))
            continue
        if event_type == _RESULT_EVENT_TYPE:
            result_event = {"type": _RESULT_EVENT_TYPE}
            if isinstance(event.get("result"), str):
                result_event["result"] = event["result"]
            if isinstance(event.get(_RESULT_DURATION_FIELD), (int, float)):
                result_event[_RESULT_DURATION_FIELD] = int(event[_RESULT_DURATION_FIELD])
            if isinstance(event.get(_RESULT_USAGE_FIELD), dict):
                result_event[_RESULT_USAGE_FIELD] = dict(event[_RESULT_USAGE_FIELD])
            normalized.append(result_event)
            continue
        normalized.append(event)
    return normalized


def _extract_codex_item_text(event: Dict) -> Optional[str]:
    """Extract assistant-visible text from a Codex item.completed event."""
    item = event.get("item")
    if not isinstance(item, dict):
        return None
    if item.get("type") != "agent_message":
        return None
    text = item.get("text")
    if isinstance(text, str) and text.strip():
        return text
    return None


def _normalize_codex_usage(usage: Dict) -> Dict:
    """Normalize Codex usage into the shared tokens dict."""
    normalized: Dict[str, int] = {}
    for key in ("input_tokens", "output_tokens", "cached_input_tokens"):
        value = usage.get(key)
        if isinstance(value, (int, float)):
            normalized[key] = int(value)
    return normalized


def _normalize_codex_events(events: List[Dict]) -> List[Dict]:
    """Normalize Codex JSONL events into the canonical transcript shape."""
    normalized: List[Dict] = []
    final_text = ""
    usage: Optional[Dict] = None
    duration_ms: Optional[int] = None

    for event in events:
        event_type = event.get("type")
        if event_type == "item.completed":
            text = _extract_codex_item_text(event)
            if text:
                final_text = text
                normalized.append(_assistant_event(text))
            continue
        if event_type == "turn.completed":
            usage_raw = event.get("usage")
            if isinstance(usage_raw, dict):
                usage = _normalize_codex_usage(usage_raw)
            if isinstance(event.get(_RESULT_DURATION_FIELD), (int, float)):
                duration_ms = int(event[_RESULT_DURATION_FIELD])

    if final_text or usage is not None or duration_ms is not None:
        result_event: Dict[str, object] = {"type": _RESULT_EVENT_TYPE}
        if final_text:
            result_event["result"] = final_text
        if usage is not None:
            result_event[_RESULT_USAGE_FIELD] = usage
        if duration_ms is not None:
            result_event[_RESULT_DURATION_FIELD] = duration_ms
        normalized.append(result_event)

    return normalized


def normalize_transcript(provider: str, stdout: str) -> List[Dict]:
    """Parse provider stdout and return a normalized transcript."""
    events = _parse_jsonl(stdout)
    if provider == CLAUDE_PROVIDER:
        return _normalize_claude_events(events)
    if provider == CODEX_PROVIDER:
        return _normalize_codex_events(events)
    raise ValueError(f"Unsupported provider for transcript normalization: {provider}")


def extract_assistant_text(transcript: List[Dict]) -> Optional[str]:
    """Extract concatenated assistant text from a normalized transcript."""
    texts: List[str] = []
    for event in transcript:
        if event.get("type") == "assistant":
            message = event.get("message") or {}
            content = message.get("content") or []
            if not isinstance(content, list):
                continue
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "").strip()
                    if text:
                        texts.append(text)
    if texts:
        return "\n".join(texts)

    for event in transcript:
        if event.get("type") == _RESULT_EVENT_TYPE:
            result_text = event.get("result")
            if isinstance(result_text, str) and result_text.strip():
                return result_text
    return None


def _extract_result_event(transcript: List[Dict]) -> Optional[Dict]:
    """Return the first normalized result event from the transcript."""
    for event in transcript:
        if event.get("type") == _RESULT_EVENT_TYPE:
            return event
    return None


def _extract_tokens(result_event: Optional[Dict]) -> Optional[Dict]:
    """Extract usage dict from a normalized result event."""
    if result_event is None:
        return None
    usage = result_event.get(_RESULT_USAGE_FIELD)
    if isinstance(usage, dict):
        return usage
    return None


def _extract_duration_ms(result_event: Optional[Dict]) -> Optional[int]:
    """Extract duration_ms from a normalized result event."""
    if result_event is None:
        return None
    value = result_event.get(_RESULT_DURATION_FIELD)
    if value is None:
        return None
    return int(value)


def _build_claude_command(prompt: str) -> List[str]:
    """Build the claude subprocess command list."""
    return [
        _CLAUDE_BINARY,
        _PROMPT_FLAG,
        prompt,
        _OUTPUT_FORMAT_FLAG,
        _OUTPUT_FORMAT_VALUE,
        _VERBOSE_FLAG,
    ]


def _build_codex_command(prompt: str) -> List[str]:
    """Build the codex subprocess command list."""
    return [
        _CODEX_BINARY,
        _CODEX_EXEC_SUBCOMMAND,
        _CODEX_JSON_FLAG,
        _CODEX_EPHEMERAL_FLAG,
        _CODEX_SKIP_GIT_CHECK_FLAG,
        _CODEX_SANDBOX_FLAG,
        _CODEX_SANDBOX_VALUE,
        prompt,
    ]


def _build_claude_env() -> Dict[str, str]:
    """Build subprocess environment for Claude Code."""
    env = os.environ.copy()
    env[_CLAUDECODE_ENV_KEY] = _CLAUDECODE_ENV_VALUE
    return env


def _build_codex_env(workdir: Optional[str]) -> Dict[str, str]:
    """Build subprocess environment for Codex CLI."""
    env = os.environ.copy()
    if workdir:
        tmp_dir = os.path.join(workdir, ".tmp")
        os.makedirs(tmp_dir, exist_ok=True)
        env["TMPDIR"] = tmp_dir
        env["TMP"] = tmp_dir
        env["TEMP"] = tmp_dir
    return env


def _run_popen(
    cmd: List[str], env: Dict[str, str], timeout: int, cwd: Optional[str] = None
):
    """Launch subprocess via Popen and communicate with timeout handling."""
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        env=env,
        cwd=cwd,
        stdin=subprocess.DEVNULL,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
        return stdout, stderr, proc.returncode
    except subprocess.TimeoutExpired:
        proc.kill()
        stdout, stderr = proc.communicate()
        return stdout or "", stderr or "", proc.returncode


def _run_completed(
    cmd: List[str], env: Dict[str, str], timeout: int, cwd: Optional[str] = None
):
    """Launch subprocess via run() with timeout handling."""
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            cwd=cwd,
            stdin=subprocess.DEVNULL,
        )
        return proc.stdout or "", proc.stderr or "", proc.returncode
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode("utf-8", errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode("utf-8", errors="replace")
        return stdout, stderr, 124


def _fallback_text(run_result: RunResult) -> str:
    """Return lower-cased text used to detect fallback-worthy Claude failures."""
    parts = [run_result.stdout, run_result.stderr]
    assistant_text = extract_assistant_text(run_result.transcript)
    if assistant_text:
        parts.append(assistant_text)
    return "\n".join(part for part in parts if part).lower()


def should_fallback_from_claude(run_result: RunResult) -> bool:
    """Return True when Claude failed for environment/auth/quota reasons."""
    text = _fallback_text(run_result)
    return any(pattern in text for pattern in _CLAUDE_FALLBACK_PATTERNS)


class ClaudeCodeRunner(ToolRunner):
    """Runs skills via the `claude` CLI binary."""

    provider = CLAUDE_PROVIDER

    def run_skill(
        self,
        skill: str,
        prompt: str,
        workdir: Optional[str] = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS,
    ) -> RunResult:
        del skill
        cmd = _build_claude_command(prompt)
        env = _build_claude_env()

        try:
            stdout, stderr, exit_code = _run_popen(cmd, env, timeout, cwd=workdir)
        except FileNotFoundError as exc:
            raise FileNotFoundError(
                f"Claude CLI is required but '{_CLAUDE_BINARY}' was not found on PATH. "
                "Install it from https://docs.anthropic.com/en/docs/claude-code"
            ) from exc

        transcript = normalize_transcript(CLAUDE_PROVIDER, stdout)
        result_event = _extract_result_event(transcript)
        return RunResult(
            exit_code=exit_code,
            stdout=stdout,
            stderr=stderr,
            transcript=transcript,
            tokens=_extract_tokens(result_event),
            duration_ms=_extract_duration_ms(result_event),
            provider=CLAUDE_PROVIDER,
        )


class CodexRunner(ToolRunner):
    """Runs skills via the `codex exec` CLI."""

    provider = CODEX_PROVIDER

    def run_skill(
        self,
        skill: str,
        prompt: str,
        workdir: Optional[str] = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS,
    ) -> RunResult:
        del skill
        cmd = _build_codex_command(prompt)
        env = _build_codex_env(workdir)

        try:
            stdout, stderr, exit_code = _run_completed(cmd, env, timeout, cwd=workdir)
        except FileNotFoundError as exc:
            raise FileNotFoundError(
                f"Codex CLI is required but '{_CODEX_BINARY}' was not found on PATH."
            ) from exc

        transcript = normalize_transcript(CODEX_PROVIDER, stdout)
        result_event = _extract_result_event(transcript)
        return RunResult(
            exit_code=exit_code,
            stdout=stdout,
            stderr=stderr,
            transcript=transcript,
            tokens=_extract_tokens(result_event),
            duration_ms=_extract_duration_ms(result_event),
            provider=CODEX_PROVIDER,
        )


class AutoRunner(ToolRunner):
    """Prefer Claude, permanently falling back to Codex when Claude is unavailable."""

    provider = AUTO_PROVIDER

    def __init__(self):
        self._claude = ClaudeCodeRunner()
        self._codex = CodexRunner()
        self._active_provider = CLAUDE_PROVIDER

    def run_skill(
        self,
        skill: str,
        prompt: str,
        workdir: Optional[str] = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS,
    ) -> RunResult:
        if self._active_provider == CODEX_PROVIDER:
            return self._codex.run_skill(skill, prompt, workdir=workdir, timeout=timeout)

        try:
            result = self._claude.run_skill(skill, prompt, workdir=workdir, timeout=timeout)
        except FileNotFoundError:
            self._active_provider = CODEX_PROVIDER
            return self._codex.run_skill(skill, prompt, workdir=workdir, timeout=timeout)

        if should_fallback_from_claude(result):
            self._active_provider = CODEX_PROVIDER
            return self._codex.run_skill(skill, prompt, workdir=workdir, timeout=timeout)
        return result


def create_runner(provider: Optional[str] = None) -> ToolRunner:
    """Create the requested runner, honoring EVALS_RUNNER when provider is unset."""
    requested = provider or os.environ.get("EVALS_RUNNER", AUTO_PROVIDER)
    requested = requested.strip().lower()
    if requested not in SUPPORTED_PROVIDERS:
        raise ValueError(
            f"Unsupported runner '{requested}'. Expected one of: "
            f"{', '.join(sorted(SUPPORTED_PROVIDERS))}"
        )
    if requested == CLAUDE_PROVIDER:
        return ClaudeCodeRunner()
    if requested == CODEX_PROVIDER:
        return CodexRunner()
    return AutoRunner()


__all__ = [
    "AUTO_PROVIDER",
    "CLAUDE_PROVIDER",
    "CODEX_PROVIDER",
    "SUPPORTED_PROVIDERS",
    "DEFAULT_TIMEOUT_SECONDS",
    "RunResult",
    "ToolRunner",
    "ClaudeCodeRunner",
    "CodexRunner",
    "AutoRunner",
    "create_runner",
    "extract_assistant_text",
    "normalize_transcript",
    "should_fallback_from_claude",
]
