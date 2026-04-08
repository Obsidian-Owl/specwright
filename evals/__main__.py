"""CLI entry point for eval framework: python -m evals."""

import argparse
import json
import os
import sys

import evals.framework.orchestrator as orchestrator

# Base directory for resolving suite paths
_EVALS_DIR = os.path.dirname(os.path.abspath(__file__))


def _resolve_suite_path(suite_arg: str) -> str:
    """Resolve suite name or path to the evals.json file path.

    Accepts either:
    - A suite name like "skill" → resolves to evals/suites/skill/evals.json
    - A direct path to an evals.json file
    """
    # If it's already a file path, use it
    if os.path.isfile(suite_arg):
        return suite_arg

    # Try resolving as suite name
    resolved = os.path.join(_EVALS_DIR, "suites", suite_arg, "evals.json")
    if os.path.isfile(resolved):
        return resolved

    # Not found — return the resolved path (will fail with clear error)
    return resolved


def main(args=None):
    """Parse args and run eval suite."""
    parser = argparse.ArgumentParser(
        prog="evals",
        description="Run Specwright eval suites",
    )
    parser.add_argument(
        "--suite",
        metavar="PATH",
        help="Path to evals.json file",
    )
    parser.add_argument(
        "--case",
        metavar="ID",
        help="Filter to a single eval case by ID",
    )
    parser.add_argument(
        "--trials",
        type=int,
        default=1,
        metavar="N",
        help="Number of trials per eval case (default: 1)",
    )
    parser.add_argument(
        "--results-dir",
        metavar="PATH",
        help="Override output results directory",
    )
    parser.add_argument(
        "--view",
        metavar="PATH",
        help="Serve a results directory in the browser",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=600,
        metavar="SECONDS",
        help="Per-skill timeout in seconds (default: 600)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Print cases without executing",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        default=False,
        help="Validate suite schema only; print OK or errors, exit 0/1",
    )
    parser.add_argument(
        "--grade-workdir",
        metavar="PATH",
        help="Grade a workdir against an eval case and write grading.json",
    )
    parser.add_argument(
        "--eval-id",
        metavar="ID",
        help="Eval case ID to grade against (used with --grade-workdir)",
    )
    parser.add_argument(
        "--output",
        metavar="PATH",
        help="Output path for grading.json (used with --grade-workdir)",
    )
    parser.add_argument(
        "--aggregate",
        metavar="PATH",
        help="Aggregate results directory into benchmark.json",
    )
    parser.add_argument(
        "--smoke-only",
        action="store_true",
        default=False,
        help="Run only eval cases tagged with `smoke: true` (Unit 02b-1)",
    )
    parser.add_argument(
        "--compare-to-baseline",
        action="store_true",
        default=False,
        help="After running, compare results against evals/baselines/{suite}.json",
    )
    parser.add_argument(
        "--update-baseline",
        action="store_true",
        default=False,
        help="Run the suite and write a fresh baseline file. Refuses on dirty git tree.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        default=False,
        help="With --update-baseline, bypass dirty-tree check (tooling development only)",
    )
    parser.add_argument(
        "--validate-baselines",
        action="store_true",
        default=False,
        help="Validate every *.json file in evals/baselines/ against the schema",
    )
    parser.add_argument(
        "--baselines-dir",
        metavar="PATH",
        default=None,
        help="Override baselines directory (default: evals/baselines)",
    )

    parsed = parser.parse_args(args)

    if parsed.view:
        from evals.framework import viewer
        viewer.serve(parsed.view, port=3117)
        return

    # ----- Unit 02b-1: --validate-baselines -----
    if parsed.validate_baselines:
        from evals.framework.baseline import validate_baselines_dir
        baselines_dir = parsed.baselines_dir or os.path.join(_EVALS_DIR, "baselines")
        if not os.path.isdir(baselines_dir):
            print(f"no baseline files found at {baselines_dir}", file=sys.stderr)
            sys.exit(0)
        findings = validate_baselines_dir(baselines_dir)
        if not findings:
            print(f"no baseline files found at {baselines_dir}", file=sys.stderr)
            sys.exit(0)
        any_invalid = False
        for filename, errors in findings.items():
            if errors:
                any_invalid = True
                for err in errors:
                    print(f"[{filename}] {err}", file=sys.stderr)
            else:
                print(f"[{filename}] OK")
        sys.exit(1 if any_invalid else 0)

    if parsed.aggregate:
        if not os.path.isdir(parsed.aggregate):
            print(f"Error: results directory not found: {parsed.aggregate}", file=sys.stderr)
            sys.exit(1)
        from evals.framework.aggregator import aggregate_results
        benchmark = aggregate_results(parsed.aggregate)
        benchmark_path = os.path.join(parsed.aggregate, "benchmark.json")
        with open(benchmark_path, "w") as f:
            json.dump(benchmark, f, indent=2)
        print(f"Benchmark written to {benchmark_path}")
        return

    if parsed.grade_workdir:
        if not parsed.eval_id or not parsed.suite or not parsed.output:
            parser.error("--grade-workdir requires --eval-id, --suite, and --output")

        suite_path = _resolve_suite_path(parsed.suite)
        if not os.path.isfile(suite_path):
            print(f"Error: suite not found at {suite_path}", file=sys.stderr)
            sys.exit(1)

        with open(suite_path) as f:
            suite_data = json.load(f)
        eval_case = next(
            (c for c in suite_data.get("evals", []) if c["id"] == parsed.eval_id),
            None,
        )
        if eval_case is None:
            print(f"Error: eval case '{parsed.eval_id}' not found", file=sys.stderr)
            sys.exit(1)

        from evals.framework.grader import grade_eval
        grade_result = grade_eval(eval_case, parsed.grade_workdir)
        grade_result["eval_id"] = parsed.eval_id
        grade_result["pass_rate"] = grade_result.get("summary", {}).get("pass_rate", 0.0)
        grade_result["duration_ms"] = grade_result.get("timing", {}).get("duration_ms", 0)

        output_dir = os.path.dirname(parsed.output)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        with open(parsed.output, "w") as f:
            json.dump(grade_result, f, indent=2)
        print(f"pass_rate: {grade_result['pass_rate']}")
        return

    if not parsed.suite:
        parser.error("--suite is required")

    suite_path = _resolve_suite_path(parsed.suite)

    if not os.path.isfile(suite_path):
        print(f"Error: suite not found at {suite_path}", file=sys.stderr)
        sys.exit(1)

    if parsed.validate:
        errors = orchestrator.validate_suite(suite_path)
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            sys.exit(1)
        else:
            print("OK")
            sys.exit(0)

    # Validate case filter before running
    if parsed.case:
        with open(suite_path) as f:
            suite_data = json.load(f)
        all_ids = [c["id"] for c in suite_data.get("evals", [])]
        if parsed.case not in all_ids:
            print(
                f"Error: case ID '{parsed.case}' not found in suite. "
                f"Available: {all_ids}",
                file=sys.stderr,
            )
            sys.exit(1)

    suite_name = os.path.basename(os.path.dirname(suite_path))
    baselines_dir = parsed.baselines_dir or os.path.join(_EVALS_DIR, "baselines")

    # ----- Unit 02b-1: --update-baseline (refuses on dirty tree) -----
    if parsed.update_baseline:
        import subprocess
        if not parsed.force:
            git_status = subprocess.run(
                ["git", "status", "--porcelain"],
                capture_output=True, text=True,
            )
            if git_status.stdout.strip():
                print(
                    "Refusing to update baseline with a dirty working tree. "
                    "Commit or stash first, then retry. Use --force to bypass "
                    "(tooling development only).",
                    file=sys.stderr,
                )
                sys.exit(1)
        results_dir = orchestrator.run_eval_suite(
            suite_path,
            trials=parsed.trials,
            timeout=parsed.timeout,
            case_filter=parsed.case,
            dry_run=parsed.dry_run,
            results_dir=parsed.results_dir,
            smoke_only=parsed.smoke_only,
        )
        if not results_dir:
            sys.exit(1)
        from evals.framework.baseline import BaselineFile, write_baseline
        from evals.framework.aggregator import aggregate_results
        agg = aggregate_results(results_dir)
        # Build baseline.evals from the run_summary
        evals_dict = {}
        for eval_id, summary in agg.get("run_summary", {}).items():
            evals_dict[eval_id] = {
                "pass_rate": summary.get("pass_rate_mean", 0.0),
                "duration_ms": int(summary.get("duration_ms_mean", 0)),
                "tokens": summary.get("tokens", {}),
                "runs": summary.get("trials", parsed.trials),
            }
        commit_sha = "unknown"
        try:
            commit_sha = subprocess.run(
                ["git", "rev-parse", "HEAD"], capture_output=True, text=True
            ).stdout.strip()[:7]
        except (FileNotFoundError, subprocess.SubprocessError):
            pass
        from datetime import datetime, timezone
        baseline = BaselineFile(
            suite=suite_name,
            generated_at=datetime.now(timezone.utc).isoformat(),
            generated_from_commit=commit_sha,
            tolerances={
                "pass_rate_delta": 0.0,
                "duration_multiplier": 1.25,
                "tokens_multiplier": 1.20,
            },
            evals=evals_dict,
        )
        os.makedirs(baselines_dir, exist_ok=True)
        baseline_path = os.path.join(baselines_dir, f"{suite_name}.json")
        write_baseline(baseline, baseline_path)
        print(f"Baseline written to {baseline_path}")
        print()
        print("Preview commit message:")
        print(f"chore(evals): refresh {suite_name} baseline ({len(evals_dict)} evals, "
              f"generated from {commit_sha})")
        return

    # ----- Unit 02b-1: --compare-to-baseline -----
    if parsed.compare_to_baseline:
        from evals.framework.baseline import (
            load_baseline, BaselineFileError, compare_run_to_baseline
        )
        baseline_path = os.path.join(baselines_dir, f"{suite_name}.json")
        if not os.path.isfile(baseline_path):
            print(
                f"No baseline file at `{baseline_path}`. Run `--update-baseline` "
                f"to create one.",
                file=sys.stderr,
            )
            sys.exit(1)
        try:
            baseline = load_baseline(suite_name, baselines_dir=baselines_dir)
        except BaselineFileError as exc:
            print(f"Failed to load baseline: {exc}", file=sys.stderr)
            sys.exit(1)
        results_dir = orchestrator.run_eval_suite(
            suite_path,
            trials=parsed.trials,
            timeout=parsed.timeout,
            case_filter=parsed.case,
            dry_run=parsed.dry_run,
            results_dir=parsed.results_dir,
            smoke_only=parsed.smoke_only,
        )
        if not results_dir:
            sys.exit(1)
        from evals.framework.aggregator import aggregate_results
        agg = aggregate_results(results_dir)
        run_results = {}
        for eval_id, summary in agg.get("run_summary", {}).items():
            run_results[eval_id] = {
                "pass_rate": summary.get("pass_rate_mean", 0.0),
                "duration_ms": summary.get("duration_ms_mean", 0),
                "tokens": summary.get("tokens", {}),
            }
        comparison = compare_run_to_baseline(run_results, baseline)
        print(comparison.table_markdown)
        # Write comparison.json at the TOP LEVEL of the run dir (proven
        # non-collidant by tests/test_aggregator.py::TestAggregatorNonCollision)
        comparison_path = os.path.join(results_dir, "comparison.json")
        with open(comparison_path, "w") as f:
            json.dump({
                "regressions": [r.__dict__ for r in comparison.regressions],
                "improvements": [i.__dict__ for i in comparison.improvements],
                "missing_from_baseline": comparison.missing_from_baseline,
                "missing_from_run": comparison.missing_from_run,
                "exit_code": comparison.exit_code,
                "table_markdown": comparison.table_markdown,
            }, f, indent=2)
        sys.exit(comparison.exit_code)

    orchestrator.run_eval_suite(
        suite_path,
        trials=parsed.trials,
        timeout=parsed.timeout,
        case_filter=parsed.case,
        dry_run=parsed.dry_run,
        results_dir=parsed.results_dir,
        smoke_only=parsed.smoke_only,
    )


if __name__ == "__main__":
    main()
