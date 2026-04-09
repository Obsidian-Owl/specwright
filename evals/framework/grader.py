"""Eval framework grader — check functions and grading orchestration."""

import glob as glob_mod
import json
import os
import re
import shlex
import subprocess
import time
from typing import Any, Dict, List, Optional


# ---------------------------------------------------------------------------
# Result type
# ---------------------------------------------------------------------------

class CheckResult:
    """Result of a single grader check."""

    def __init__(
        self,
        type: str = "",
        description: str = "",
        passed: Optional[bool] = None,
        evidence: str = "",
        score: float = 0.0,
    ):
        self.type = type
        self.description = description
        self.passed = passed
        self.evidence = evidence
        self.score = score


# ---------------------------------------------------------------------------
# Valid state transitions
# ---------------------------------------------------------------------------

VALID_TRANSITIONS = {
    (None, "designing"),
    ("designing", "planning"),
    ("designing", "building"),
    ("planning", "building"),
    ("building", "verifying"),
    ("verifying", "building"),
    ("verifying", "shipped"),
    ("shipped", "building"),
}

# ---------------------------------------------------------------------------
# Named constants
# ---------------------------------------------------------------------------

WORKFLOW_JSON_PATH = os.path.join(".specwright", "state", "workflow.json")
FILE_CONTENT_EVIDENCE_LIMIT = 200
TEST_OUTPUT_EVIDENCE_LIMIT = 500
HEADING_PATTERN = r"^## (.+)"
ID_PATTERN = r"AC-\d+"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _load_workflow_json(workdir: str) -> Dict:
    """Read and parse workflow.json from workdir. Raises on error."""
    path = os.path.join(workdir, WORKFLOW_JSON_PATH)
    with open(path, "r") as f:
        return json.load(f)


def _traverse_dotted_path(data: Any, field: str) -> Any:
    """Traverse a dotted key path in a nested dict. Raises KeyError on missing."""
    parts = field.split(".")
    current = data
    for part in parts:
        if not isinstance(current, dict):
            raise KeyError(f"Cannot traverse into non-dict at key '{part}'")
        if part not in current:
            raise KeyError(f"Key '{part}' not found")
        current = current[part]
    return current


def _snapshot_status(snapshot: Dict) -> Optional[str]:
    """Extract currentWork status from a snapshot, or None if workflow_state is None."""
    workflow_state = snapshot.get("workflow_state")
    if workflow_state is None:
        return None
    current_work = workflow_state.get("currentWork")
    if current_work is None:
        return None
    return current_work.get("status")


def _check_passed(passed: bool) -> float:
    """Return 1.0 for pass, 0.0 for fail."""
    return 1.0 if passed else 0.0


# ---------------------------------------------------------------------------
# Check functions
# ---------------------------------------------------------------------------

def check_file_exists(path: str, workdir: str) -> CheckResult:
    """Return passed=True when a file exists at workdir/path."""
    full_path = os.path.join(workdir, path)
    exists = os.path.exists(full_path)
    if exists:
        return CheckResult(
            type="file_exists",
            description=f"File exists: {path}",
            passed=True,
            evidence=f"Found: {full_path}",
            score=1.0,
        )
    return CheckResult(
        type="file_exists",
        description=f"File exists: {path}",
        passed=False,
        evidence=f"Not found: {path} in {workdir}",
        score=0.0,
    )


def check_file_not_exists(path: str, workdir: str) -> CheckResult:
    """Return passed=True when no file matches workdir/path.

    Supports glob patterns (e.g., '.specwright/work/*/design.md').
    """
    full_path = os.path.join(workdir, path)
    # Support glob patterns — expand and check for matches
    if any(c in path for c in ("*", "?", "[")):
        matches = glob_mod.glob(full_path, recursive=True)
        if not matches:
            return CheckResult(
                type="file_not_exists",
                description=f"File not exists: {path}",
                passed=True,
                evidence=f"Confirmed absent: {path} (glob matched 0 files)",
                score=1.0,
            )
        return CheckResult(
            type="file_not_exists",
            description=f"File not exists: {path}",
            passed=False,
            evidence=f"Found {len(matches)} match(es): {', '.join(matches)}",
            score=0.0,
        )
    # Literal path
    if not os.path.exists(full_path):
        return CheckResult(
            type="file_not_exists",
            description=f"File not exists: {path}",
            passed=True,
            evidence=f"Confirmed absent: {path}",
            score=1.0,
        )
    return CheckResult(
        type="file_not_exists",
        description=f"File not exists: {path}",
        passed=False,
        evidence=f"Found (should not exist): {path} at {full_path}",
        score=0.0,
    )


