"""Tests for evals.framework.baseline — schema, loader, validator, comparison.

Unit 02b-1 of the legibility recovery. Adds:
  - BaselineFile dataclass and loader (AC-1, AC-2)
  - validate_baseline_file (AC-2)
  - --validate-baselines CLI flag (AC-3)
  - compare_run_to_baseline + Regression/Improvement/ComparisonResult (AC-7, AC-8)
  - Branch coverage per AC-15

Tokens shape mirrors evals/framework/runner.py RunResult.tokens VERBATIM:
  {input_tokens, output_tokens, cache_creation_input_tokens, cache_read_input_tokens}
NOT a normalized {input, output, total} shape.
"""

import copy
import json
import os
import shutil
import tempfile
import unittest

from evals.framework.baseline import (
    BaselineFile,
    BaselineFileError,
    Regression,
    Improvement,
    ComparisonResult,
    load_baseline,
    validate_baseline_file,
    write_baseline,
    compare_run_to_baseline,
)


# ===========================================================================
# Helpers
# ===========================================================================

_DEFAULT_EVALS = {
    "eval-01": {
        "pass_rate": 1.0,
        "duration_ms": 30000,
        "tokens": {
            "input_tokens": 10000,
            "output_tokens": 2000,
            "cache_creation_input_tokens": 0,
            "cache_read_input_tokens": 0,
        },
        "runs": 3,
    }
}


def _valid_baseline_dict(suite="skill", evals=None):
    """Build a valid baseline dict for fixtures.

    Pass `evals={}` for an explicitly empty evals dict (sentinel `None`
    means "use the default single-eval fixture"). Always deep-copies so
    test mutations don't bleed across tests.
    """
    return {
        "suite": suite,
        "generated_at": "2026-04-08T12:00:00Z",
        "generated_from_commit": "4b60b4c",
        "tolerances": {
            "pass_rate_delta": 0.0,
            "duration_multiplier": 1.25,
            "tokens_multiplier": 1.20,
        },
        "evals": copy.deepcopy(_DEFAULT_EVALS) if evals is None else copy.deepcopy(evals),
    }


def _write_baseline_file(dir_path, suite_name, content):
    path = os.path.join(dir_path, f"{suite_name}.json")
    with open(path, "w") as f:
        json.dump(content, f, indent=2)
    return path


# ===========================================================================
# AC-1, AC-2: Schema, dataclass, loader
# ===========================================================================

