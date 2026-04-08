#!/usr/bin/env python3
"""Write eval baseline files from existing run-* result directories."""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
if REPO_ROOT not in sys.path:
    sys.path.insert(0, REPO_ROOT)

from evals.framework.aggregator import aggregate_results
from evals.framework.baseline import BaselineFile, write_baseline


def _latest_run_dirs_by_suite(results_dir: str) -> dict[str, str]:
    latest: dict[str, tuple[float, str]] = {}

    for entry in os.listdir(results_dir):
        if not entry.startswith("run-"):
            continue

        run_dir = os.path.join(results_dir, entry)
        if not os.path.isdir(run_dir):
            continue

        config_path = os.path.join(run_dir, "config.json")
        if not os.path.isfile(config_path):
            continue

        with open(config_path) as f:
            config = json.load(f)

        suite = config.get("suite")
        if not suite:
            continue

        mtime = os.path.getmtime(run_dir)
        previous = latest.get(suite)
        if previous is None or mtime > previous[0]:
            latest[suite] = (mtime, run_dir)

    return {suite: run_dir for suite, (_, run_dir) in latest.items()}


def _resolve_commit_sha() -> str:
    github_sha = os.environ.get("GITHUB_SHA", "").strip()
    if github_sha:
        return github_sha[:7]

    try:
        completed = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            check=True,
            capture_output=True,
            text=True,
        )
    except (FileNotFoundError, subprocess.CalledProcessError):
        return "unknown"

    commit_sha = completed.stdout.strip()
    return commit_sha[:7] if commit_sha else "unknown"


def _write_suite_baseline(suite: str, run_dir: str, baselines_dir: str, commit_sha: str) -> str:
    aggregate = aggregate_results(run_dir)
    evals_dict = {}

    for eval_id, summary in aggregate.get("run_summary", {}).items():
        evals_dict[eval_id] = {
            "pass_rate": summary.get("pass_rate", {}).get("mean", 0.0),
            "duration_ms": int(summary.get("duration_ms", {}).get("mean", 0)),
            "tokens": summary.get("tokens", {}),
            "runs": summary.get("trial_count", 1),
        }

    baseline = BaselineFile(
        suite=suite,
        generated_at=datetime.now(timezone.utc).isoformat(),
        generated_from_commit=commit_sha,
        tolerances={
            "pass_rate_delta": 0.0,
            "duration_multiplier": 1.25,
            "tokens_multiplier": 1.20,
        },
        evals=evals_dict,
    )

    output_path = os.path.join(baselines_dir, f"{suite}.json")
    write_baseline(baseline, output_path)
    return output_path


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Write baseline files from downloaded eval run artifacts."
    )
    parser.add_argument(
        "--results-dir",
        default="evals/results",
        help="Directory containing run-* result folders with config.json.",
    )
    parser.add_argument(
        "--baselines-dir",
        default="evals/baselines",
        help="Directory to write baseline JSON files into.",
    )
    args = parser.parse_args()

    latest_runs = _latest_run_dirs_by_suite(args.results_dir)
    if not latest_runs:
        print(
            f"No suite run directories found under {args.results_dir}",
            file=sys.stderr,
        )
        return 1

    commit_sha = _resolve_commit_sha()

    for suite, run_dir in sorted(latest_runs.items()):
        output_path = _write_suite_baseline(
            suite=suite,
            run_dir=run_dir,
            baselines_dir=args.baselines_dir,
            commit_sha=commit_sha,
        )
        print(f"Wrote {output_path} from {run_dir}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
