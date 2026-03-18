"""Integration smoke tests — invoke real processes to prove the pipeline works.

These tests are SKIPPED by default. Run with:
    python -m pytest evals/tests/test_integration.py -m integration

They require:
    - Claude CLI installed and authenticated
    - Network access (for claude API)
    - ~30-120 seconds per test
"""

import json
import os
import shutil
import subprocess
import sys
import unittest

import pytest

# Base paths
_EVALS_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_PROJECT_ROOT = os.path.dirname(_EVALS_DIR)


@pytest.mark.integration
class TestRunnerInvokesClaude(unittest.TestCase):
    """AC-9: Real claude -p invocation returns valid results."""

    def test_claude_returns_exit_0_with_transcript(self):
        from evals.framework.runner import ClaudeCodeRunner

        runner = ClaudeCodeRunner()
        result = runner.run_skill(
            skill="test",
            prompt="Say hello in one word.",
            workdir=os.getcwd(),
            timeout=30,
        )
        self.assertEqual(result.exit_code, 0, f"stderr: {result.stderr}")
        self.assertTrue(len(result.stdout) > 0, "stdout should be non-empty")
        self.assertIsInstance(result.transcript, list)
        self.assertTrue(len(result.transcript) > 0, "transcript should have events")
        for event in result.transcript:
            self.assertIsInstance(event, dict)


@pytest.mark.integration
class TestDryRunPipeline(unittest.TestCase):
    """AC-10: Dry run completes and lists all eval case IDs."""

    def test_dry_run_exits_0_with_case_ids(self):
        result = subprocess.run(
            [sys.executable, "-m", "evals", "--suite", "skill", "--dry-run"],
            cwd=_PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=30,
        )
        self.assertEqual(result.returncode, 0, f"stderr: {result.stderr}")

        stderr = result.stderr
        self.assertIn("sw-build-simple-function", stderr)
        self.assertIn("sw-init-fresh-ts", stderr)
        self.assertIn("sw-design-vague-request", stderr)


@pytest.mark.integration
class TestFullSingleCaseRun(unittest.TestCase):
    """AC-11: Full eval run produces results directory with grading + benchmark."""

    def test_single_case_produces_results(self):
        # Use a temp results dir to avoid polluting the project
        import tempfile

        results_dir = tempfile.mkdtemp(prefix="eval-integration-test-")

        try:
            result = subprocess.run(
                [
                    sys.executable, "-m", "evals",
                    "--suite", "skill",
                    "--case", "sw-init-fresh-ts",
                    "--trials", "1",
                    "--results-dir", results_dir,
                    "--timeout", "120",
                ],
                cwd=_PROJECT_ROOT,
                capture_output=True,
                text=True,
                timeout=180,
            )
            self.assertEqual(result.returncode, 0, f"stderr: {result.stderr}")

            # Results directory should exist
            self.assertTrue(os.path.isdir(results_dir))

            # Find the grading.json
            grading_files = []
            for root, dirs, files in os.walk(results_dir):
                for f in files:
                    if f == "grading.json":
                        grading_files.append(os.path.join(root, f))

            self.assertTrue(
                len(grading_files) > 0,
                f"No grading.json found in {results_dir}. "
                f"Contents: {os.listdir(results_dir)}",
            )

            # Grading.json should be valid JSON with expected structure
            with open(grading_files[0]) as f:
                grading = json.load(f)
            self.assertIn("expectations", grading)
            self.assertIn("summary", grading)
            self.assertIn("eval_id", grading)

            # Benchmark.json should exist
            benchmark_path = os.path.join(results_dir, "benchmark.json")
            self.assertTrue(
                os.path.isfile(benchmark_path),
                f"benchmark.json not found in {results_dir}",
            )
        finally:
            shutil.rmtree(results_dir, ignore_errors=True)


@pytest.mark.integration
class TestValidateExistingSuites(unittest.TestCase):
    """AC-13/AC-14: Existing eval suites pass schema validation."""

    def test_skill_suite_validates(self):
        result = subprocess.run(
            [sys.executable, "-m", "evals", "--suite", "skill", "--validate"],
            cwd=_PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(
            result.returncode, 0,
            f"Skill suite validation failed:\n{result.stderr}",
        )

    def test_integration_suite_validates(self):
        result = subprocess.run(
            [sys.executable, "-m", "evals", "--suite", "integration", "--validate"],
            cwd=_PROJECT_ROOT,
            capture_output=True,
            text=True,
            timeout=10,
        )
        self.assertEqual(
            result.returncode, 0,
            f"Integration suite validation failed:\n{result.stderr}",
        )


if __name__ == "__main__":
    unittest.main()