class TestBaselineFileLoad(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_loads_valid_baseline_returns_dataclass(self):
        _write_baseline_file(self.tmpdir, "skill", _valid_baseline_dict())
        baseline = load_baseline("skill", baselines_dir=self.tmpdir)
        self.assertIsInstance(baseline, BaselineFile)
        self.assertEqual(baseline.suite, "skill")
        self.assertIn("eval-01", baseline.evals)

    def test_loads_tolerances(self):
        _write_baseline_file(self.tmpdir, "skill", _valid_baseline_dict())
        baseline = load_baseline("skill", baselines_dir=self.tmpdir)
        self.assertEqual(baseline.tolerances["pass_rate_delta"], 0.0)
        self.assertEqual(baseline.tolerances["duration_multiplier"], 1.25)
        self.assertEqual(baseline.tolerances["tokens_multiplier"], 1.20)

    def test_loads_eval_entry_with_runner_tokens_shape(self):
        _write_baseline_file(self.tmpdir, "skill", _valid_baseline_dict())
        baseline = load_baseline("skill", baselines_dir=self.tmpdir)
        eval_01 = baseline.evals["eval-01"]
        self.assertEqual(eval_01["pass_rate"], 1.0)
        self.assertEqual(eval_01["duration_ms"], 30000)
        # Tokens shape mirrors runner.py exactly
        self.assertIn("input_tokens", eval_01["tokens"])
        self.assertIn("output_tokens", eval_01["tokens"])
        self.assertIn("cache_creation_input_tokens", eval_01["tokens"])
        self.assertIn("cache_read_input_tokens", eval_01["tokens"])
        # NOT the fictional shape
        self.assertNotIn("input", eval_01["tokens"])
        self.assertNotIn("total", eval_01["tokens"])

    def test_loads_empty_evals_dict(self):
        d = _valid_baseline_dict(evals={})
        _write_baseline_file(self.tmpdir, "skill", d)
        baseline = load_baseline("skill", baselines_dir=self.tmpdir)
        self.assertEqual(baseline.evals, {})

    def test_missing_file_raises_baseline_file_error(self):
        with self.assertRaises(BaselineFileError) as cm:
            load_baseline("nonexistent", baselines_dir=self.tmpdir)
        self.assertIn("not found", str(cm.exception).lower())

    def test_malformed_json_raises_baseline_file_error(self):
        bad_path = os.path.join(self.tmpdir, "skill.json")
        with open(bad_path, "w") as f:
            f.write("{not valid json")
        with self.assertRaises(BaselineFileError) as cm:
            load_baseline("skill", baselines_dir=self.tmpdir)
        self.assertIn("parse", str(cm.exception).lower())

    def test_missing_required_top_field_raises(self):
        bad = _valid_baseline_dict()
        del bad["suite"]
        _write_baseline_file(self.tmpdir, "skill", bad)
        with self.assertRaises(BaselineFileError):
            load_baseline("skill", baselines_dir=self.tmpdir)

    def test_missing_tolerances_raises(self):
        bad = _valid_baseline_dict()
        del bad["tolerances"]
        _write_baseline_file(self.tmpdir, "skill", bad)
        with self.assertRaises(BaselineFileError):
            load_baseline("skill", baselines_dir=self.tmpdir)

    def test_dunder_comment_field_is_ignored(self):
        """Baseline files MAY include a __comment field for human notes
        about excluded evals. The loader must ignore it, not error."""
        d = _valid_baseline_dict()
        d["__comment"] = "Excluded eval-02 due to pass_rate stddev > 0.1"
        _write_baseline_file(self.tmpdir, "skill", d)
        baseline = load_baseline("skill", baselines_dir=self.tmpdir)
        self.assertEqual(baseline.suite, "skill")


class TestValidateBaselineFile(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_valid_returns_empty_list(self):
        path = _write_baseline_file(self.tmpdir, "skill", _valid_baseline_dict())
        self.assertEqual(validate_baseline_file(path), [])

    def test_missing_top_field_returns_error(self):
        bad = _valid_baseline_dict()
        del bad["generated_at"]
        path = _write_baseline_file(self.tmpdir, "skill", bad)
        errors = validate_baseline_file(path)
        self.assertEqual(len(errors), 1)
        self.assertIn("generated_at", errors[0])

    def test_invalid_tolerances_type_returns_error(self):
        bad = _valid_baseline_dict()
        bad["tolerances"]["pass_rate_delta"] = "not a number"
        path = _write_baseline_file(self.tmpdir, "skill", bad)
        errors = validate_baseline_file(path)
        self.assertTrue(len(errors) >= 1)
        self.assertTrue(any("pass_rate_delta" in e for e in errors))

    def test_invalid_eval_entry_pass_rate_type(self):
        bad = _valid_baseline_dict()
        bad["evals"]["eval-01"]["pass_rate"] = "1.0"  # string, not number
        path = _write_baseline_file(self.tmpdir, "skill", bad)
        errors = validate_baseline_file(path)
        self.assertTrue(any("pass_rate" in e for e in errors))

    def test_pass_rate_out_of_range_returns_error(self):
        bad = _valid_baseline_dict()
        bad["evals"]["eval-01"]["pass_rate"] = 1.5
        path = _write_baseline_file(self.tmpdir, "skill", bad)
        errors = validate_baseline_file(path)
        self.assertTrue(any("pass_rate" in e for e in errors))

    def test_negative_duration_returns_error(self):
        bad = _valid_baseline_dict()
        bad["evals"]["eval-01"]["duration_ms"] = -100
        path = _write_baseline_file(self.tmpdir, "skill", bad)
        errors = validate_baseline_file(path)
        self.assertTrue(any("duration" in e for e in errors))

    def test_missing_baseline_file_returns_error(self):
        errors = validate_baseline_file(os.path.join(self.tmpdir, "nope.json"))
        self.assertTrue(len(errors) >= 1)
        self.assertTrue(any("not found" in e.lower() or "no such" in e.lower() for e in errors))

    def test_malformed_json_returns_error(self):
        path = os.path.join(self.tmpdir, "skill.json")
        with open(path, "w") as f:
            f.write("{not valid")
        errors = validate_baseline_file(path)
        self.assertTrue(len(errors) >= 1)


class TestWriteBaseline(unittest.TestCase):

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_write_then_load_roundtrip(self):
        original = BaselineFile(
            suite="skill",
            generated_at="2026-04-08T12:00:00Z",
            generated_from_commit="abc1234",
            tolerances={
                "pass_rate_delta": 0.0,
                "duration_multiplier": 1.25,
                "tokens_multiplier": 1.20,
            },
            evals={
                "eval-x": {
                    "pass_rate": 0.9,
                    "duration_ms": 12345,
                    "tokens": {
                        "input_tokens": 5000,
                        "output_tokens": 1000,
                        "cache_creation_input_tokens": 0,
                        "cache_read_input_tokens": 0,
                    },
                    "runs": 1,
                },
            },
        )
        path = os.path.join(self.tmpdir, "skill.json")
        write_baseline(original, path)
        loaded = load_baseline("skill", baselines_dir=self.tmpdir)
        self.assertEqual(loaded.suite, original.suite)
        self.assertEqual(loaded.evals, original.evals)
        self.assertEqual(loaded.tolerances, original.tolerances)


# ===========================================================================
# AC-7, AC-8, AC-15: compare_run_to_baseline branch coverage
# ===========================================================================

def _run_results(eval_id="eval-01", pass_rate=1.0, duration_ms=30000,
                 input_tokens=10000, output_tokens=2000):
    """Build a one-eval run_results dict matching the aggregator's shape."""
    return {
        eval_id: {
            "pass_rate": pass_rate,
            "duration_ms": duration_ms,
            "tokens": {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "cache_creation_input_tokens": 0,
                "cache_read_input_tokens": 0,
            },
        }
    }


class TestCompareRunToBaselineHappyPath(unittest.TestCase):

    def test_identical_run_no_regressions_no_improvements(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(_run_results(), baseline)
        self.assertIsInstance(result, ComparisonResult)
        self.assertEqual(result.regressions, [])
        # Identical → no strict improvement
        self.assertEqual(result.exit_code, 0)

    def test_returns_table_markdown(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(_run_results(), baseline)
        self.assertIsInstance(result.table_markdown, str)
        self.assertIn("|", result.table_markdown)
        self.assertIn("eval-01", result.table_markdown)


class TestCompareRunToBaselineRegressions(unittest.TestCase):

    def test_pass_rate_regression_strict_zero_tolerance(self):
        """Pass rate below baseline by ANY amount → regression."""
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(pass_rate=0.99), baseline
        )
        self.assertEqual(result.exit_code, 1)
        self.assertEqual(len(result.regressions), 1)
        self.assertEqual(result.regressions[0].metric, "pass_rate")
        self.assertEqual(result.regressions[0].eval_id, "eval-01")

    def test_pass_rate_at_baseline_no_regression(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(pass_rate=1.0), baseline
        )
        self.assertEqual(result.regressions, [])

    def test_duration_over_tolerance_multiplier_is_regression(self):
        """duration_multiplier=1.25 → 30000 * 1.25 = 37500 is the limit."""
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(duration_ms=37501), baseline
        )
        self.assertEqual(result.exit_code, 1)
        self.assertTrue(any(r.metric == "duration_ms" for r in result.regressions))

    def test_duration_at_tolerance_boundary_passes(self):
        """At exactly the tolerance boundary, no regression."""
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(duration_ms=37500), baseline
        )
        self.assertEqual(result.regressions, [])

    def test_duration_just_under_baseline_no_regression(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(duration_ms=29999), baseline
        )
        self.assertEqual(result.regressions, [])

    def test_input_tokens_over_tolerance_is_regression(self):
        """tokens_multiplier=1.20 → 10000 * 1.20 = 12000 is the limit."""
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(input_tokens=12001), baseline
        )
        self.assertEqual(result.exit_code, 1)
        token_regs = [r for r in result.regressions if r.metric.startswith("tokens.")]
        self.assertTrue(len(token_regs) >= 1)

    def test_output_tokens_over_tolerance_is_regression(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(output_tokens=2401), baseline
        )
        self.assertEqual(result.exit_code, 1)

    def test_tokens_at_tolerance_boundary_passes(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(input_tokens=12000, output_tokens=2400), baseline
        )
        self.assertEqual(result.regressions, [])

    def test_multiple_regressions_all_reported(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(pass_rate=0.5, duration_ms=99999, input_tokens=99999),
            baseline,
        )
        self.assertEqual(result.exit_code, 1)
        # At least 3: pass_rate, duration_ms, tokens.input_tokens
        self.assertGreaterEqual(len(result.regressions), 3)

    def test_table_marks_regression_rows(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(duration_ms=37501), baseline
        )
        self.assertIn("| eval-01 |", result.table_markdown)
        self.assertIn("| regression |", result.table_markdown)


