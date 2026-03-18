"""Eval framework orchestrator — runs eval suites, grades results, writes outputs."""

import json
import os
import shutil
import subprocess
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
    template_fn = getattr(prompts, template_name)
    return template_fn(**prompt_args)


def _resolve_prompts_layer2(eval_case: Dict) -> Dict[str, str]:
    """Build a dict of skill -> prompt string for a Layer 2/3 eval case."""
    skills = eval_case.get("sequence") or eval_case.get("workflow") or []
    prompt_args = eval_case.get("prompt_args", {})
    problem_statement = prompt_args.get("problem_statement")

    prompts_dict = {}
    for i, skill_name in enumerate(skills):
        template_name = _skill_to_template_name(skill_name)
        template_fn = getattr(prompts, template_name)

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
    plugin_dir: Optional[str] = None,
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
            seed_entry = _resolve_seed(suite_path=os.path.join(
                _EVALS_BASE_DIR, "suites", "workflow", "seeds.json"
            ), seed_id=seed_id)
            repo_url = f"https://github.com/{seed_entry['repo']}.git"
            setup_repo(repo_url, seed_entry["base_commit"], workdir,
                       install_command="npm install")
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

    try:
        snapshots: List[Dict] = []

        if layer == _LAYER_SKILL:
            resolved_prompt = _resolve_prompt_layer1(eval_case)
            runner.run_skill(
                skill=eval_case["skill"],
                prompt=resolved_prompt,
                workdir=workdir,
                timeout=timeout,
                plugin_dir=plugin_dir,
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
                plugin_dir=plugin_dir,
            )
            snapshots = chain_result.snapshots

    except (subprocess.TimeoutExpired, RuntimeError):
        pass

    grade_result = grade_eval(eval_case, workdir, snapshots)

    _write_grading_json(
        trial_dir=trial_dir,
        eval_id=eval_id,
        trial_num=trial_num,
        grade_result=grade_result,
    )

    pass_rate = grade_result.get("summary", {}).get("pass_rate", 0.0)
    print(f"  DONE (pass_rate: {pass_rate:.2f})", file=sys.stderr)

    shutil.rmtree(workdir, ignore_errors=True)


def run_eval_suite(
    suite_path: str,
    trials: int = 1,
    timeout: int = 300,
    case_filter: Optional[str] = None,
    dry_run: bool = False,
    plugin_dir: Optional[str] = None,
    results_dir: Optional[str] = None,
) -> str:
    """Load evals.json, iterate cases x trials, aggregate, return results_dir."""
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
        # Return a placeholder path — dry run creates no results dir
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S")
        results_dir = os.path.join(
            os.path.dirname(suite_path),
            "..",
            "..",
            "results",
            f"{_RESULTS_RUN_PREFIX}{timestamp}",
        )
        return os.path.abspath(results_dir)

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
                plugin_dir=plugin_dir,
            )

    benchmark = aggregate_results(results_dir)
    with open(os.path.join(results_dir, _BENCHMARK_FILENAME), "w") as f:
        json.dump(benchmark, f, indent=2)

    return results_dir
