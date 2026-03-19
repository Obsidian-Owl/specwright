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

    parsed = parser.parse_args(args)

    if parsed.view:
        from evals.framework import viewer
        viewer.serve(parsed.view, port=3117)
        return

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

    orchestrator.run_eval_suite(
        suite_path,
        trials=parsed.trials,
        timeout=parsed.timeout,
        case_filter=parsed.case,
        dry_run=parsed.dry_run,
        results_dir=parsed.results_dir,
    )


if __name__ == "__main__":
    main()