def check_file_contains(path: str, pattern: str, workdir: str) -> CheckResult:
    """Return passed=True when pattern matches file content via re.search."""
    full_path = os.path.join(workdir, path)
    try:
        with open(full_path, "r") as f:
            content = f.read()
    except FileNotFoundError:
        return CheckResult(
            type="file_contains",
            description=f"File contains pattern: {pattern}",
            passed=False,
            evidence=f"File not found: {path}",
            score=0.0,
        )
    except OSError as exc:
        return CheckResult(
            type="file_contains",
            description=f"File contains pattern: {pattern}",
            passed=False,
            evidence=f"Error reading {path}: {exc}",
            score=0.0,
        )

    if re.search(pattern, content):
        return CheckResult(
            type="file_contains",
            description=f"File contains pattern: {pattern}",
            passed=True,
            evidence=f"Pattern matched in {path}",
            score=1.0,
        )

    truncated = content[:FILE_CONTENT_EVIDENCE_LIMIT]
    return CheckResult(
        type="file_contains",
        description=f"File contains pattern: {pattern}",
        passed=False,
        evidence=f"Pattern not found in {path}. Content: {truncated}",
        score=0.0,
    )


def check_file_not_contains(path: str, pattern: str, workdir: str) -> CheckResult:
    """Return passed=True when pattern does NOT match file content.

    A missing file returns passed=False (not vacuous truth). Pair with
    a file_exists check if you need to distinguish missing from clean.
    """
    full_path = os.path.join(workdir, path)
    try:
        with open(full_path, "r") as f:
            content = f.read()
    except FileNotFoundError:
        return CheckResult(
            type="file_not_contains",
            description=f"File not contains pattern: {pattern}",
            passed=False,
            evidence=f"File not found: {path}",
            score=0.0,
        )
    except OSError as exc:
        return CheckResult(
            type="file_not_contains",
            description=f"File not contains pattern: {pattern}",
            passed=False,
            evidence=f"Error reading {path}: {exc}",
            score=0.0,
        )

    if re.search(pattern, content):
        return CheckResult(
            type="file_not_contains",
            description=f"File not contains pattern: {pattern}",
            passed=False,
            evidence=f"Pattern found in {path} (should be absent)",
            score=0.0,
        )

    return CheckResult(
        type="file_not_contains",
        description=f"File not contains pattern: {pattern}",
        passed=True,
        evidence=f"Pattern confirmed absent in {path}",
        score=1.0,
    )


def check_tests_pass(command: str, workdir: str) -> CheckResult:
    """Return passed=True when subprocess exits with code 0.

    Note: command is split via shlex.split(). Eval definitions that need
    shell features (pipes, globs) should use explicit shell invocation
    in the command string (e.g., "bash -c 'cmd1 | cmd2'").
    """
    proc = subprocess.run(
        shlex.split(command),
        cwd=workdir,
        capture_output=True,
        text=True,
    )
    if proc.returncode == 0:
        return CheckResult(
            type="tests_pass",
            description=f"Tests pass: {command}",
            passed=True,
            evidence=f"Command exited 0",
            score=1.0,
        )

    combined = (proc.stdout or "") + (proc.stderr or "")
    tail = combined[-TEST_OUTPUT_EVIDENCE_LIMIT:]
    return CheckResult(
        type="tests_pass",
        description=f"Tests pass: {command}",
        passed=False,
        evidence=f"Command exited {proc.returncode}. Output (last {TEST_OUTPUT_EVIDENCE_LIMIT} chars): {tail}",
        score=0.0,
    )


