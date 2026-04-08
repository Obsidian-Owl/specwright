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


if __name__ == "__main__":
    unittest.main()
