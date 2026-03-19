"""Eval framework orchestrator — runs eval suites, grades results, writes outputs."""

import json
import os
import shutil
import sys
import tempfile
import time
import uuid
from datetime import datetime, timezone
from typing import Dict, List, Optional

from evals.framework.runner import ClaudeCodeRunner, RunResult
from evals.framework.chainer import run_sequence, ChainResult
from evals.framework.grader import grade_eval
from evals.framework.setup import setup_fixture, setup_repo
from evals.framework.aggregator import aggregate_results
from evals.framework import prompts

# Base directory for resolving fixture/suite paths
_EVALS_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------------------------------------------------------------------------
# Named constants
# ---------------------------------------------------------------------------

_LAYER_SKILL = "skill"
_LAYER_INTEGRATION = "integration"
_LAYER_WORKFLOW = "workflow"
_GRADING_FILENAME = "grading.json"
_BENCHMARK_FILENAME = "benchmark.json"
_CONFIG_FILENAME = "config.json"
_EVALS_SUBDIR = "evals"
_TRIAL_PREFIX = "trial-"
_RESULTS_RUN_PREFIX = "run-"
_SKILL_NAME_PREFIX = "sw-"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _resolve_seed(suite_path: str, seed_id: str) -> Dict:
    """Load seeds.json and find the entry matching seed_id."""
    with open(suite_path) as f:
        seeds_data = json.load(f)
    for seed in seeds_data.get("seeds", []):
        if seed.get("id") == seed_id:
            return seed
    raise FileNotFoundError(f"Seed '{seed_id}' not found in {suite_path}")


def _determine_layer(eval_case: Dict) -> str:
    """Return the layer string based on which field is present in the eval case."""
    if "skill" in eval_case:
        return _LAYER_SKILL
    if "sequence" in eval_case:
        return _LAYER_INTEGRATION
    return _LAYER_WORKFLOW


def _skill_to_template_name(skill_name: str) -> str:
    """Convert a skill name like 'sw-build' to a prompts template name 'build'."""
    if skill_name.startswith(_SKILL_NAME_PREFIX):
        return skill_name[len(_SKILL_NAME_PREFIX):]
    return skill_name


def _resolve_prompt_layer1(eval_case: Dict) -> str:
    """Resolve prompt string for a Layer 1 (skill) eval case."""
    template_name = eval_case.get("prompt_template", "")
    prompt_args = eval_case.get("prompt_args", {})
    template_fn = getattr(prompts, template_name, None)
    if template_fn is None:
        raise ValueError(f"Unknown prompt template: '{template_name}'")
    return template_fn(**prompt_args)


def _resolve_prompts_layer2(eval_case: Dict) -> Dict[str, str]:
    """Build a dict of skill -> prompt string for a Layer 2/3 eval case."""
    skills = eval_case.get("sequence") or eval_case.get("workflow") or []
    prompt_args = eval_case.get("prompt_args", {})
    problem_statement = prompt_args.get("problem_statement")

    prompts_dict = {}
    for i, skill_name in enumerate(skills):
        template_name = _skill_to_template_name(skill_name)
        template_fn = getattr(prompts, template_name, None)
        if template_fn is None:
            raise ValueError(f"Unknown prompt template: '{template_name}' for skill '{skill_name}'")

        # Pass problem_statement to the first skill if it is the design skill
        if i == 0 and problem_statement is not None and template_name == "design":
            prompts_dict[skill_name] = template_fn(problem_statement=problem_statement)
        else:
            prompts_dict[skill_name] = template_fn()

    return prompts_dict


def _write_grading_json(
    trial_dir: str,
    eval_id: str,
    trial_num: int,
    grade_result: Dict,
) -> None:
    """Write grading.json with flattened top-level fields."""
    os.makedirs(trial_dir, exist_ok=True)
    output = dict(grade_result)
    output["eval_id"] = eval_id
    output["trial"] = trial_num
    output["pass_rate"] = grade_result.get("summary", {}).get("pass_rate", 0.0)
    output["duration_ms"] = grade_result.get("timing", {}).get("duration_ms", 0)
    path = os.path.join(trial_dir, _GRADING_FILENAME)
    with open(path, "w") as f:
        json.dump(output, f, indent=2)


def _write_error_grading_json(
    trial_dir: str,
    eval_id: str,
    trial_num: int,
    error: str,
    duration_ms: float,
) -> None:
    """Write an error grading.json when setup fails."""
    os.makedirs(trial_dir, exist_ok=True)
    output = {
        "eval_id": eval_id,
        "trial": trial_num,
        "pass_rate": 0.0,
        "duration_ms": duration_ms,
        "error": error,
        "expectations": [],
        "summary": {
            "total": 0,
            "passed": 0,
            "failed": 0,
            "skipped": 0,
            "pass_rate": 0.0,
        },
        "timing": {"duration_ms": duration_ms},
    }
    path = os.path.join(trial_dir, _GRADING_FILENAME)
    with open(path, "w") as f:
        json.dump(output, f, indent=2)