def check_state(field: str, expected: Any, workdir: str) -> CheckResult:
    """Return passed=True when dotted field path in workflow.json equals expected."""
    try:
        data = _load_workflow_json(workdir)
    except FileNotFoundError:
        return CheckResult(
            type="state",
            description=f"State field: {field}",
            passed=False,
            evidence=f"workflow.json not found in {workdir}",
            score=0.0,
        )
    except (OSError, json.JSONDecodeError) as exc:
        return CheckResult(
            type="state",
            description=f"State field: {field}",
            passed=False,
            evidence=f"Error reading workflow.json: {exc}",
            score=0.0,
        )

    try:
        actual = _traverse_dotted_path(data, field)
    except KeyError as exc:
        return CheckResult(
            type="state",
            description=f"State field: {field}",
            passed=False,
            evidence=f"Path not found: {exc}",
            score=0.0,
        )

    if actual == expected:
        return CheckResult(
            type="state",
            description=f"State field: {field}",
            passed=True,
            evidence=f"{field} = {actual!r}",
            score=1.0,
        )

    return CheckResult(
        type="state",
        description=f"State field: {field}",
        passed=False,
        evidence=f"Expected {expected!r}, got {actual!r}",
        score=0.0,
    )


def check_state_transition(
    expected_sequence: List[str], snapshots: List[Dict]
) -> CheckResult:
    """Validate that snapshot statuses follow valid transitions and match expected_sequence."""
    if len(snapshots) < 2:
        return CheckResult(
            type="state_transition",
            description="State transition validation",
            passed=False,
            evidence="Insufficient snapshots for transition validation",
            score=0.0,
        )

    if len(expected_sequence) != len(snapshots):
        return CheckResult(
            type="state_transition",
            description="State transition validation",
            passed=False,
            evidence=(
                f"expected_sequence length {len(expected_sequence)} does not match "
                f"snapshots length {len(snapshots)}"
            ),
            score=0.0,
        )

    actual_statuses = [_snapshot_status(s) for s in snapshots]

    # Check actual matches expected at each step
    for i, (actual, expected) in enumerate(zip(actual_statuses, expected_sequence)):
        if actual != expected:
            return CheckResult(
                type="state_transition",
                description="State transition validation",
                passed=False,
                evidence=(
                    f"Snapshot {i}: expected status {expected!r}, got {actual!r}"
                ),
                score=0.0,
            )

    # Validate consecutive pairs against VALID_TRANSITIONS
    for i in range(len(actual_statuses) - 1):
        pair = (actual_statuses[i], actual_statuses[i + 1])
        if pair not in VALID_TRANSITIONS:
            return CheckResult(
                type="state_transition",
                description="State transition validation",
                passed=False,
                evidence=(
                    f"Invalid transition at step {i}: {pair[0]!r} -> {pair[1]!r}"
                ),
                score=0.0,
            )

    return CheckResult(
        type="state_transition",
        description="State transition validation",
        passed=True,
        evidence=f"All {len(actual_statuses) - 1} transitions valid",
        score=1.0,
    )


def check_artifact_reference(
    source: str, target: str, check: str, workdir: str
) -> CheckResult:
    """Verify target file references headings or IDs extracted from source file.

    Extracts headings (## ) or IDs (AC-\\d+) from the source file and verifies
    each appears in the target file.
    """
    source_path = os.path.join(workdir, source)
    target_path = os.path.join(workdir, target)

    try:
        with open(source_path, "r") as f:
            source_content = f.read()
    except (FileNotFoundError, OSError) as exc:
        return CheckResult(
            type="artifact_reference",
            description=f"Artifact reference ({check}): {source} -> {target}",
            passed=False,
            evidence=f"Source file not found: {source}: {exc}",
            score=0.0,
        )

    try:
        with open(target_path, "r") as f:
            target_content = f.read()
    except (FileNotFoundError, OSError) as exc:
        return CheckResult(
            type="artifact_reference",
            description=f"Artifact reference ({check}): {source} -> {target}",
            passed=False,
            evidence=f"Target file not found: {target}: {exc}",
            score=0.0,
        )

    if check == "headings_referenced":
        items = re.findall(HEADING_PATTERN, source_content, re.MULTILINE)
    elif check == "ids_referenced":
        items = re.findall(ID_PATTERN, source_content)
    else:
        return CheckResult(
            type="artifact_reference",
            description=f"Artifact reference ({check}): {source} -> {target}",
            passed=False,
            evidence=f"Unknown check type: {check}",
            score=0.0,
        )

    if not items:
        return CheckResult(
            type="artifact_reference",
            description=f"Artifact reference ({check}): {source} -> {target}",
            passed=False,
            evidence=f"Source file contains no extractable references",
            score=0.0,
        )

    missing = [item for item in items if item not in target_content]
    if not missing:
        return CheckResult(
            type="artifact_reference",
            description=f"Artifact reference ({check}): {source} -> {target}",
            passed=True,
            evidence=f"All {len(items)} {check} from {source} found in {target}",
            score=1.0,
        )

    return CheckResult(
        type="artifact_reference",
        description=f"Artifact reference ({check}): {source} -> {target}",
        passed=False,
        evidence=f"Missing references in {target}: {', '.join(missing)}",
        score=0.0,
    )


