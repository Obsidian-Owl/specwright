"""Deterministic proof for Unit 07's provider-matched sw-build comparison."""

import json
from pathlib import Path
import unittest

from evals.framework.baseline import BaselineFile, compare_run_to_baseline


_ROOT = Path(__file__).resolve().parents[2]
_REFERENCES = _ROOT / "evals" / "baselines" / "references"
_BASELINE = _REFERENCES / "sw-build-simple-function.codex.v0.27.1.json"
_CURRENT = _REFERENCES / "sw-build-simple-function.codex.current.json"


class TestRecoveryCloseoutBaselineReference(unittest.TestCase):
    def test_baseline_reference_is_anchored_to_v0271_commit(self):
        data = json.loads(_BASELINE.read_text(encoding="utf-8"))
        self.assertEqual(data["provider"], "codex")
        self.assertEqual(
            data["generated_from_commit"],
            "0f914027f36667f0793ef21e287b814dc5bb847a",
        )
        self.assertIn("sw-build-simple-function", data["evals"])

    def test_current_closeout_metrics_match_or_improve_against_baseline(self):
        baseline_data = json.loads(_BASELINE.read_text(encoding="utf-8"))
        current_data = json.loads(_CURRENT.read_text(encoding="utf-8"))
        baseline = BaselineFile(
            suite=baseline_data["suite"],
            provider=baseline_data["provider"],
            generated_at=baseline_data["generated_at"],
            generated_from_commit=baseline_data["generated_from_commit"],
            tolerances=baseline_data["tolerances"],
            evals=baseline_data["evals"],
        )

        result = compare_run_to_baseline(current_data["run_results"], baseline)

        self.assertEqual(result.exit_code, 0, result.table_markdown)
        self.assertEqual(result.regressions, [])
        improved_metrics = {(item.eval_id, item.metric) for item in result.improvements}
        self.assertIn(("sw-build-simple-function", "pass_rate"), improved_metrics)
        self.assertIn(("sw-build-simple-function", "duration_ms"), improved_metrics)

    def test_current_closeout_artifact_preserves_order_of_operations(self):
        current_data = json.loads(_CURRENT.read_text(encoding="utf-8"))
        self.assertEqual(current_data["provider"], "codex")
        self.assertEqual(
            current_data["source_benchmark"],
            "evals/results/run-20260409T023110/benchmark.json",
        )
        self.assertEqual(
            current_data["source_grading"],
            "evals/results/run-20260409T023110/evals/sw-build-simple-function/trial-1/grading.json",
        )
        self.assertEqual(
            current_data["order_expectations"],
            {
                "branch_exists": True,
                "commit_count": True,
                "no_uncommitted_changes": True,
                "stage_report_written": True,
                "three_line_handoff": True,
            },
        )


if __name__ == "__main__":
    unittest.main()
