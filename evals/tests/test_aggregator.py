"""Tests for evals.framework.aggregator — statistics, aggregation, pass@k, flaky detection.

RED phase: all tests must fail because the implementation is stubbed.

Acceptance criteria covered:
  AC-1: calculate_stats(values) — mean, stddev (sample N-1), min, max; empty raises ValueError
  AC-2: aggregate_results(results_dir) — scans grading.json files, returns structured report
  AC-3: compute_pass_at_k(results, k) — 1 - comb(n-c,k)/comb(n,k); edge cases
  AC-4: compute_pass_power_k(results, k) — comb(c,k)/comb(n,k); edge cases
  AC-5: detect_flaky(expectations_across_trials, threshold) — stddev-based detection
"""

import json
import math
import os
import tempfile
import unittest

from evals.framework.aggregator import (
    calculate_stats,
    aggregate_results,
    compute_pass_at_k,
    compute_pass_power_k,
    detect_flaky,
)


# ---------------------------------------------------------------------------
# AC-1: calculate_stats
# ---------------------------------------------------------------------------

class TestCalculateStatsHappyPath(unittest.TestCase):
    """AC-1: calculate_stats returns correct mean, stddev, min, max."""

    def test_five_integers(self):
        result = calculate_stats([1, 2, 3, 4, 5])
        self.assertAlmostEqual(result["mean"], 3.0)
        # sample stddev (N-1): sqrt(10/4) = sqrt(2.5) ~ 1.5811
        self.assertAlmostEqual(result["stddev"], math.sqrt(2.5), places=6)
        self.assertEqual(result["min"], 1)
        self.assertEqual(result["max"], 5)

    def test_floats_with_known_values(self):
        vals = [2.5, 3.5, 4.5]
        result = calculate_stats(vals)
        self.assertAlmostEqual(result["mean"], 3.5, places=6)
        # sample stddev: sqrt(((−1)^2+0+1^2)/2) = sqrt(1) = 1.0
        self.assertAlmostEqual(result["stddev"], 1.0, places=6)
        self.assertAlmostEqual(result["min"], 2.5)
        self.assertAlmostEqual(result["max"], 4.5)

    def test_returns_exactly_four_keys(self):
        result = calculate_stats([10, 20])
        self.assertEqual(set(result.keys()), {"mean", "stddev", "min", "max"})

    def test_negative_values(self):
        result = calculate_stats([-5, -3, -1])
        self.assertAlmostEqual(result["mean"], -3.0)
        self.assertEqual(result["min"], -5)
        self.assertEqual(result["max"], -1)

    def test_large_list_consistency(self):
        """Verify against a large dataset to prevent hardcoded shortcuts."""
        vals = list(range(1, 101))  # 1..100
        result = calculate_stats(vals)
        self.assertAlmostEqual(result["mean"], 50.5)
        self.assertEqual(result["min"], 1)
        self.assertEqual(result["max"], 100)
        # sample stddev of 1..100 is sqrt(100*101/12) ~ 29.0115
        expected_stddev = math.sqrt(sum((x - 50.5) ** 2 for x in vals) / 99)
        self.assertAlmostEqual(result["stddev"], expected_stddev, places=4)


class TestCalculateStatsSingleValue(unittest.TestCase):
    """AC-1: single value list has stddev=0.0."""

    def test_single_value_stddev_zero(self):
        result = calculate_stats([7.0])
        self.assertAlmostEqual(result["mean"], 7.0)
        self.assertEqual(result["stddev"], 0.0)
        self.assertAlmostEqual(result["min"], 7.0)
        self.assertAlmostEqual(result["max"], 7.0)

    def test_single_negative_value(self):
        result = calculate_stats([-42.0])
        self.assertEqual(result["stddev"], 0.0)
        self.assertAlmostEqual(result["mean"], -42.0)