class TestCompareRunToBaselineImprovements(unittest.TestCase):

    def test_pass_rate_improvement(self):
        d = _valid_baseline_dict()
        d["evals"]["eval-01"]["pass_rate"] = 0.8
        baseline = BaselineFile(**d)
        result = compare_run_to_baseline(
            _run_results(pass_rate=0.95), baseline
        )
        self.assertEqual(result.exit_code, 0)
        self.assertTrue(any(i.metric == "pass_rate" for i in result.improvements))

    def test_duration_improvement(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(duration_ms=20000), baseline
        )
        self.assertTrue(any(i.metric == "duration_ms" for i in result.improvements))
        self.assertEqual(result.exit_code, 0)

    def test_tokens_improvement(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(input_tokens=8000), baseline
        )
        self.assertTrue(any(i.metric.startswith("tokens.") for i in result.improvements))

    def test_table_marks_improvement_rows(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        result = compare_run_to_baseline(
            _run_results(duration_ms=20000), baseline
        )
        self.assertIn("| improved |", result.table_markdown)


class TestCompareRunToBaselineMissingEntries(unittest.TestCase):

    def test_eval_in_run_but_not_baseline_warn_only(self):
        """A new eval not in the baseline is reported as missing_from_baseline,
        not a regression. Exit code stays 0."""
        baseline = BaselineFile(**_valid_baseline_dict())
        run = _run_results(eval_id="eval-new-99")
        result = compare_run_to_baseline(run, baseline)
        self.assertIn("eval-new-99", result.missing_from_baseline)
        self.assertEqual(result.regressions, [])
        self.assertEqual(result.exit_code, 0)

    def test_eval_in_baseline_but_not_run_warn_only(self):
        """A skipped eval that's in the baseline shows up in missing_from_run,
        not a regression."""
        baseline = BaselineFile(**_valid_baseline_dict())
        empty_run: dict = {}
        result = compare_run_to_baseline(empty_run, baseline)
        self.assertIn("eval-01", result.missing_from_run)
        self.assertEqual(result.regressions, [])
        self.assertEqual(result.exit_code, 0)

    def test_table_markdown_marks_new_evals(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        run = _run_results(eval_id="eval-new")
        result = compare_run_to_baseline(run, baseline)
        self.assertIn("eval-new", result.table_markdown)
        self.assertIn("new", result.table_markdown.lower())


class TestCompareRunToBaselineCustomTolerances(unittest.TestCase):

    def test_custom_duration_multiplier_loosens_threshold(self):
        d = _valid_baseline_dict()
        d["tolerances"]["duration_multiplier"] = 2.0  # 2x slack
        baseline = BaselineFile(**d)
        result = compare_run_to_baseline(
            _run_results(duration_ms=59000), baseline  # nearly 2x baseline
        )
        self.assertEqual(result.regressions, [])

    def test_custom_tokens_multiplier_tightens_threshold(self):
        d = _valid_baseline_dict()
        d["tolerances"]["tokens_multiplier"] = 1.05  # 5% slack
        baseline = BaselineFile(**d)
        result = compare_run_to_baseline(
            _run_results(input_tokens=10600), baseline  # 6% over baseline
        )
        self.assertEqual(result.exit_code, 1)


class TestCompareRunToBaselineEdgeCases(unittest.TestCase):

    def test_empty_baseline_with_run_marks_all_as_new(self):
        d = _valid_baseline_dict(evals={})
        baseline = BaselineFile(**d)
        result = compare_run_to_baseline(_run_results(), baseline)
        self.assertEqual(result.regressions, [])
        self.assertIn("eval-01", result.missing_from_baseline)

    def test_run_missing_tokens_field_treated_as_zero(self):
        baseline = BaselineFile(**_valid_baseline_dict())
        run = {
            "eval-01": {
                "pass_rate": 1.0,
                "duration_ms": 30000,
                "tokens": {},  # empty
            }
        }
        result = compare_run_to_baseline(run, baseline)
        # Empty tokens should not cause regression — 0 ≤ baseline
        self.assertEqual(result.regressions, [])

    def test_baseline_missing_token_key_no_comparison_for_that_key(self):
        d = _valid_baseline_dict()
        # Drop output_tokens from baseline
        del d["evals"]["eval-01"]["tokens"]["output_tokens"]
        baseline = BaselineFile(**d)
        # Run has high output_tokens — should NOT be a regression because
        # we only compare keys present in baseline
        result = compare_run_to_baseline(
            _run_results(output_tokens=999999), baseline
        )
        self.assertEqual(result.regressions, [])


# ===========================================================================
# End-to-end integration test (added in response to PR #151 review)
#
# The original 02b-1 unit tests synthesized run_results dicts directly,
# never going through the real aggregator. PR #151 review caught three
# P1 bugs that survived 40 unit tests because of this gap:
#   1. summary["pass_rate_mean"] doesn't exist (real shape is
#      summary["pass_rate"]["mean"])
#   2. summary["tokens"] was always {} because aggregator never read
#      execution.tokens from per-grading files
#   3. _render_table's :+d format crashed on float duration values
# This test exercises the full pipeline so the integration seam stays
# tested forever.
# ===========================================================================

import os
from evals.framework.aggregator import aggregate_results


def _write_grading_with_tokens(
    base_dir, eval_id, trial_num, pass_rate, duration_ms,
    input_tokens=0, output_tokens=0, cache_creation_input_tokens=0,
    cache_read_input_tokens=0,
):
    """Mirror the shape of grading.json files written by run_single_eval."""
    eval_dir = os.path.join(base_dir, "evals", eval_id, f"trial-{trial_num}")
    os.makedirs(eval_dir, exist_ok=True)
    grading = {
        "eval_id": eval_id,
        "trial": trial_num,
        "pass_rate": pass_rate,
        "duration_ms": duration_ms,
        "expectations": [],
        "summary": {"total": 1, "passed": 1, "failed": 0, "skipped": 0,
                    "pass_rate": pass_rate},
        "execution": {
            "exit_code": 0,
            "duration_ms": duration_ms,
            "tokens": {
                "input_tokens": input_tokens,
                "output_tokens": output_tokens,
                "cache_creation_input_tokens": cache_creation_input_tokens,
                "cache_read_input_tokens": cache_read_input_tokens,
            },
        },
    }
    with open(os.path.join(eval_dir, "grading.json"), "w") as f:
        json.dump(grading, f)


class TestEndToEndAggregatorToBaseline(unittest.TestCase):
    """The full pipeline: write grading.json → aggregate_results → build
    baseline → compare_run_to_baseline.

    This test would have caught all 3 P1 bugs from PR #151 review.
    """

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_aggregator_run_summary_has_nested_pass_rate_mean(self):
        """REGRESSION: PR #151 access pattern was summary['pass_rate_mean']
        which doesn't exist. Real shape is summary['pass_rate']['mean']."""
        _write_grading_with_tokens(
            self.tmpdir, "e2e-eval-01", 1,
            pass_rate=0.75, duration_ms=12000,
            input_tokens=5000, output_tokens=1000,
        )
        agg = aggregate_results(self.tmpdir)
        run_summary = agg["run_summary"]
        self.assertIn("e2e-eval-01", run_summary)
        eval_summary = run_summary["e2e-eval-01"]

        # The pass_rate is a nested dict with 'mean', not a flat 'pass_rate_mean'
        self.assertIn("pass_rate", eval_summary)
        self.assertIsInstance(eval_summary["pass_rate"], dict)
        self.assertIn("mean", eval_summary["pass_rate"])
        self.assertNotIn("pass_rate_mean", eval_summary)
        self.assertEqual(eval_summary["pass_rate"]["mean"], 0.75)

        # Same for duration_ms
        self.assertIn("duration_ms", eval_summary)
        self.assertIsInstance(eval_summary["duration_ms"], dict)
        self.assertIn("mean", eval_summary["duration_ms"])
        self.assertEqual(eval_summary["duration_ms"]["mean"], 12000)

    def test_aggregator_collects_tokens_from_execution(self):
        """REGRESSION: aggregator originally did not read execution.tokens
        from grading files, so summary['tokens'] was always {}."""
        _write_grading_with_tokens(
            self.tmpdir, "e2e-tokens", 1,
            pass_rate=1.0, duration_ms=10000,
            input_tokens=5000, output_tokens=1000,
            cache_creation_input_tokens=200, cache_read_input_tokens=100,
        )
        agg = aggregate_results(self.tmpdir)
        eval_summary = agg["run_summary"]["e2e-tokens"]
        self.assertIn("tokens", eval_summary)
        self.assertEqual(eval_summary["tokens"]["input_tokens"], 5000)
        self.assertEqual(eval_summary["tokens"]["output_tokens"], 1000)
        self.assertEqual(eval_summary["tokens"]["cache_creation_input_tokens"], 200)
        self.assertEqual(eval_summary["tokens"]["cache_read_input_tokens"], 100)

    def test_aggregator_means_tokens_across_trials(self):
        """Multiple trials → tokens are mean-aggregated per key."""
        for trial, (it, ot) in enumerate(((4000, 800), (6000, 1200)), start=1):
            _write_grading_with_tokens(
                self.tmpdir, "e2e-multi", trial,
                pass_rate=1.0, duration_ms=10000,
                input_tokens=it, output_tokens=ot,
            )
        agg = aggregate_results(self.tmpdir)
        tokens = agg["run_summary"]["e2e-multi"]["tokens"]
        self.assertEqual(tokens["input_tokens"], 5000.0)  # (4000 + 6000) / 2
        self.assertEqual(tokens["output_tokens"], 1000.0)  # (800 + 1200) / 2

    def test_aggregator_handles_missing_tokens_gracefully(self):
        """A grading file without execution.tokens should not crash;
        the eval just gets an empty tokens dict in the summary."""
        # Write grading WITHOUT execution.tokens (older format)
        eval_dir = os.path.join(self.tmpdir, "evals", "e2e-no-tokens", "trial-1")
        os.makedirs(eval_dir)
        with open(os.path.join(eval_dir, "grading.json"), "w") as f:
            json.dump({
                "eval_id": "e2e-no-tokens", "trial": 1,
                "pass_rate": 1.0, "duration_ms": 10000,
                # no execution field at all
            }, f)
        agg = aggregate_results(self.tmpdir)
        self.assertEqual(agg["run_summary"]["e2e-no-tokens"]["tokens"], {})

    def test_full_pipeline_aggregator_to_baseline_to_compare_clean(self):
        """End-to-end: write graders → aggregate → write baseline →
        re-aggregate identical run → compare → no regressions, exit 0.
        Goes through every layer the PR review found bugs in."""
        # Step 1: write grading files (simulating a real eval run)
        _write_grading_with_tokens(
            self.tmpdir, "pipeline-eval", 1,
            pass_rate=1.0, duration_ms=15000,
            input_tokens=8000, output_tokens=1500,
        )
        # Step 2: aggregate
        agg = aggregate_results(self.tmpdir)
        run_summary = agg["run_summary"]
        # Step 3: build baseline using the SAME shape the CLI uses
        evals_dict = {}
        for eval_id, summary in run_summary.items():
            evals_dict[eval_id] = {
                "pass_rate": summary["pass_rate"]["mean"],
                "duration_ms": int(summary["duration_ms"]["mean"]),
                "tokens": summary["tokens"],
                "runs": summary["trial_count"],
            }
        baseline = BaselineFile(
            suite="test",
            generated_at="2026-04-08T13:00:00Z",
            generated_from_commit="abc1234",
            tolerances={
                "pass_rate_delta": 0.0,
                "duration_multiplier": 1.25,
                "tokens_multiplier": 1.20,
            },
            evals=evals_dict,
        )
        # Step 4: build run_results using the SAME shape (simulating
        # --compare-to-baseline against this baseline)
        run_results = {}
        for eval_id, summary in run_summary.items():
            run_results[eval_id] = {
                "pass_rate": summary["pass_rate"]["mean"],
                "duration_ms": int(summary["duration_ms"]["mean"]),
                "tokens": summary["tokens"],
            }
        # Step 5: compare — must NOT crash on the format string and must
        # report no regressions on identical input
        result = compare_run_to_baseline(run_results, baseline)
        self.assertEqual(result.exit_code, 0,
                         f"Expected clean run, got regressions: {result.regressions}")
        self.assertEqual(result.regressions, [])
        # Table renders without crashing
        self.assertIsInstance(result.table_markdown, str)
        self.assertIn("pipeline-eval", result.table_markdown)

    def test_full_pipeline_detects_real_regression(self):
        """End-to-end: build baseline from one run, then compare against
        a SECOND run with worse metrics. Must detect the regression. This
        test would have failed before the key-mismatch fix."""
        # First run — clean baseline values
        baseline_dir = os.path.join(self.tmpdir, "baseline-run")
        _write_grading_with_tokens(
            baseline_dir, "regress-test", 1,
            pass_rate=1.0, duration_ms=10000,
            input_tokens=5000, output_tokens=1000,
        )
        baseline_agg = aggregate_results(baseline_dir)

        # Build the baseline FROM the aggregator output (the buggy CLI
        # path the review caught — this is the exact code path)
        evals_dict = {}
        for eval_id, summary in baseline_agg["run_summary"].items():
            evals_dict[eval_id] = {
                "pass_rate": summary["pass_rate"]["mean"],
                "duration_ms": int(summary["duration_ms"]["mean"]),
                "tokens": summary["tokens"],
                "runs": summary["trial_count"],
            }
        baseline = BaselineFile(
            suite="test",
            generated_at="2026-04-08T13:00:00Z",
            generated_from_commit="abc",
            tolerances={
                "pass_rate_delta": 0.0,
                "duration_multiplier": 1.25,
                "tokens_multiplier": 1.20,
            },
            evals=evals_dict,
        )
        # Verify baseline actually has real values, not zeros
        self.assertEqual(baseline.evals["regress-test"]["pass_rate"], 1.0)
        self.assertEqual(baseline.evals["regress-test"]["duration_ms"], 10000)
        self.assertEqual(baseline.evals["regress-test"]["tokens"]["input_tokens"], 5000)

        # Second run — pass rate dropped, duration much higher, tokens up
        regress_dir = os.path.join(self.tmpdir, "regress-run")
        _write_grading_with_tokens(
            regress_dir, "regress-test", 1,
            pass_rate=0.5, duration_ms=20000,  # well over 1.25x baseline
            input_tokens=8000, output_tokens=2000,  # over 1.20x baseline
        )
        regress_agg = aggregate_results(regress_dir)
        run_results = {}
        for eval_id, summary in regress_agg["run_summary"].items():
            run_results[eval_id] = {
                "pass_rate": summary["pass_rate"]["mean"],
                "duration_ms": int(summary["duration_ms"]["mean"]),
                "tokens": summary["tokens"],
            }

        result = compare_run_to_baseline(run_results, baseline)
        # Three distinct regressions: pass_rate, duration_ms, input_tokens, output_tokens
        self.assertEqual(result.exit_code, 1)
        self.assertGreaterEqual(len(result.regressions), 3)
        metrics_hit = {r.metric for r in result.regressions}
        self.assertIn("pass_rate", metrics_hit)
        self.assertIn("duration_ms", metrics_hit)
        # At least one tokens.* regression
        token_regressions = [m for m in metrics_hit if m.startswith("tokens.")]
        self.assertGreaterEqual(len(token_regressions), 1)

    def test_table_render_does_not_crash_on_float_duration(self):
        """REGRESSION: _render_table used :+d format which crashed on
        floats. After the aggregator fix, run_dur is float (mean of trials)."""
        _write_grading_with_tokens(
            self.tmpdir, "float-dur", 1,
            pass_rate=1.0, duration_ms=15000,
            input_tokens=5000, output_tokens=1000,
        )
        _write_grading_with_tokens(
            self.tmpdir, "float-dur", 2,
            pass_rate=1.0, duration_ms=14000,
            input_tokens=5000, output_tokens=1000,
        )
        # Two trials produce float means — exact bug repro condition
        agg = aggregate_results(self.tmpdir)
        evals_dict = {}
        for eval_id, summary in agg["run_summary"].items():
            evals_dict[eval_id] = {
                "pass_rate": summary["pass_rate"]["mean"],
                "duration_ms": int(summary["duration_ms"]["mean"]),
                "tokens": summary["tokens"],
                "runs": summary["trial_count"],
            }
        baseline = BaselineFile(
            suite="test",
            generated_at="2026-04-08T13:00:00Z",
            generated_from_commit="abc",
            tolerances={
                "pass_rate_delta": 0.0,
                "duration_multiplier": 1.25,
                "tokens_multiplier": 1.20,
            },
            evals=evals_dict,
        )
        # Pass float duration directly — this is what the CLI used to do
        run_results = {
            "float-dur": {
                "pass_rate": 1.0,
                "duration_ms": 14500.0,  # FLOAT — would crash :+d
                "tokens": {"input_tokens": 5000, "output_tokens": 1000,
                           "cache_creation_input_tokens": 0,
                           "cache_read_input_tokens": 0},
            }
        }
        # Must not raise ValueError
        result = compare_run_to_baseline(run_results, baseline)
        self.assertIsInstance(result.table_markdown, str)
        self.assertIn("float-dur", result.table_markdown)


if __name__ == "__main__":
    unittest.main()
