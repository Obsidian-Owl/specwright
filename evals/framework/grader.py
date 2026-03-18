"""Eval framework grader — check functions and grading orchestration."""

import json
import os
import re
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
    """Return passed=True when a file does NOT exist at workdir/path."""
    full_path = os.path.join(workdir, path)
    exists = os.path.exists(full_path)
    if not exists:
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


def check_tests_pass(command: str, workdir: str) -> CheckResult:
    """Return passed=True when subprocess exits with code 0."""
    proc = subprocess.run(
        command,
        shell=True,
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
            f"git show-ref --verify refs/heads/{branch}",
            shell=True,
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
        expected_count = kwargs.get("expected", kwargs.get("min_count", 1))
        proc = subprocess.run(
            "git rev-list --count HEAD",
            shell=True,
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
            "git status --porcelain",
            shell=True,
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
            actual_status = gate.get("status")
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
# Grading orchestration
# ---------------------------------------------------------------------------

def _dispatch_expectation(
    expectation: Dict, workdir: str, snapshots: Optional[List[Dict]]
) -> CheckResult:
    """Dispatch a single expectation dict to the appropriate check function."""
    check_type = expectation.get("type", "")

    if check_type == "file_exists":
        return check_file_exists(expectation["path"], workdir)

    if check_type == "file_not_exists":
        return check_file_not_exists(expectation["path"], workdir)

    if check_type == "file_contains":
        return check_file_contains(
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
    eval_case: Dict, workdir: str, snapshots: Optional[List[Dict]] = None
) -> Dict:
    """Grade an eval case against a workdir. Return grading results dict."""
    start_time = time.time()

    expectations_input = eval_case.get("expectations", [])
    results = []
    passed_count = 0
    failed_count = 0
    skipped_count = 0

    for expectation in expectations_input:
        result = _dispatch_expectation(expectation, workdir, snapshots)
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
