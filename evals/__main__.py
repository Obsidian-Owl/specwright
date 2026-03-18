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
    # Auto-detect plugin dir: evals/ -> repo root -> adapters/claude-code
    _default_plugin_dir = os.path.abspath(
        os.path.join(_EVALS_DIR, "..", "adapters", "claude-code")
    )
    parser.add_argument(
        "--plugin-dir",
        metavar="PATH",
        default=_default_plugin_dir if os.path.isdir(_default_plugin_dir) else None,
        help="Path to Specwright plugin directory (default: auto-detected from repo)",
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
    parser.add_argument(
        "--validate",
        action="store_true",
        default=False,
        help="Validate suite schema only; print OK or errors, exit 0/1",
    )

    parsed = parser.parse_args(args)

    if parsed.view:
        from evals.framework import viewer
        viewer.serve(parsed.view, port=3117)
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
        plugin_dir=parsed.plugin_dir,
        results_dir=parsed.results_dir,
    )


if __name__ == "__main__":
    main()
