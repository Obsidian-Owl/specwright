"""CLI entry point for eval framework: python -m evals."""

import argparse
import json
import sys

import evals.framework.orchestrator as orchestrator


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
        default=300,
        metavar="SECONDS",
        help="Per-skill timeout in seconds (default: 300)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        default=False,
        help="Print cases without executing",
    )

    parsed = parser.parse_args(args)

    if parsed.view:
        from evals.framework import viewer
        viewer.serve(parsed.view, port=3117)
        return

    if not parsed.suite:
        parser.error("--suite is required")

    # Validate case filter before running
    if parsed.case:
        with open(parsed.suite) as f:
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
        parsed.suite,
        trials=parsed.trials,
        timeout=parsed.timeout,
        case_filter=parsed.case,
        dry_run=parsed.dry_run,
    )


if __name__ == "__main__":
    main()
