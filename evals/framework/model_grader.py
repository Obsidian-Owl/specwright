"""Eval framework model grader with Claude and Codex judge support."""

import json
import re
import subprocess

from evals.framework.grader import CheckResult
from evals.framework.runner import (
    CLAUDE_PROVIDER,
    CODEX_PROVIDER,
    extract_assistant_text,
    normalize_transcript,
)

_PASS_THRESHOLD = 0.7


def _extract_json(text: str) -> dict | None:
    """Extract a JSON object from text that may contain fences, preamble, or trailing content."""
    text = text.strip()

    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data
    except (json.JSONDecodeError, ValueError):
        pass

    stripped = re.sub(r'^```(?:json)?\s*\n?', '', text)
    stripped = re.sub(r'\n?```\s*$', '', stripped).strip()
    if stripped != text:
        try:
            data = json.loads(stripped)
            if isinstance(data, dict):
                return data
        except (json.JSONDecodeError, ValueError):
            pass

    start = text.find('{')
    if start >= 0:
        depth = 0
        in_string = False
        escape_next = False
        for i in range(start, len(text)):
            ch = text[i]
            if escape_next:
                escape_next = False
                continue
            if ch == '\\' and in_string:
                escape_next = True
                continue
            if ch == '"':
                in_string = not in_string
                continue
            if in_string:
                continue
            if ch == '{':
                depth += 1
            elif ch == '}':
                depth -= 1
                if depth == 0:
                    candidate = text[start:i + 1]
                    try:
                        data = json.loads(candidate)
                        if isinstance(data, dict):
                            return data
                    except (json.JSONDecodeError, ValueError):
                        pass
                    break

    return None


def _build_prompt(rubric: str, target_content: str, transcript) -> str:
    parts = []
    parts.append("You are an evaluator. Grade the following content against the rubric below.")
    parts.append("")
    parts.append("## Rubric")
    parts.append(rubric)
    parts.append("")
    parts.append("## Content to Evaluate")
    parts.append(target_content)
    if transcript:
        parts.append("")
        parts.append("## Transcript")
        parts.append(json.dumps(transcript, indent=2))
    parts.append("")
    parts.append(
        'Respond with ONLY a JSON object. No preamble. No explanation. '
        'Format: {"score": <float 0.0-1.0>, "evidence": "<brief explanation>"}'
    )
    return "\n".join(parts)


def _build_command(provider: str, prompt: str) -> list[str]:
    if provider == CLAUDE_PROVIDER:
        return [
            "claude",
            "-p",
            prompt,
            "--output-format",
            "stream-json",
            "--verbose",
            "--max-turns",
            "1",
        ]
    if provider == CODEX_PROVIDER:
        return [
            "codex",
            "exec",
            "--json",
            "--ephemeral",
            "--skip-git-repo-check",
            prompt,
        ]
    raise ValueError(f"Unsupported model grader provider: {provider}")


def _run_model_command(provider: str, prompt: str):
    cmd = _build_command(provider, prompt)
    return subprocess.run(cmd, capture_output=True, text=True, timeout=120)


def _extract_assistant_text(provider: str, raw_stdout: str) -> str | None:
    transcript = normalize_transcript(provider, raw_stdout)
    return extract_assistant_text(transcript)


def grade_with_model(
    rubric: str,
    target_content: str,
    transcript=None,
    threshold: float = _PASS_THRESHOLD,
    provider: str = CLAUDE_PROVIDER,
) -> CheckResult:
    """Invoke the selected judge provider and return a CheckResult."""
    prompt = _build_prompt(rubric, target_content, transcript)

    try:
        proc = _run_model_command(provider, prompt)
    except subprocess.TimeoutExpired as exc:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"{provider} timed out after {exc.timeout}s",
            score=0.0,
        )
    except FileNotFoundError as exc:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"{provider} binary not found: {exc}",
            score=0.0,
        )

    if proc.returncode != 0:
        stderr = proc.stderr or ""
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"{provider} exited with code {proc.returncode}: {stderr}".strip(": "),
            score=0.0,
        )

    raw = proc.stdout or ""
    assistant_text = _extract_assistant_text(provider, raw)
    if assistant_text is None:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=(
                f"Model grader returned no assistant text in {provider} stream. "
                f"Raw (first 500 chars): {raw[:500]}"
            ),
            score=0.0,
        )

    data = _extract_json(assistant_text)
    if data is None:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"Model grader returned unparseable response: {assistant_text[:500]}",
            score=0.0,
        )

    try:
        if "score" not in data or "evidence" not in data:
            raise ValueError("missing required fields")
        score = data["score"]
        if not isinstance(score, (int, float)) or isinstance(score, bool):
            raise ValueError("score is not a number")
        score = float(score)
        evidence = data["evidence"]
    except (ValueError, KeyError):
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"Model grader returned unparseable response: {assistant_text[:500]}",
            score=0.0,
        )

    return CheckResult(
        type="model_grade",
        description="Model grade",
        passed=score >= threshold,
        evidence=evidence,
        score=score,
    )


__all__ = ["grade_with_model", "_extract_json"]