class TestCalculateStatsTwoValues(unittest.TestCase):
    """AC-1: two values edge — stddev uses N-1 denominator."""

    def test_two_values_stddev_is_sample(self):
        # [0, 10]: mean=5, sample stddev = sqrt((25+25)/1) = sqrt(50)
        result = calculate_stats([0, 10])
        self.assertAlmostEqual(result["stddev"], math.sqrt(50.0), places=6)

    def test_two_identical_values(self):
        result = calculate_stats([3.0, 3.0])
        self.assertEqual(result["stddev"], 0.0)


class TestCalculateStatsEmpty(unittest.TestCase):
    """AC-1: empty list raises ValueError with specific message."""

    def test_empty_list_raises_value_error(self):
        with self.assertRaises(ValueError) as ctx:
            calculate_stats([])
        self.assertIn("empty", str(ctx.exception).lower())

    def test_empty_list_error_message_exact(self):
        with self.assertRaises(ValueError) as ctx:
            calculate_stats([])
        self.assertEqual(str(ctx.exception), "Cannot calculate stats on empty list")


class TestCalculateStatsReturnTypes(unittest.TestCase):
    """AC-1: return values are correct types."""

    def test_all_values_are_numeric(self):
        result = calculate_stats([1, 2, 3])
        for key in ("mean", "stddev", "min", "max"):
            self.assertIsInstance(result[key], (int, float),
                                  f"{key} should be numeric, got {type(result[key])}")


# ---------------------------------------------------------------------------
# AC-3: compute_pass_at_k
# ---------------------------------------------------------------------------

class TestPassAtKKnownValues(unittest.TestCase):
    """AC-3: verify pass@k against hand-calculated combinatorial results."""

    def test_all_pass_k1(self):
        # n=5, c=5, k=1: 1 - comb(0,1)/comb(5,1) = 1 - 0/5 = 1.0
        result = compute_pass_at_k([True] * 5, 1)
        self.assertEqual(result, 1.0)

    def test_all_fail_k1(self):
        # n=5, c=0: spec says return 0.0 if c=0
        result = compute_pass_at_k([False] * 5, 1)
        self.assertEqual(result, 0.0)

    def test_one_of_five_pass_k1(self):
        # n=5, c=1, k=1: 1 - comb(4,1)/comb(5,1) = 1 - 4/5 = 0.2
        result = compute_pass_at_k([True, False, False, False, False], 1)
        self.assertAlmostEqual(result, 0.2, places=6)

    def test_three_of_five_pass_k2(self):
        # n=5, c=3, k=2: 1 - comb(2,2)/comb(5,2) = 1 - 1/10 = 0.9
        result = compute_pass_at_k([True, True, True, False, False], 2)
        self.assertAlmostEqual(result, 0.9, places=6)

    def test_two_of_four_pass_k3(self):
        # n=4, c=2, k=3: 1 - comb(2,3)/comb(4,3) = 1 - 0/4 = 1.0
        # comb(2,3)=0 because 3>2
        result = compute_pass_at_k([True, True, False, False], 3)
        self.assertAlmostEqual(result, 1.0, places=6)

    def test_c_equals_k_returns_one(self):
        # n=3, c=2, k=2: 1 - comb(1,2)/comb(3,2) = 1 - 0/3 = 1.0
        result = compute_pass_at_k([True, True, False], 2)
        self.assertAlmostEqual(result, 1.0, places=6)

    def test_k_equals_n_all_pass(self):
        # n=3, c=3, k=3: 1 - comb(0,3)/comb(3,3) = 1 - 1/1... wait:
        # comb(0,3)=0, comb(3,3)=1 => 1 - 0 = 1.0
        result = compute_pass_at_k([True, True, True], 3)
        self.assertAlmostEqual(result, 1.0, places=6)

    def test_k_equals_n_some_fail(self):
        # n=3, c=2, k=3: 1 - comb(1,3)/comb(3,3) = 1 - 0/1 = 1.0
        result = compute_pass_at_k([True, True, False], 3)
        self.assertAlmostEqual(result, 1.0, places=6)

    def test_one_of_ten_pass_k5(self):
        # n=10, c=1, k=5: 1 - comb(9,5)/comb(10,5) = 1 - 126/252 = 0.5
        results = [True] + [False] * 9
        val = compute_pass_at_k(results, 5)
        self.assertAlmostEqual(val, 0.5, places=6)

    def test_return_type_is_float(self):
        result = compute_pass_at_k([True, False], 1)
        self.assertIsInstance(result, float)