def _trial_dir(results_dir: str, eval_id: str, trial_num: int) -> str:
    """Return the trial output directory path."""
    return os.path.join(
        results_dir, _EVALS_SUBDIR, eval_id, f"{_TRIAL_PREFIX}{trial_num}"
    )


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def run_single_eval(
    eval_case: Dict,
    trial_num: int,
    results_dir: str,
    runner,
    timeout: int = 300,
    suite_dir: Optional[str] = None,
) -> None:
    """Run a single eval case trial: setup, execute, grade, write results."""
    eval_id = eval_case["id"]
    trial_dir = _trial_dir(results_dir, eval_id, trial_num)

    print(f"Running eval {eval_id} trial {trial_num} ...", file=sys.stderr)

    start_time = time.time()

    # Setup: copy fixture or clone repo to a fresh temp workdir.
    seed = eval_case.get("seed", {})
    seed_type = seed.get("type", "fixture")
    workdir = os.path.join(tempfile.gettempdir(), f"eval-workdir-{uuid.uuid4().hex}")

    try:
        if seed_type == "repo":
            seed_id = seed.get("seed_id", "")
            seeds_path = os.path.join(suite_dir or _EVALS_BASE_DIR, "seeds.json")
            seed_entry = _resolve_seed(suite_path=seeds_path, seed_id=seed_id)
            repo_url = f"https://github.com/{seed_entry['repo']}.git"
            install_cmd = seed_entry.get("test_command", "npm install")
            setup_repo(repo_url, seed_entry["base_commit"], workdir,
                       install_command=install_cmd)
        else:
            raw_path = seed.get("path", "")
            fixture_path = os.path.join(_EVALS_BASE_DIR, raw_path) if raw_path else ""
            setup_fixture(fixture_path, workdir)
    except (FileNotFoundError, RuntimeError) as exc:
        elapsed_ms = round((time.time() - start_time) * 1000, 2)
        print(f"  ERROR: {exc}", file=sys.stderr)
        _write_error_grading_json(
            trial_dir=trial_dir,
            eval_id=eval_id,
            trial_num=trial_num,
            error=str(exc),
            duration_ms=elapsed_ms,
        )
        shutil.rmtree(workdir, ignore_errors=True)
        return

    layer = _determine_layer(eval_case)
    snapshots: List[Dict] = []
    exec_error: Optional[str] = None

    run_result = None

    try:
        try:
            if layer == _LAYER_SKILL:
                resolved_prompt = _resolve_prompt_layer1(eval_case)
                run_result = runner.run_skill(
                    skill=eval_case["skill"],
                    prompt=resolved_prompt,
                    workdir=workdir,
                    timeout=timeout,
                )
            else:
                skills = eval_case.get("sequence") or eval_case.get("workflow") or []
                prompts_dict = _resolve_prompts_layer2(eval_case)
                chain_result = run_sequence(
                    runner=runner,
                    skills=skills,
                    prompts=prompts_dict,
                    workdir=workdir,
                    timeout_per_skill=timeout,
                )
                snapshots = chain_result.snapshots
                if chain_result.steps:
                    run_result = chain_result.steps[-1]

        except Exception as exc:
            exec_error = f"{type(exc).__name__}: {exc}"

        grade_result = grade_eval(eval_case, workdir, snapshots)
        if exec_error:
            grade_result["error"] = exec_error

        # Add execution telemetry from runner
        if run_result is not None:
            grade_result["execution"] = {
                "exit_code": run_result.exit_code,
                "duration_ms": run_result.duration_ms,
                "tokens": run_result.tokens,
            }

        _write_grading_json(
            trial_dir=trial_dir,
            eval_id=eval_id,
            trial_num=trial_num,
            grade_result=grade_result,
        )

        pass_rate = grade_result.get("summary", {}).get("pass_rate", 0.0)
        print(f"  DONE (pass_rate: {pass_rate:.2f})", file=sys.stderr)

    finally:
        shutil.rmtree(workdir, ignore_errors=True)