def check_git(check_type: str, workdir: str, **kwargs) -> CheckResult:
    """Run a git check against the repository at workdir."""
    if check_type == "branch_exists":
        branch = kwargs.get("branch", "")
        proc = subprocess.run(
            ["git", "show-ref", "--verify", f"refs/heads/{branch}"],
            cwd=workdir,
            capture_output=True,
            text=True,
        )
        passed = proc.returncode == 0
        return CheckResult(
            type="git",
            description=f"Git branch exists: {branch}",
            passed=passed,
            evidence=f"Branch '{branch}' {'found' if passed else 'not found'}",
            score=_check_passed(passed),
        )

    if check_type == "commit_count":
        expected_count = kwargs.get("expected", 1)
        proc = subprocess.run(
            ["git", "rev-list", "--count", "HEAD"],
            cwd=workdir,
            capture_output=True,
            text=True,
        )
        try:
            actual_count = int(proc.stdout.strip())
        except ValueError:
            return CheckResult(
                type="git",
                description=f"Git commit count == {expected_count}",
                passed=False,
                evidence=f"Could not parse commit count: {proc.stdout!r}",
                score=0.0,
            )
        passed = actual_count == expected_count
        return CheckResult(
            type="git",
            description=f"Git commit count == {expected_count}",
            passed=passed,
            evidence=f"Commit count: {actual_count} (expected: {expected_count})",
            score=_check_passed(passed),
        )

    if check_type == "no_uncommitted_changes":
        proc = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=workdir,
            capture_output=True,
            text=True,
        )
        dirty = proc.stdout.strip()
        if not dirty:
            return CheckResult(
                type="git",
                description="Git working tree clean",
                passed=True,
                evidence="No uncommitted changes",
                score=1.0,
            )
        return CheckResult(
            type="git",
            description="Git working tree clean",
            passed=False,
            evidence=f"Uncommitted changes:\n{dirty}",
            score=0.0,
        )

    return CheckResult(
        type="git",
        description=f"Git check: {check_type}",
        passed=False,
        evidence=f"Unknown git check type: {check_type}",
        score=0.0,
    )


def check_gate_results(expected: Dict[str, str], workdir: str) -> CheckResult:
    """Return passed=True when all gates[name].status match expected."""
    try:
        data = _load_workflow_json(workdir)
    except FileNotFoundError:
        return CheckResult(
            type="gate_results",
            description="Gate results",
            passed=False,
            evidence=f"workflow.json not found in {workdir}",
            score=0.0,
        )
    except (OSError, json.JSONDecodeError) as exc:
        return CheckResult(
            type="gate_results",
            description="Gate results",
            passed=False,
            evidence=f"Error reading workflow.json: {exc}",
            score=0.0,
        )

    gates = data.get("gates", {})
    mismatches = []
    for gate_name, expected_status in expected.items():
        gate = gates.get(gate_name)
        if gate is None:
            mismatches.append(f"{gate_name}: missing (expected {expected_status!r})")
        else:
            actual_status = gate.get("verdict") or gate.get("status")
            if actual_status != expected_status:
                mismatches.append(
                    f"{gate_name}: {actual_status!r} (expected {expected_status!r})"
                )

    if not mismatches:
        return CheckResult(
            type="gate_results",
            description="Gate results",
            passed=True,
            evidence=f"All {len(expected)} gate(s) match expected status",
            score=1.0,
        )

    return CheckResult(
        type="gate_results",
        description="Gate results",
        passed=False,
        evidence=f"Gate mismatches: {'; '.join(mismatches)}",
        score=0.0,
    )


# ---------------------------------------------------------------------------
# Transcript final block check
# ---------------------------------------------------------------------------