class TestPassAtKEdgeCases(unittest.TestCase):
    """AC-3: error handling for invalid k."""

    def test_k_zero_raises(self):
        with self.assertRaises(ValueError):
            compute_pass_at_k([True, False], 0)

    def test_k_negative_raises(self):
        with self.assertRaises(ValueError):
            compute_pass_at_k([True, False], -1)

    def test_k_greater_than_n_raises(self):
        with self.assertRaises(ValueError):
            compute_pass_at_k([True, False], 3)

    def test_single_trial_pass(self):
        # n=1, c=1, k=1: should be 1.0
        self.assertAlmostEqual(compute_pass_at_k([True], 1), 1.0)

    def test_single_trial_fail(self):
        # n=1, c=0, k=1: should be 0.0
        self.assertAlmostEqual(compute_pass_at_k([False], 1), 0.0)


# ---------------------------------------------------------------------------
# AC-4: compute_pass_power_k
# ---------------------------------------------------------------------------

class TestPassPowerKKnownValues(unittest.TestCase):
    """AC-4: verify pass^k against hand-calculated combinatorial results."""

    def test_all_pass_k1(self):
        # n=5, c=5, k=1: comb(5,1)/comb(5,1) = 1.0
        result = compute_pass_power_k([True] * 5, 1)
        self.assertAlmostEqual(result, 1.0, places=6)

    def test_all_fail_returns_zero(self):
        # n=5, c=0, k=1: comb(0,1)/comb(5,1) = 0/5 = 0.0
        result = compute_pass_power_k([False] * 5, 1)
        self.assertEqual(result, 0.0)

    def test_three_of_five_k2(self):
        # n=5, c=3, k=2: comb(3,2)/comb(5,2) = 3/10 = 0.3
        result = compute_pass_power_k([True, True, True, False, False], 2)
        self.assertAlmostEqual(result, 0.3, places=6)

    def test_all_pass_k_equals_n(self):
        # n=3, c=3, k=3: comb(3,3)/comb(3,3) = 1/1 = 1.0
        result = compute_pass_power_k([True, True, True], 3)
        self.assertAlmostEqual(result, 1.0, places=6)

    def test_c_less_than_k_returns_zero(self):
        # n=5, c=2, k=3: comb(2,3)/comb(5,3) = 0/10 = 0.0
        result = compute_pass_power_k([True, True, False, False, False], 3)
        self.assertEqual(result, 0.0)

    def test_four_of_six_k3(self):
        # n=6, c=4, k=3: comb(4,3)/comb(6,3) = 4/20 = 0.2
        results = [True] * 4 + [False] * 2
        val = compute_pass_power_k(results, 3)
        self.assertAlmostEqual(val, 0.2, places=6)

    def test_return_type_is_float(self):
        result = compute_pass_power_k([True, True, False], 1)
        self.assertIsInstance(result, float)


class TestPassPowerKEdgeCases(unittest.TestCase):
    """AC-4: error handling for invalid k."""

    def test_k_zero_raises(self):
        with self.assertRaises(ValueError):
            compute_pass_power_k([True, False], 0)

    def test_k_negative_raises(self):
        with self.assertRaises(ValueError):
            compute_pass_power_k([True, False], -1)

    def test_k_greater_than_n_raises(self):
        with self.assertRaises(ValueError):
            compute_pass_power_k([True, False], 3)

    def test_single_trial_pass(self):
        self.assertAlmostEqual(compute_pass_power_k([True], 1), 1.0)

    def test_single_trial_fail(self):
        self.assertEqual(compute_pass_power_k([False], 1), 0.0)