def run_eval_suite(
    suite_path: str,
    trials: int = 1,
    timeout: int = 300,
    case_filter: Optional[str] = None,
    dry_run: bool = False,
    results_dir: Optional[str] = None,
) -> str:
    """Load evals.json, iterate cases x trials, aggregate, return results_dir."""
    try:
        validation_errors = validate_suite(suite_path)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"Error loading suite: {exc}", file=sys.stderr)
        return ""
    if validation_errors:
        for error in validation_errors:
            print(error, file=sys.stderr)
        return ""

    with open(suite_path) as f:
        suite_data = json.load(f)

    all_cases = suite_data.get("evals", [])

    if case_filter is not None:
        cases = [c for c in all_cases if c["id"] == case_filter]
    else:
        cases = all_cases

    if dry_run:
        for case in cases:
            seed_path = case.get("seed", {}).get("path", "")
            print(f"{case['id']}  {seed_path}", file=sys.stderr)
        return ""  # dry run produces no results directory

    timestamp = datetime.now(timezone.utc).isoformat()
    if results_dir is None:
        results_dir = os.path.join(
            _EVALS_BASE_DIR,
            "results",
            f"{_RESULTS_RUN_PREFIX}{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')}",
        )
    results_dir = os.path.abspath(results_dir)
    os.makedirs(results_dir, exist_ok=True)

    # Write config.json
    config = {
        "timestamp": timestamp,
        "suite": os.path.basename(os.path.dirname(suite_path)),
        "trials": trials,
        "timeout": timeout,
        "python_version": sys.version,
    }
    with open(os.path.join(results_dir, _CONFIG_FILENAME), "w") as f:
        json.dump(config, f, indent=2)

    runner = ClaudeCodeRunner()

    for case in cases:
        for trial_num in range(1, trials + 1):
            run_single_eval(
                eval_case=case,
                trial_num=trial_num,
                results_dir=results_dir,
                runner=runner,
                timeout=timeout,
                suite_dir=os.path.dirname(os.path.abspath(suite_path)),
            )

    benchmark = aggregate_results(results_dir)
    with open(os.path.join(results_dir, _BENCHMARK_FILENAME), "w") as f:
        json.dump(benchmark, f, indent=2)

    return results_dir


REGISTERED_TYPES = frozenset({
    "file_exists",
    "file_not_exists",
    "file_contains",
    "tests_pass",
    "state",
    "state_transition",
    "artifact_reference",
    "git",
    "gate_results",
    "model_grade",
})

REQUIRED_FIELDS = {
    "file_exists": ["path"],
    "file_not_exists": ["path"],
    "file_contains": ["path", "pattern"],
    "tests_pass": ["command"],
    "state": ["field", "expected"],
    "state_transition": ["expected_sequence"],
    "artifact_reference": ["source", "target", "check"],
    "git": [],
    "gate_results": ["expected"],
    "model_grade": ["rubric"],
}

REGISTERED_PROMPT_TEMPLATES = frozenset({
    "init", "design", "plan", "build", "verify", "ship",
})

_LAYER_FIELDS = ("skill", "sequence", "workflow")


def _validate_expectation(case_id: str, expectation: dict) -> list[str]:
    """Validate a single expectation dict. Returns list of error strings."""
    errors = []
    exp_type = expectation.get("type", "")

    if exp_type not in REGISTERED_TYPES:
        errors.append(
            f"[{case_id}] Unknown expectation type '{exp_type}'"
        )
        return errors

    for field in REQUIRED_FIELDS.get(exp_type, []):
        if field not in expectation:
            errors.append(
                f"[{case_id}] Expectation type '{exp_type}' is missing required field '{field}'"
            )

    return errors


def _validate_layer_fields(case_id: str, eval_case: dict) -> list[str]:
    """Validate exactly one layer field is present. Returns list of error strings."""
    present = [f for f in _LAYER_FIELDS if f in eval_case]
    if len(present) != 1:
        return [
            f"[{case_id}] Eval case must have exactly one of {_LAYER_FIELDS}, "
            f"found {len(present)}: {present}"
        ]
    return []


def _validate_prompt_template(case_id: str, eval_case: dict) -> list[str]:
    """Validate prompt_template for Layer 1 (skill) cases. Returns list of error strings."""
    if "skill" not in eval_case:
        return []

    if "prompt_template" not in eval_case:
        return [f"[{case_id}] Missing required field 'prompt_template' for skill-layer eval"]
    template = eval_case["prompt_template"]
    if template not in REGISTERED_PROMPT_TEMPLATES:
        return [
            f"[{case_id}] Unknown prompt_template '{template}'; "
            f"registered templates: {sorted(REGISTERED_PROMPT_TEMPLATES)}"
        ]
    return []


def _validate_seed_path(case_id: str, eval_case: dict) -> list[str]:
    """Validate fixture seed path exists on disk. Returns list of error strings."""
    seed = eval_case.get("seed", {})
    if seed.get("type") != "fixture":
        return []

    raw_path = seed.get("path", "")
    if not raw_path:
        return []

    resolved = os.path.join(_EVALS_BASE_DIR, raw_path)
    if not os.path.exists(resolved):
        return [
            f"[{case_id}] Fixture seed path does not exist: '{raw_path}'"
        ]
    return []


def validate_suite(suite_path: str) -> list[str]:
    """Validate an eval suite JSON file. Returns list of error strings (empty = valid)."""
    with open(suite_path) as f:
        suite_data = json.load(f)

    errors = []
    seen_ids: set[str] = set()
    for eval_case in suite_data.get("evals", []):
        case_id = eval_case.get("id", "<unknown>")
        if case_id in seen_ids:
            errors.append(f"[{case_id}] Duplicate case ID")
        seen_ids.add(case_id)

        errors.extend(_validate_layer_fields(case_id, eval_case))
        errors.extend(_validate_prompt_template(case_id, eval_case))
        errors.extend(_validate_seed_path(case_id, eval_case))

        for expectation in eval_case.get("expectations", []):
            errors.extend(_validate_expectation(case_id, expectation))

    return errors