def _extract_final_assistant_text(transcript: List[Dict]) -> str:
    """Walk a stream-json transcript and return the final user-visible text.

    Preference order:
    1. The 'result' field of the final 'result' event (canonical Claude Code
       final-output channel).
    2. The concatenated text content of the LAST 'assistant' event with
       text-type content blocks.

    Returns empty string if neither source has content.
    """
    if not transcript:
        return ""

    # Prefer the canonical result event
    for event in reversed(transcript):
        if event.get("type") == "result":
            result_text = event.get("result")
            if isinstance(result_text, str) and result_text.strip():
                return result_text

    # Fall back to last assistant text content
    for event in reversed(transcript):
        if event.get("type") != "assistant":
            continue
        message = event.get("message") or {}
        content = message.get("content") or []
        if not isinstance(content, list):
            continue
        text_parts = [
            block.get("text", "")
            for block in content
            if isinstance(block, dict) and block.get("type") == "text"
        ]
        text = "".join(text_parts).strip()
        if text:
            return text

    return ""


def _final_non_empty_block(text: str) -> List[str]:
    """Return the final non-empty block of lines from a text body.

    A block is a run of consecutive non-empty lines, separated from prior
    content by one or more blank lines. Trailing whitespace on the text is
    stripped before splitting.
    """
    if not text:
        return []
    stripped = text.rstrip()
    lines = stripped.split("\n")
    block: List[str] = []
    for line in reversed(lines):
        if line.strip() == "":
            if block:
                break
            continue
        block.append(line)
    block.reverse()
    return block


def check_transcript_final_block(
    line_patterns: List[str],
    transcript: Optional[List[Dict]],
    forbidden_substrings: Optional[List[str]] = None,
) -> CheckResult:
    """Assert the transcript's final non-empty block matches per-line regex patterns.

    Args:
        line_patterns: list of regex patterns, one per expected line. The
            block must contain exactly len(line_patterns) lines, each
            matching the corresponding pattern (re.search semantics).
        transcript: stream-json events from RunResult.transcript.
        forbidden_substrings: optional list of literal substrings that must
            NOT appear anywhere in the final assistant text.

    Returns CheckResult.passed=True iff:
        - the final non-empty block has exactly the expected number of lines
        - every line matches its corresponding regex
        - none of the forbidden substrings appear anywhere in the final text
    """
    if transcript is None:
        return CheckResult(
            type="transcript_final_block",
            description="Transcript final block matches",
            passed=False,
            evidence="No transcript available (transcript is None)",
            score=0.0,
        )

    final_text = _extract_final_assistant_text(transcript)
    if not final_text:
        return CheckResult(
            type="transcript_final_block",
            description="Transcript final block matches",
            passed=False,
            evidence="Transcript contains no extractable assistant text",
            score=0.0,
        )

    # Forbidden substring check (run before block extraction so we can report
    # leakage even if the structural assertion would pass)
    forbidden_substrings = forbidden_substrings or []
    found_forbidden = [s for s in forbidden_substrings if s in final_text]
    if found_forbidden:
        return CheckResult(
            type="transcript_final_block",
            description="Transcript final block matches",
            passed=False,
            evidence=(
                f"Forbidden substring(s) present in final text: "
                f"{', '.join(repr(s) for s in found_forbidden)}"
            ),
            score=0.0,
        )

    block = _final_non_empty_block(final_text)
    if len(block) != len(line_patterns):
        return CheckResult(
            type="transcript_final_block",
            description="Transcript final block matches",
            passed=False,
            evidence=(
                f"Expected {len(line_patterns)} lines in final block, "
                f"got {len(block)}: {block!r}"
            ),
            score=0.0,
        )

    for idx, (line, pattern) in enumerate(zip(block, line_patterns), start=1):
        if not re.search(pattern, line):
            return CheckResult(
                type="transcript_final_block",
                description="Transcript final block matches",
                passed=False,
                evidence=(
                    f"Line {idx} does not match pattern. "
                    f"Pattern: {pattern!r}. Line: {line!r}"
                ),
                score=0.0,
            )

    return CheckResult(
        type="transcript_final_block",
        description="Transcript final block matches",
        passed=True,
        evidence=(
            f"Final block matches {len(line_patterns)}-line template"
            + (
                f"; no forbidden substrings present ({len(forbidden_substrings)} checked)"
                if forbidden_substrings
                else ""
            )
        ),
        score=1.0,
    )


# ---------------------------------------------------------------------------
# Grading orchestration
# ---------------------------------------------------------------------------