class TestPassAtKAndPowerKRelationship(unittest.TestCase):
    """Cross-check: pass@k >= pass^k always, and they agree at extremes."""

    def test_pass_at_k_gte_pass_power_k(self):
        """For any valid input, P(at least 1) >= P(all)."""
        results = [True, True, False, False, False]
        for k in range(1, 6):
            at_k = compute_pass_at_k(results, k)
            power_k = compute_pass_power_k(results, k)
            self.assertGreaterEqual(at_k, power_k,
                                     f"pass@{k} should be >= pass^{k}")

    def test_all_pass_both_equal_one(self):
        results = [True] * 4
        for k in range(1, 5):
            self.assertAlmostEqual(compute_pass_at_k(results, k), 1.0)
            self.assertAlmostEqual(compute_pass_power_k(results, k), 1.0)

    def test_all_fail_both_equal_zero(self):
        results = [False] * 4
        for k in range(1, 5):
            self.assertEqual(compute_pass_at_k(results, k), 0.0)
            self.assertEqual(compute_pass_power_k(results, k), 0.0)


# ---------------------------------------------------------------------------
# AC-5: detect_flaky
# ---------------------------------------------------------------------------

class TestDetectFlakyBasic(unittest.TestCase):
    """AC-5: flaky detection based on pass-rate stddev."""

    def test_always_pass_not_flagged(self):
        expectations = {"exp-a": [True, True, True, True, True]}
        result = detect_flaky(expectations)
        self.assertEqual(result, [])

    def test_always_fail_not_flagged(self):
        expectations = {"exp-a": [False, False, False, False]}
        result = detect_flaky(expectations)
        self.assertEqual(result, [])

    def test_fifty_fifty_flagged(self):
        # 50/50 pass rate: [T, F, T, F, T, F] stddev of [1,0,1,0,1,0] = 0.5477
        expectations = {"flaky-one": [True, False, True, False, True, False]}
        result = detect_flaky(expectations)
        self.assertIn("flaky-one", result)

    def test_mostly_pass_not_flagged(self):
        # 9/10 pass: stddev of [1,1,1,1,1,1,1,1,1,0] ~ 0.316 < 0.4
        expectations = {"stable": [True] * 9 + [False]}
        result = detect_flaky(expectations)
        self.assertNotIn("stable", result)


class TestDetectFlakyMultiple(unittest.TestCase):
    """AC-5: multiple expectations in one call."""

    def test_mixed_bag_returns_only_flaky(self):
        expectations = {
            "always-pass": [True, True, True, True],
            "always-fail": [False, False, False, False],
            "very-flaky": [True, False, True, False],
            "barely-stable": [True] * 8 + [False, False],  # stddev ~ 0.316
        }
        result = detect_flaky(expectations)
        self.assertIn("very-flaky", result)
        self.assertNotIn("always-pass", result)
        self.assertNotIn("always-fail", result)
        self.assertNotIn("barely-stable", result)

    def test_returns_list_type(self):
        result = detect_flaky({"a": [True, True]})
        self.assertIsInstance(result, list)


class TestDetectFlakyCustomThreshold(unittest.TestCase):
    """AC-5: threshold parameter changes sensitivity."""

    def test_low_threshold_catches_more(self):
        expectations = {
            "slight-variance": [True] * 8 + [False, False],  # stddev ~ 0.316
        }
        # Default threshold 0.4 would NOT catch this
        result_default = detect_flaky(expectations)
        self.assertNotIn("slight-variance", result_default)
        # Threshold 0.2 SHOULD catch this
        result_sensitive = detect_flaky(expectations, threshold=0.2)
        self.assertIn("slight-variance", result_sensitive)

    def test_high_threshold_catches_fewer(self):
        expectations = {"flaky": [True, False, True, False]}  # stddev ~ 0.5477
        result = detect_flaky(expectations, threshold=0.6)
        self.assertNotIn("flaky", result)


