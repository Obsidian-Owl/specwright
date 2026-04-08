"""Aggregator module — statistics, result aggregation, pass@k, and flaky detection."""

import glob
import json
import math
import os
import statistics
from datetime import datetime, timezone
from typing import Any


def calculate_stats(values: list[float]) -> dict[str, float]:
    """Return dict with mean, stddev (sample N-1), min, max for a list of numeric values."""
    if not values:
        raise ValueError("Cannot calculate stats on empty list")

    mean = statistics.mean(values)
    stddev = 0.0 if len(values) == 1 else statistics.stdev(values)

    return {
        "mean": mean,
        "stddev": stddev,
        "min": min(values),
        "max": max(values),
    }


def compute_pass_at_k(results: list[bool], k: int) -> float:
    """Probability that at least 1 of k random picks succeeds.

    Formula: 1 - comb(n-c, k) / comb(n, k)
    Returns 0.0 if c == 0, 1.0 if c >= k.
    Raises ValueError if k <= 0 or k > n.
    """
    n = len(results)
    if k <= 0:
        raise ValueError(f"k must be positive, got {k}")
    if k > n:
        raise ValueError(f"k ({k}) cannot exceed number of trials ({n})")

    c = sum(1 for r in results if r)

    if c == 0:
        return 0.0
    if c >= k:
        # comb(n-c, k) is 0 when n-c < k
        numerator = math.comb(n - c, k)
        if numerator == 0:
            return 1.0

    numerator = math.comb(n - c, k)
    denominator = math.comb(n, k)

    return float(1 - numerator / denominator)


def compute_pass_power_k(results: list[bool], k: int) -> float:
    """Probability that all k random picks succeed.

    Formula: comb(c, k) / comb(n, k)
    Returns 0.0 if c < k.
    Raises ValueError if k <= 0 or k > n.
    """
    n = len(results)
    if k <= 0:
        raise ValueError(f"k must be positive, got {k}")
    if k > n:
        raise ValueError(f"k ({k}) cannot exceed number of trials ({n})")

    c = sum(1 for r in results if r)

    if c < k:
        return 0.0

    numerator = math.comb(c, k)
    denominator = math.comb(n, k)

    return float(numerator / denominator)


def detect_flaky(
    expectations_across_trials: dict[str, list[bool]], threshold: float = 0.4
) -> list[str]:
    """Return descriptions of expectations whose pass-rate stddev exceeds threshold.

    Always-pass and always-fail expectations are never flagged.
    Single-trial expectations cannot show variance and are never flagged.
    """
    flaky = []

    for description, trial_results in expectations_across_trials.items():
        if len(trial_results) < 2:
            continue

        pass_rates = [1.0 if r else 0.0 for r in trial_results]
        all_pass = all(r for r in trial_results)
        all_fail = not any(r for r in trial_results)

        if all_pass or all_fail:
            continue

        stddev = statistics.pstdev(pass_rates)
        if stddev > threshold:
            flaky.append(description)

    return flaky


def aggregate_results(results_dir: str) -> dict[str, Any]:
    """Scan results_dir for grading.json files and produce aggregated report.

    Scans: {results_dir}/evals/{eval-id}/trial-{n}/grading.json
    Returns dict with metadata, runs (per-trial), and run_summary (per-eval stats).
    """
    pattern = os.path.join(results_dir, "evals", "*", "trial-*", "grading.json")
    grading_files = glob.glob(pattern)

    runs = []
    trials_per_eval: dict[str, int] = {}

    for grading_path in sorted(grading_files):
        with open(grading_path) as f:
            grading = json.load(f)

        eval_id = grading.get("eval_id", _extract_eval_id(grading_path))
        trial_num = grading.get("trial", _extract_trial_num(grading_path))
        pass_rate = grading.get("pass_rate", 0.0)
        duration_ms = grading.get("duration_ms", 0)
        # execution.tokens is written by run_single_eval; contains the raw
        # RunResult.tokens dict (input_tokens, output_tokens, cache_*).
        # May be missing on older grading files — default to empty dict.
        tokens = (grading.get("execution") or {}).get("tokens") or {}

        run_entry = {
            "eval_id": eval_id,
            "trial": trial_num,
            "pass_rate": pass_rate,
            "duration_ms": duration_ms,
            "tokens": tokens,
        }
        runs.append(run_entry)

        trials_per_eval[eval_id] = trials_per_eval.get(eval_id, 0) + 1

    run_summary = _compute_run_summary(runs)

    return {
        "metadata": {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "evals_run": len(trials_per_eval),
            "trials_per_eval": trials_per_eval,
        },
        "runs": runs,
        "run_summary": run_summary,
    }


def _extract_eval_id(grading_path: str) -> str:
    """Extract eval ID from path like .../evals/{eval-id}/trial-{n}/grading.json."""
    parts = grading_path.split(os.sep)
    evals_index = next(
        (i for i, p in enumerate(parts) if p == "evals"), None
    )
    if evals_index is not None and evals_index + 1 < len(parts):
        return parts[evals_index + 1]
    return "unknown"


def _extract_trial_num(grading_path: str) -> int:
    """Extract trial number from path like .../trial-{n}/grading.json."""
    parts = grading_path.split(os.sep)
    for part in parts:
        if part.startswith("trial-"):
            try:
                return int(part.split("-", 1)[1])
            except ValueError:
                pass
    return 0


def _aggregate_tokens(eval_runs: list[dict]) -> dict[str, float]:
    """Mean-aggregate the tokens dict across all runs of an eval.

    Each run_entry may have a `tokens` dict (the raw RunResult.tokens
    from runner.py — keys like input_tokens, output_tokens,
    cache_creation_input_tokens, cache_read_input_tokens). Some runs
    may have no tokens at all (older grading files, failures).

    For baseline comparison, we want ONE aggregate value per token key.
    Strategy: take the mean across runs where the key is present AND
    numeric. Keys present in some runs but not others still get a mean
    (of the runs where they are present). Non-numeric values are
    skipped. Returns empty dict if no tokens data found in any run.
    """
    key_values: dict[str, list[float]] = {}
    for run in eval_runs:
        tokens = run.get("tokens") or {}
        if not isinstance(tokens, dict):
            continue
        for key, val in tokens.items():
            # Exclude bool (which is an int subclass) and non-numeric types
            if isinstance(val, bool):
                continue
            if not isinstance(val, (int, float)):
                continue
            key_values.setdefault(key, []).append(float(val))

    return {
        key: sum(values) / len(values)
        for key, values in key_values.items()
        if values
    }


def _compute_run_summary(runs: list[dict]) -> dict[str, Any]:
    """Compute per-eval aggregated stats from all run entries."""
    by_eval: dict[str, list[dict]] = {}
    for run in runs:
        eval_id = run["eval_id"]
        by_eval.setdefault(eval_id, []).append(run)

    summary = {}
    for eval_id, eval_runs in by_eval.items():
        pass_rates = [r["pass_rate"] for r in eval_runs]
        durations = [r["duration_ms"] for r in eval_runs]

        pass_rate_stats = calculate_stats(pass_rates)
        duration_stats = calculate_stats(durations)
        tokens_aggregate = _aggregate_tokens(eval_runs)

        summary[eval_id] = {
            "pass_rate": pass_rate_stats,
            "duration_ms": duration_stats,
            "tokens": tokens_aggregate,
            "trial_count": len(eval_runs),
        }

    return summary
