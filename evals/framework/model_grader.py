"""Eval framework model grader — grade eval outputs using claude as a judge."""

import json
import re
import subprocess

from evals.framework.grader import CheckResult

_PASS_THRESHOLD = 0.7


def _extract_json(text: str) -> dict | None:
    """Extract a JSON object from text that may contain fences, preamble, or trailing content.

    Tries three strategies in order:
    1. Direct parse (text is valid JSON)
    2. Strip markdown code fences and parse
    3. Regex-extract the first {...} block and parse

    Returns the parsed dict, or None if no valid JSON object found.
    """
    text = text.strip()

    # Strategy 1: direct parse
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            return data
    except (json.JSONDecodeError, ValueError):
        pass

    # Strategy 2: strip markdown fences
    stripped = re.sub(r'^```(?:json)?\s*\n?', '', text)
    stripped = re.sub(r'\n?```\s*$', '', stripped).strip()
    if stripped != text:
        try:
            data = json.loads(stripped)
            if isinstance(data, dict):
                return data
        except (json.JSONDecodeError, ValueError):
            pass

    # Strategy 3: find first JSON object via string-aware brace matching
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


def _extract_assistant_text(raw_stdout: str) -> str | None:
    """Extract the assistant's text response from NDJSON stream-json output.

    Parses each line as JSON, finds assistant messages, and extracts text content.
    Returns the concatenated text, or None if no text found.
    """
    texts = []
    for line in raw_stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        if event.get("type") != "assistant":
            continue
        message = event.get("message", {})
        if not isinstance(message, dict):
            continue
        content = message.get("content", [])
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "text":
                    text = block.get("text", "").strip()
                    if text:
                        texts.append(text)
        elif isinstance(content, str) and content.strip():
            texts.append(content.strip())
    return "\n".join(texts) if texts else None


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


def grade_with_model(rubric: str, target_content: str, transcript=None, threshold: float = _PASS_THRESHOLD) -> CheckResult:
    """Invoke claude -p with rubric prompt, return CheckResult."""
    prompt = _build_prompt(rubric, target_content, transcript)
    cmd = ["claude", "-p", prompt, "--output-format", "stream-json", "--verbose", "--max-turns", "1"]

    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired as exc:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"claude timed out after {exc.timeout}s",
            score=0.0,
        )
    except FileNotFoundError as exc:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"claude binary not found: {exc}",
            score=0.0,
        )

    if proc.returncode != 0:
        stderr = proc.stderr or ""
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"claude exited with code {proc.returncode}: {stderr}".strip(": "),
            score=0.0,
        )

    raw = proc.stdout or ""

    # Parse NDJSON stream to extract the assistant's text response
    assistant_text = _extract_assistant_text(raw)
    if assistant_text is None:
        return CheckResult(
            type="model_grade",
            description="Model grade",
            passed=False,
            evidence=f"Model grader returned no assistant text in stream. Raw (first 500 chars): {raw[:500]}",
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

    passed = score >= threshold
    return CheckResult(
        type="model_grade",
        description="Model grade",
        passed=passed,
        evidence=evidence,
        score=score,
    )