class TestDetectFlakyEdgeCases(unittest.TestCase):
    """AC-5: edge cases for flaky detection."""

    def test_empty_expectations_returns_empty(self):
        result = detect_flaky({})
        self.assertEqual(result, [])

    def test_single_trial_not_flagged(self):
        """Single trial can't show variance."""
        expectations = {"one-shot": [True]}
        result = detect_flaky(expectations)
        self.assertEqual(result, [])

    def test_two_trials_opposite_flagged(self):
        """[True, False] stddev = 0.707 > 0.4, should be flagged."""
        expectations = {"flip-flop": [True, False]}
        result = detect_flaky(expectations)
        self.assertIn("flip-flop", result)


# ---------------------------------------------------------------------------
# AC-2: aggregate_results
# ---------------------------------------------------------------------------

def _make_grading_json(passed_expectations, failed_expectations,
                       duration_ms=1000, eval_id="eval-01", trial_num=1):
    """Build a grading.json structure matching the expected schema."""
    expectations = []
    for desc in passed_expectations:
        expectations.append({
            "description": desc,
            "type": "file_exists",
            "passed": True,
            "evidence": "Found",
        })
    for desc in failed_expectations:
        expectations.append({
            "description": desc,
            "type": "file_exists",
            "passed": False,
            "evidence": "Not found",
        })
    return {
        "eval_id": eval_id,
        "trial": trial_num,
        "expectations": expectations,
        "duration_ms": duration_ms,
        "passed_count": len(passed_expectations),
        "failed_count": len(failed_expectations),
        "total_count": len(passed_expectations) + len(failed_expectations),
        "pass_rate": (len(passed_expectations) /
                      max(1, len(passed_expectations) + len(failed_expectations))),
    }


def _write_grading(base_dir, eval_id, trial_num, grading_dict):
    """Write a grading.json file in the expected directory layout."""
    trial_dir = os.path.join(base_dir, "evals", eval_id, f"trial-{trial_num}")
    os.makedirs(trial_dir, exist_ok=True)
    path = os.path.join(trial_dir, "grading.json")
    with open(path, "w") as f:
        json.dump(grading_dict, f)
    return path