def _dispatch_expectation(
    expectation: Dict,
    workdir: str,
    snapshots: Optional[List[Dict]],
    transcript: Optional[List[Dict]] = None,
    provider: str = "claude",
) -> CheckResult:
    """Dispatch a single expectation dict to the appropriate check function."""
    check_type = expectation.get("type", "")

    if check_type == "transcript_final_block":
        return check_transcript_final_block(
            expectation.get("line_patterns", []),
            transcript,
            forbidden_substrings=expectation.get("forbidden_substrings"),
        )

    if check_type == "file_exists":
        return check_file_exists(expectation["path"], workdir)

    if check_type == "file_not_exists":
        return check_file_not_exists(expectation["path"], workdir)

    if check_type == "file_contains":
        return check_file_contains(
            expectation["path"], expectation["pattern"], workdir
        )

    if check_type == "file_not_contains":
        return check_file_not_contains(
            expectation["path"], expectation["pattern"], workdir
        )

    if check_type == "tests_pass":
        return check_tests_pass(expectation["command"], workdir)

    if check_type == "state":
        return check_state(expectation["field"], expectation["expected"], workdir)

    if check_type == "state_transition":
        return check_state_transition(
            expectation["expected_sequence"], snapshots or []
        )

    if check_type == "artifact_reference":
        return check_artifact_reference(
            expectation["source"],
            expectation["target"],
            expectation["check"],
            workdir,
        )

    if check_type == "git":
        kwargs = {k: v for k, v in expectation.items() if k not in ("type",)}
        check_subtype = kwargs.pop("check_type", check_type)
        return check_git(check_subtype, workdir, **kwargs)

    if check_type == "gate_results":
        return check_gate_results(expectation["expected"], workdir)

    if check_type == "model_grade":
        try:
            from evals.framework.model_grader import grade_with_model
            rubric = expectation.get("rubric", "")
            target_path = expectation.get("target", "")
            target_content = ""
            if target_path and target_path != "$TRANSCRIPT":
                full_path = os.path.join(workdir, target_path)
                try:
                    with open(full_path) as f:
                        target_content = f.read()
                except (FileNotFoundError, OSError):
                    target_content = f"[File not found: {target_path}]"
            threshold = expectation.get("threshold")
            kwargs = {}
            if threshold is not None:
                kwargs["threshold"] = threshold
            kwargs["provider"] = provider
            if target_path == "$TRANSCRIPT" and snapshots is not None:
                kwargs["transcript"] = snapshots
            return grade_with_model(rubric, target_content, **kwargs)
        except ImportError:
            return CheckResult(
                type="model_grade",
                description="Model grade (skipped)",
                passed=None,
                evidence="Skipped: model grading not available",
                score=0.0,
            )

    return CheckResult(
        type=check_type or "unknown",
        description=f"Unknown expectation type: {check_type}",
        passed=False,
        evidence=f"No handler for expectation type: {check_type!r}",
        score=0.0,
    )


def grade_eval(
    eval_case: Dict,
    workdir: str,
    snapshots: Optional[List[Dict]] = None,
    transcript: Optional[List[Dict]] = None,
    provider: str = "claude",
) -> Dict:
    """Grade an eval case against a workdir. Return grading results dict.

    Args:
        eval_case: parsed eval entry from a suite file.
        workdir: directory in which the skill ran.
        snapshots: workdir state snapshots from the chainer (multi-skill evals).
        transcript: stream-json events from RunResult.transcript (single-skill).
    """
    start_time = time.time()

    expectations_input = eval_case.get("expectations", [])
    results = []
    passed_count = 0
    failed_count = 0
    skipped_count = 0

    for expectation in expectations_input:
        result = _dispatch_expectation(
            expectation,
            workdir,
            snapshots,
            transcript,
            provider=provider,
        )
        result_dict = {
            "type": result.type,
            "description": result.description,
            "passed": result.passed,
            "evidence": result.evidence,
            "score": result.score,
        }
        results.append(result_dict)

        if result.passed is None:
            skipped_count += 1
        elif result.passed:
            passed_count += 1
        else:
            failed_count += 1

    total = len(results)
    pass_rate = passed_count / total if total > 0 else 0.0

    elapsed_s = time.time() - start_time

    return {
        "expectations": results,
        "summary": {
            "total": total,
            "passed": passed_count,
            "failed": failed_count,
            "skipped": skipped_count,
            "pass_rate": pass_rate,
        },
        "timing": {
            "duration_ms": round(elapsed_s * 1000, 2),
        },
    }