class TestAggregateResultsStructure(unittest.TestCase):
    """AC-2: aggregate_results returns well-structured dict."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_returns_metadata_key(self):
        grading = _make_grading_json(["a passes"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        result = aggregate_results(self.tmpdir)
        self.assertIn("metadata", result)

    def test_metadata_has_required_fields(self):
        grading = _make_grading_json(["a passes"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        result = aggregate_results(self.tmpdir)
        meta = result["metadata"]
        self.assertIn("timestamp", meta)
        self.assertIn("evals_run", meta)
        self.assertIn("trials_per_eval", meta)

    def test_returns_runs_key(self):
        grading = _make_grading_json(["a"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        result = aggregate_results(self.tmpdir)
        self.assertIn("runs", result)

    def test_returns_run_summary_key(self):
        grading = _make_grading_json(["a"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        result = aggregate_results(self.tmpdir)
        self.assertIn("run_summary", result)


class TestAggregateResultsContent(unittest.TestCase):
    """AC-2: aggregate_results correctly computes per-eval and per-trial data."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_single_eval_single_trial(self):
        grading = _make_grading_json(["exp-a"], ["exp-b"],
                                     eval_id="eval-01", trial_num=1, duration_ms=500)
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        result = aggregate_results(self.tmpdir)
        self.assertEqual(result["metadata"]["evals_run"], 1)
        # runs should contain the trial data
        self.assertEqual(len(result["runs"]), 1)

    def test_multiple_trials_same_eval(self):
        for trial in range(1, 4):
            grading = _make_grading_json(
                ["exp-a"], ["exp-b"] if trial % 2 == 0 else [],
                eval_id="eval-01", trial_num=trial, duration_ms=100 * trial,
            )
            _write_grading(self.tmpdir, "eval-01", trial, grading)
        result = aggregate_results(self.tmpdir)
        self.assertEqual(result["metadata"]["evals_run"], 1)
        self.assertEqual(len(result["runs"]), 3)

    def test_multiple_evals(self):
        for eid in ["eval-01", "eval-02"]:
            grading = _make_grading_json(["exp-a"], [], eval_id=eid, trial_num=1)
            _write_grading(self.tmpdir, eid, 1, grading)
        result = aggregate_results(self.tmpdir)
        self.assertEqual(result["metadata"]["evals_run"], 2)

    def test_run_summary_has_stats_per_eval(self):
        """Each eval in run_summary should have computed stats."""
        for trial in range(1, 4):
            grading = _make_grading_json(
                ["exp-a"], [], eval_id="eval-01", trial_num=trial,
                duration_ms=100 * trial,
            )
            _write_grading(self.tmpdir, "eval-01", trial, grading)
        result = aggregate_results(self.tmpdir)
        summary = result["run_summary"]
        # Should have entry for eval-01
        self.assertIn("eval-01", summary)
        eval_summary = summary["eval-01"]
        # Should have stats (from calculate_stats)
        self.assertIn("pass_rate", eval_summary)

    def test_run_preserves_trial_pass_rate(self):
        """Each run entry should carry the pass_rate from its grading."""
        grading = _make_grading_json(["a", "b"], ["c"],
                                     eval_id="eval-01", trial_num=1)
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        result = aggregate_results(self.tmpdir)
        run = result["runs"][0]
        # 2 passed out of 3
        self.assertAlmostEqual(run["pass_rate"], 2 / 3, places=4)


class TestAggregateResultsEmptyDir(unittest.TestCase):
    """AC-2: edge case — no grading.json files found."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_empty_dir_returns_zero_evals(self):
        result = aggregate_results(self.tmpdir)
        self.assertEqual(result["metadata"]["evals_run"], 0)
        self.assertEqual(result["runs"], [])

    def test_empty_dir_still_has_metadata(self):
        result = aggregate_results(self.tmpdir)
        self.assertIn("timestamp", result["metadata"])


class TestAggregateResultsTrialsPerEval(unittest.TestCase):
    """AC-2: metadata.trials_per_eval tracks per-eval trial counts."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_trials_per_eval_counts(self):
        for trial in range(1, 4):
            grading = _make_grading_json(["a"], [], eval_id="eval-01", trial_num=trial)
            _write_grading(self.tmpdir, "eval-01", trial, grading)
        for trial in range(1, 3):
            grading = _make_grading_json(["a"], [], eval_id="eval-02", trial_num=trial)
            _write_grading(self.tmpdir, "eval-02", trial, grading)
        result = aggregate_results(self.tmpdir)
        tpe = result["metadata"]["trials_per_eval"]
        self.assertEqual(tpe["eval-01"], 3)
        self.assertEqual(tpe["eval-02"], 2)


class TestSeedsVerified(unittest.TestCase):
    """AC-19: Every seed in seeds.json must have verified: true."""

    def test_all_seeds_have_verified_field(self):
        seeds_path = os.path.join(
            os.path.dirname(__file__), "..", "suites", "workflow", "seeds.json"
        )
        if not os.path.exists(seeds_path):
            self.skipTest("seeds.json not found")

        with open(seeds_path) as f:
            data = json.load(f)

        for seed in data.get("seeds", []):
            self.assertIn(
                "verified", seed,
                f"Seed {seed.get('id', 'unknown')} missing 'verified' field",
            )

    @unittest.skip("Seeds pending population — run verify_seeds.py first")
    def test_all_seeds_are_verified_true(self):
        seeds_path = os.path.join(
            os.path.dirname(__file__), "..", "suites", "workflow", "seeds.json"
        )
        with open(seeds_path) as f:
            data = json.load(f)

        for seed in data.get("seeds", []):
            self.assertTrue(
                seed.get("verified"),
                f"Seed {seed['id']} is not verified. Run: "
                "python -m evals.framework.verify_seeds --populate --verify",
            )


class TestAggregatorNonCollision(unittest.TestCase):
    """Unit 02b-1 AC-9: aggregate_results does NOT pick up top-level
    files in the results dir. The new comparison.json file added by
    --compare-to-baseline lives at {results_dir}/comparison.json (or
    similar) and must NOT be confused with grading.json files."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_top_level_comparison_json_does_not_collide(self):
        """A top-level comparison.json must not be picked up as a grading file."""
        # Seed a normal run dir with one eval/trial
        grading = _make_grading_json(["a"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)

        # Aggregate without comparison.json
        baseline_result = aggregate_results(self.tmpdir)

        # Drop a comparison.json at the top level — same dir as the
        # `evals/` subdirectory the aggregator scans
        comparison_path = os.path.join(self.tmpdir, "comparison.json")
        with open(comparison_path, "w") as f:
            json.dump({
                "regressions": [],
                "improvements": [],
                "exit_code": 0,
                "table_markdown": "| Eval | Pass Rate |\n",
            }, f)

        # Aggregate again
        with_comparison_result = aggregate_results(self.tmpdir)

        # The aggregated runs should be identical
        self.assertEqual(
            baseline_result["runs"],
            with_comparison_result["runs"],
            "comparison.json was picked up by aggregator — collision detected"
        )
        self.assertEqual(
            baseline_result["metadata"]["evals_run"],
            with_comparison_result["metadata"]["evals_run"],
        )
        self.assertEqual(
            baseline_result["metadata"]["trials_per_eval"],
            with_comparison_result["metadata"]["trials_per_eval"],
        )

    def test_top_level_arbitrary_json_does_not_collide(self):
        """Defensive: ANY top-level *.json should be ignored, not just
        comparison.json. The aggregator's contract is `evals/*/trial-*/grading.json`."""
        grading = _make_grading_json(["a"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        baseline_result = aggregate_results(self.tmpdir)

        # Add several arbitrary top-level json files
        for name in ("benchmark.json", "config.json", "summary.json", "stray-grading.json"):
            with open(os.path.join(self.tmpdir, name), "w") as f:
                json.dump({"arbitrary": "content", "pass_rate": 0.5}, f)

        with_extras_result = aggregate_results(self.tmpdir)
        self.assertEqual(baseline_result["runs"], with_extras_result["runs"])

    def test_grading_json_in_wrong_dir_structure_ignored(self):
        """Even a grading.json file outside the evals/{id}/trial-N/ structure
        is ignored. Confirms the glob pattern is the only path."""
        grading = _make_grading_json(["a"], [], eval_id="eval-01")
        _write_grading(self.tmpdir, "eval-01", 1, grading)
        baseline_result = aggregate_results(self.tmpdir)

        # Stray grading.json at top level (no evals/ wrapper)
        stray_path = os.path.join(self.tmpdir, "grading.json")
        with open(stray_path, "w") as f:
            json.dump({
                "eval_id": "stray", "trial": 1, "pass_rate": 1.0,
            }, f)

        # Stray grading.json one directory deep, but not in evals/
        os.makedirs(os.path.join(self.tmpdir, "other"), exist_ok=True)
        with open(os.path.join(self.tmpdir, "other", "grading.json"), "w") as f:
            json.dump({
                "eval_id": "stray-2", "trial": 1, "pass_rate": 1.0,
            }, f)

        with_strays_result = aggregate_results(self.tmpdir)
        self.assertEqual(baseline_result["runs"], with_strays_result["runs"])
        self.assertNotIn(
            "stray",
            [r["eval_id"] for r in with_strays_result["runs"]],
        )


if __name__ == "__main__":
    unittest.main()
