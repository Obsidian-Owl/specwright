"""Tests for evals.framework.orchestrator and evals.__main__ CLI entry point.

Acceptance criteria covered:
  AC-8:  run_single_eval() Layer 1 — calls runner.run_skill() with prompt from prompts.py
  AC-9:  run_single_eval() Layer 2 — calls chainer.run_sequence() with prompts dict
  AC-11: Fixture-based seeds — calls setup_fixture(), cleans up temp dir after
  AC-13: After execution, calls grade_eval(eval_case, workdir, snapshots)
  AC-14: Writes grading.json with flattened fields (eval_id, trial, pass_rate, duration_ms)
  AC-15: Calls aggregate_results() after all trials, writes benchmark.json
  AC-17: On skill timeout/failure, still grades and writes results
  AC-18: On setup failure, writes error grading.json with pass_rate: 0.0
  AC-19: Prints progress to stderr
  CLI AC-1: --suite loads correct JSON, writes to results dir
  CLI AC-2: --case filters to single case, invalid ID exits non-zero
  CLI AC-3: --trials N creates trial-1..trial-N directories
  CLI AC-6: --dry-run prints cases without running
  CLI AC-7: --timeout passed through
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import MagicMock, call, patch

from evals.framework.orchestrator import run_single_eval, run_eval_suite
from evals.framework.runner import RunResult, ToolRunner


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_run_result(exit_code=0, stdout="", stderr="", duration_ms=1500):
    """Build a RunResult with sensible defaults."""
    return RunResult(
        exit_code=exit_code,
        stdout=stdout,
        stderr=stderr,
        transcript=[],
        tokens={"input": 100, "output": 50},
        duration_ms=duration_ms,
    )


def _make_skill_eval_case(eval_id="eval-skill-01", skill="sw-build",
                           fixture_path=None):
    """Build a Layer 1 (skill) eval case dict matching evals.json schema."""
    return {
        "id": eval_id,
        "layer": "skill",
        "skill": skill,
        "prompt_template": "build",
        "prompt_args": {},
        "seed": {
            "type": "fixture",
            "path": fixture_path or "suites/skill/fixtures/sw-build/simple-function",
        },
        "expectations": [
            {"type": "file_exists", "path": "src/math.ts"},
        ],
    }


def _make_integration_eval_case(eval_id="eval-int-01",
                                 sequence=None, fixture_path=None):
    """Build a Layer 2 (integration) eval case dict."""
    return {
        "id": eval_id,
        "layer": "integration",
        "sequence": sequence or ["sw-design", "sw-plan"],
        "prompt_args": {"problem_statement": "Add rate limiting"},
        "seed": {
            "type": "fixture",
            "path": fixture_path or "suites/integration/fixtures/design-to-plan",
        },
        "expectations": [
            {"type": "file_exists", "path": ".specwright/work/test-work/spec.md"},
        ],
    }


def _make_structural_eval_case(
    eval_id="eval-struct-01",
    command="python -c \"print('ok')\"",
    smoke=True,
):
    """Build a structural eval case dict for Unit 02d smoke evals."""
    return {
        "id": eval_id,
        "type": "structural",
        "command": command,
        "smoke": smoke,
        "expectations": [],
    }


def _make_fixture_dir(tmpdir):
    """Create a minimal fixture directory with required structure."""
    fixture = os.path.join(tmpdir, "fixture")
    os.makedirs(os.path.join(fixture, ".specwright", "state"), exist_ok=True)
    with open(os.path.join(fixture, ".specwright", "state", "workflow.json"), "w") as f:
        json.dump({"currentWork": {"status": "building"}}, f)
    with open(os.path.join(fixture, "package.json"), "w") as f:
        json.dump({"name": "test"}, f)
    return fixture


def _make_suite_json(tmpdir, evals, suite_name="test-suite"):
    """Write an evals.json file and return its path."""
    suite = {
        "suite": suite_name,
        "version": "1.0",
        "evals": evals,
    }
    suite_path = os.path.join(tmpdir, "evals.json")
    with open(suite_path, "w") as f:
        json.dump(suite, f)
    return suite_path


def _read_grading_json(results_dir, eval_id, trial_num):
    """Read grading.json from the standard directory layout."""
    path = os.path.join(
        results_dir, "evals", eval_id, f"trial-{trial_num}", "grading.json"
    )
    with open(path) as f:
        return json.load(f)


class MockRunner(ToolRunner):
    """Mock runner that records calls and returns configurable results."""

    def __init__(self, result=None, side_effect=None):
        self.calls = []
        self._result = result or _make_run_result()
        self._side_effect = side_effect

    def run_skill(self, skill, prompt, workdir=None, timeout=300):
        self.calls.append({
            "skill": skill,
            "prompt": prompt,
            "workdir": workdir,
            "timeout": timeout,
        })
        if self._side_effect:
            effect = self._side_effect.pop(0)
            if isinstance(effect, Exception):
                raise effect
            return effect
        return self._result


# ===========================================================================
# AC-8: run_single_eval() Layer 1 — skill execution
# ===========================================================================

class TestRunSingleEvalLayer1Invocation(unittest.TestCase):
    """AC-8: Layer 1 evals call runner.run_skill() with prompt from prompts.py."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_calls_run_skill_for_layer1(self, mock_setup):
        """Layer 1 eval must invoke runner.run_skill exactly once."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        self.assertEqual(len(self.runner.calls), 1)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_passes_correct_skill_name(self, mock_setup):
        """Layer 1 eval passes the skill name from eval case to runner."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(skill="sw-init", fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        self.assertEqual(self.runner.calls[0]["skill"], "sw-init")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_prompt_comes_from_prompts_module(self, mock_setup):
        """Layer 1 eval uses prompts.py template, not raw prompt_template string."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        case["prompt_template"] = "build"
        case["prompt_args"] = {}
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        prompt_used = self.runner.calls[0]["prompt"]
        # prompts.build() returns a string containing "Run /sw-build"
        self.assertIn("/sw-build", prompt_used)
        self.assertIn("TDD", prompt_used)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_prompt_args_passed_to_template(self, mock_setup):
        """Layer 1 eval passes prompt_args to the template function."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        case["prompt_template"] = "init"
        case["prompt_args"] = {"project_type": "python"}
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        prompt_used = self.runner.calls[0]["prompt"]
        self.assertIn("python", prompt_used)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_timeout_forwarded_to_runner(self, mock_setup):
        """Timeout parameter must be forwarded to runner.run_skill."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner, timeout=600)
        self.assertEqual(self.runner.calls[0]["timeout"], 600)


# ===========================================================================
# AC-9: run_single_eval() Layer 2 — integration/chain execution
# ===========================================================================

class TestRunSingleEvalLayer2Invocation(unittest.TestCase):
    """AC-9: Layer 2 evals call chainer.run_sequence() with prompts dict."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.run_sequence")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_calls_run_sequence_for_layer2(self, mock_setup, mock_chain):
        """Layer 2 eval must call chainer.run_sequence, not runner.run_skill directly."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        from evals.framework.chainer import ChainResult
        mock_chain.return_value = ChainResult(
            steps=[_make_run_result()],
            snapshots=[{"workflow_state": {"currentWork": {"status": "designing"}}}],
        )
        case = _make_integration_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        mock_chain.assert_called_once()

    @patch("evals.framework.orchestrator.run_sequence")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_passes_sequence_skills(self, mock_setup, mock_chain):
        """Layer 2 passes the correct skill sequence to run_sequence."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        from evals.framework.chainer import ChainResult
        mock_chain.return_value = ChainResult(steps=[], snapshots=[])
        case = _make_integration_eval_case(
            sequence=["sw-plan", "sw-build"],
            fixture_path=self.fixture_dir,
        )
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        call_args = mock_chain.call_args
        # Second positional arg or 'skills' keyword should be the sequence
        skills_arg = call_args[1].get("skills") if call_args[1] else call_args[0][1]
        self.assertEqual(skills_arg, ["sw-plan", "sw-build"])

    @patch("evals.framework.orchestrator.run_sequence")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_passes_prompts_dict_for_each_skill(self, mock_setup, mock_chain):
        """Layer 2 builds a prompts dict keyed by skill name."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        from evals.framework.chainer import ChainResult
        mock_chain.return_value = ChainResult(steps=[], snapshots=[])
        case = _make_integration_eval_case(
            sequence=["sw-design", "sw-plan"],
            fixture_path=self.fixture_dir,
        )
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        call_args = mock_chain.call_args
        prompts_arg = call_args[1].get("prompts") if call_args[1] else call_args[0][2]
        # Should have keys for each skill in sequence
        self.assertIn("sw-design", prompts_arg)
        self.assertIn("sw-plan", prompts_arg)
        # Each value should be a non-empty string (from prompts module)
        for skill, prompt in prompts_arg.items():
            self.assertIsInstance(prompt, str)
            self.assertGreater(len(prompt), 10,
                               f"Prompt for {skill} too short to be real template")

    @patch("evals.framework.orchestrator.run_sequence")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_does_not_call_run_skill_directly_for_layer2(self, mock_setup, mock_chain):
        """Layer 2 must not call runner.run_skill directly."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        from evals.framework.chainer import ChainResult
        mock_chain.return_value = ChainResult(steps=[], snapshots=[])
        case = _make_integration_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        self.assertEqual(len(self.runner.calls), 0)


# ===========================================================================
# AC-11: Fixture-based seeds — setup and cleanup
# ===========================================================================

class TestFixtureSetupAndCleanup(unittest.TestCase):
    """AC-11: Fixture seeds call setup_fixture() and clean up temp dir after."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_calls_setup_fixture_with_seed_path(self, mock_setup):
        """setup_fixture is called with the seed path from eval case."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        mock_setup.assert_called_once()
        call_args = mock_setup.call_args[0]
        self.assertEqual(call_args[0], self.fixture_dir)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_workdir_is_temp_directory(self, mock_setup):
        """The workdir passed to setup_fixture is a temp directory, not the fixture."""
        captured_workdirs = []
        def capture_setup(src, dst):
            captured_workdirs.append(dst)
            shutil.copytree(self.fixture_dir, dst)
        mock_setup.side_effect = capture_setup
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        workdir = captured_workdirs[0]
        # workdir should not be the fixture itself
        self.assertNotEqual(os.path.realpath(workdir),
                            os.path.realpath(self.fixture_dir))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_workdir_cleaned_up_after_execution(self, mock_setup):
        """Temp workdir should be cleaned up after run_single_eval completes."""
        captured_workdirs = []
        def capture_setup(src, dst):
            captured_workdirs.append(dst)
            shutil.copytree(self.fixture_dir, dst)
        mock_setup.side_effect = capture_setup
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        workdir = captured_workdirs[0]
        self.assertFalse(os.path.exists(workdir),
                         f"Workdir {workdir} should be cleaned up after execution")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_workdir_cleaned_up_even_on_failure(self, mock_setup):
        """Temp workdir cleaned up even when the skill execution fails."""
        captured_workdirs = []
        def capture_setup(src, dst):
            captured_workdirs.append(dst)
            shutil.copytree(self.fixture_dir, dst)
        mock_setup.side_effect = capture_setup
        runner = MockRunner(result=_make_run_result(exit_code=1))
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        workdir = captured_workdirs[0]
        self.assertFalse(os.path.exists(workdir),
                         "Workdir should be cleaned up even after skill failure")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_different_trials_use_different_workdirs(self, mock_setup):
        """Each trial must use a fresh, separate workdir."""
        captured_workdirs = []
        def capture_setup(src, dst):
            captured_workdirs.append(dst)
            shutil.copytree(self.fixture_dir, dst)
        mock_setup.side_effect = capture_setup
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        run_single_eval(case, trial_num=2, results_dir=self.results_dir,
                        runner=self.runner)
        self.assertEqual(len(captured_workdirs), 2)
        self.assertNotEqual(captured_workdirs[0], captured_workdirs[1])


# ===========================================================================
# AC-13: After execution, calls grade_eval()
# ===========================================================================

class TestGradingInvocation(unittest.TestCase):
    """AC-13: run_single_eval calls grade_eval(eval_case, workdir, snapshots)."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.grade_eval")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grade_eval_called_after_skill_run(self, mock_setup, mock_grade):
        """grade_eval must be called after skill execution completes."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        mock_grade.return_value = {
            "expectations": [], "summary": {"total": 0, "passed": 0,
            "failed": 0, "skipped": 0, "pass_rate": 0.0},
            "timing": {"duration_ms": 10},
        }
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        mock_grade.assert_called_once()

    @patch("evals.framework.orchestrator.grade_eval")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grade_eval_receives_eval_case(self, mock_setup, mock_grade):
        """grade_eval receives the original eval case dict."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        mock_grade.return_value = {
            "expectations": [], "summary": {"total": 0, "passed": 0,
            "failed": 0, "skipped": 0, "pass_rate": 0.0},
            "timing": {"duration_ms": 10},
        }
        case = _make_skill_eval_case(eval_id="grade-test", fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        call_args = mock_grade.call_args[0]
        self.assertEqual(call_args[0]["id"], "grade-test")

    @patch("evals.framework.orchestrator.grade_eval")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grade_eval_receives_workdir(self, mock_setup, mock_grade):
        """grade_eval receives a workdir path that is a string."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        mock_grade.return_value = {
            "expectations": [], "summary": {"total": 0, "passed": 0,
            "failed": 0, "skipped": 0, "pass_rate": 0.0},
            "timing": {"duration_ms": 10},
        }
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        call_args = mock_grade.call_args[0]
        self.assertIsInstance(call_args[1], str)
        # workdir should be a real path that was set up (before cleanup)
        self.assertGreater(len(call_args[1]), 0)

    @patch("evals.framework.orchestrator.run_sequence")
    @patch("evals.framework.orchestrator.grade_eval")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grade_eval_receives_snapshots_for_layer2(self, mock_setup,
                                                       mock_grade, mock_chain):
        """Layer 2 passes chain snapshots to grade_eval."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        from evals.framework.chainer import ChainResult
        fake_snapshots = [
            {"workflow_state": {"currentWork": {"status": "designing"}}},
            {"workflow_state": {"currentWork": {"status": "planning"}}},
        ]
        mock_chain.return_value = ChainResult(
            steps=[_make_run_result(), _make_run_result()],
            snapshots=fake_snapshots,
        )
        mock_grade.return_value = {
            "expectations": [], "summary": {"total": 0, "passed": 0,
            "failed": 0, "skipped": 0, "pass_rate": 0.0},
            "timing": {"duration_ms": 10},
        }
        case = _make_integration_eval_case(fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        call_args = mock_grade.call_args
        # snapshots should be the third positional arg or keyword
        if len(call_args[0]) >= 3:
            snapshots = call_args[0][2]
        else:
            snapshots = call_args[1].get("snapshots")
        self.assertEqual(len(snapshots), 2)
        self.assertEqual(snapshots[0]["workflow_state"]["currentWork"]["status"],
                         "designing")


# ===========================================================================
# AC-14: Writes grading.json with flattened fields
# ===========================================================================

class TestGradingJsonOutput(unittest.TestCase):
    """AC-14: run_single_eval writes grading.json with flattened fields."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_file_exists(self, mock_setup):
        """grading.json must be written under results/evals/{id}/trial-{n}/."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="grading-test",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        path = os.path.join(
            self.results_dir, "evals", "grading-test", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(path), f"Expected {path} to exist")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_has_eval_id(self, mock_setup):
        """grading.json must contain eval_id field matching the eval case."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="id-check",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "id-check", 1)
        self.assertEqual(grading["eval_id"], "id-check")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_has_trial_number(self, mock_setup):
        """grading.json must contain trial field matching trial_num."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="trial-check",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=3, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "trial-check", 3)
        self.assertEqual(grading["trial"], 3)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_has_pass_rate(self, mock_setup):
        """grading.json must contain pass_rate as a float between 0.0 and 1.0."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="rate-check",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "rate-check", 1)
        self.assertIn("pass_rate", grading)
        self.assertIsInstance(grading["pass_rate"], float)
        self.assertGreaterEqual(grading["pass_rate"], 0.0)
        self.assertLessEqual(grading["pass_rate"], 1.0)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_has_duration_ms(self, mock_setup):
        """grading.json must contain duration_ms as a numeric value."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="dur-check",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "dur-check", 1)
        self.assertIn("duration_ms", grading)
        self.assertIsInstance(grading["duration_ms"], (int, float))
        self.assertGreaterEqual(grading["duration_ms"], 0)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_fields_are_flat(self, mock_setup):
        """All required fields (eval_id, trial, pass_rate, duration_ms) are
        top-level keys, not nested in sub-dicts."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="flat-check",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=2, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "flat-check", 2)
        required_flat = {"eval_id", "trial", "pass_rate", "duration_ms"}
        for key in required_flat:
            self.assertIn(key, grading,
                          f"'{key}' must be a top-level key in grading.json")
            # Must not be nested in summary or timing
            self.assertNotIsInstance(grading[key], dict,
                                     f"'{key}' should be a flat value, not a dict")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_grading_json_valid_json(self, mock_setup):
        """grading.json must be parseable JSON."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="json-check",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        path = os.path.join(
            self.results_dir, "evals", "json-check", "trial-1", "grading.json"
        )
        with open(path) as f:
            data = json.load(f)
        self.assertIsInstance(data, dict)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_trial_number_matches_directory_name(self, mock_setup):
        """Trial number in grading.json must match the trial-N directory."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="dir-match",
                                      fixture_path=self.fixture_dir)
        for t in [1, 2, 3]:
            run_single_eval(case, trial_num=t, results_dir=self.results_dir,
                            runner=self.runner)
            grading = _read_grading_json(self.results_dir, "dir-match", t)
            self.assertEqual(grading["trial"], t)


# ===========================================================================
# AC-15: Aggregate results and write benchmark.json
# ===========================================================================

class TestAggregation(unittest.TestCase):
    """AC-15: run_eval_suite calls aggregate_results() and writes benchmark.json."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_run_eval_suite_writes_benchmark_json(self, mock_setup):
        """benchmark.json must exist in results_dir after run_eval_suite."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="bench-test",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1)
        benchmark_path = os.path.join(results_dir, "benchmark.json")
        self.assertTrue(os.path.exists(benchmark_path),
                        "benchmark.json should exist in results_dir")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_benchmark_json_is_valid_json(self, mock_setup):
        """benchmark.json must be parseable."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="bench-valid",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1)
        benchmark_path = os.path.join(results_dir, "benchmark.json")
        with open(benchmark_path) as f:
            data = json.load(f)
        self.assertIsInstance(data, dict)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_benchmark_json_has_metadata(self, mock_setup):
        """benchmark.json must contain metadata with timestamp and evals_run."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="bench-meta",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1)
        benchmark_path = os.path.join(results_dir, "benchmark.json")
        with open(benchmark_path) as f:
            data = json.load(f)
        self.assertIn("metadata", data)
        self.assertIn("evals_run", data["metadata"])

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_run_eval_suite_returns_results_dir_path(self, mock_setup):
        """run_eval_suite must return the results_dir path as a string."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1)
        self.assertIsInstance(results_dir, str)
        self.assertTrue(os.path.isdir(results_dir))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_multiple_evals_all_appear_in_benchmark(self, mock_setup):
        """benchmark.json covers all evals from the suite, not just the last one."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        cases = [
            _make_skill_eval_case(eval_id="eval-A", fixture_path=self.fixture_dir),
            _make_skill_eval_case(eval_id="eval-B", fixture_path=self.fixture_dir),
        ]
        suite_path = _make_suite_json(self.tmpdir, cases)
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1)
        benchmark_path = os.path.join(results_dir, "benchmark.json")
        with open(benchmark_path) as f:
            data = json.load(f)
        self.assertGreaterEqual(data["metadata"]["evals_run"], 2)


# ===========================================================================
# AC-17: On skill timeout/failure, still grades and writes results
# ===========================================================================

class TestFailureStillGrades(unittest.TestCase):
    """AC-17: Skill timeout or failure does not skip grading."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_nonzero_exit_still_writes_grading(self, mock_setup):
        """Skill exit code != 0 should still produce grading.json."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner(result=_make_run_result(exit_code=1))
        case = _make_skill_eval_case(eval_id="fail-grade",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        path = os.path.join(
            self.results_dir, "evals", "fail-grade", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_timeout_exception_still_writes_grading(self, mock_setup):
        """If runner raises a timeout exception, grading.json must still be written."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner(side_effect=[
            subprocess.TimeoutExpired(cmd="claude", timeout=300)
        ])
        case = _make_skill_eval_case(eval_id="timeout-grade",
                                      fixture_path=self.fixture_dir)
        # Should NOT raise
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        path = os.path.join(
            self.results_dir, "evals", "timeout-grade", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_timeout_grading_has_required_fields(self, mock_setup):
        """Even on timeout, grading.json has eval_id, trial, pass_rate, duration_ms."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner(side_effect=[
            subprocess.TimeoutExpired(cmd="claude", timeout=300)
        ])
        case = _make_skill_eval_case(eval_id="timeout-fields",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        grading = _read_grading_json(self.results_dir, "timeout-fields", 1)
        self.assertIn("eval_id", grading)
        self.assertIn("trial", grading)
        self.assertIn("pass_rate", grading)
        self.assertIn("duration_ms", grading)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_runtime_error_still_writes_grading(self, mock_setup):
        """If runner raises RuntimeError, grading must still be produced."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner(side_effect=[RuntimeError("Skill crashed")])
        case = _make_skill_eval_case(eval_id="crash-grade",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        path = os.path.join(
            self.results_dir, "evals", "crash-grade", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(path))


# ===========================================================================
# AC-18: On setup failure, writes error grading.json with pass_rate: 0.0
# ===========================================================================

class TestSetupFailureErrorGrading(unittest.TestCase):
    """AC-18: Setup failure writes error grading.json with pass_rate: 0.0."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_setup_failure_writes_grading_json(self, mock_setup):
        """If setup_fixture raises, grading.json is still written."""
        mock_setup.side_effect = FileNotFoundError("Fixture not found")
        case = _make_skill_eval_case(eval_id="setup-fail")
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        path = os.path.join(
            self.results_dir, "evals", "setup-fail", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_setup_failure_pass_rate_zero(self, mock_setup):
        """Setup failure grading must have pass_rate: 0.0."""
        mock_setup.side_effect = FileNotFoundError("Fixture not found")
        case = _make_skill_eval_case(eval_id="setup-zero")
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "setup-zero", 1)
        self.assertEqual(grading["pass_rate"], 0.0)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_setup_failure_has_eval_id(self, mock_setup):
        """Error grading.json must still include eval_id."""
        mock_setup.side_effect = FileNotFoundError("Bad fixture")
        case = _make_skill_eval_case(eval_id="setup-id")
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "setup-id", 1)
        self.assertEqual(grading["eval_id"], "setup-id")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_setup_failure_has_trial(self, mock_setup):
        """Error grading.json must include trial number."""
        mock_setup.side_effect = RuntimeError("Clone failed")
        case = _make_skill_eval_case(eval_id="setup-trial")
        run_single_eval(case, trial_num=2, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "setup-trial", 2)
        self.assertEqual(grading["trial"], 2)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_setup_failure_does_not_call_runner(self, mock_setup):
        """If setup fails, runner should never be called."""
        mock_setup.side_effect = FileNotFoundError("Missing")
        case = _make_skill_eval_case(eval_id="no-run")
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        self.assertEqual(len(self.runner.calls), 0)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_setup_failure_has_duration_ms(self, mock_setup):
        """Error grading must still have a duration_ms field."""
        mock_setup.side_effect = FileNotFoundError("Missing")
        case = _make_skill_eval_case(eval_id="setup-dur")
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        grading = _read_grading_json(self.results_dir, "setup-dur", 1)
        self.assertIn("duration_ms", grading)
        self.assertIsInstance(grading["duration_ms"], (int, float))


# ===========================================================================
# AC-19: Prints progress to stderr
# ===========================================================================

class TestProgressOutput(unittest.TestCase):
    """AC-19: run_single_eval and run_eval_suite print progress to stderr."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)
        self.runner = MockRunner()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("sys.stderr")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_progress_printed_to_stderr(self, mock_setup, mock_stderr):
        """At least one message must be written to stderr during eval run."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="progress-test",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        self.assertTrue(mock_stderr.write.called,
                        "Progress must be written to stderr")

    @patch("sys.stderr")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_progress_includes_eval_id(self, mock_setup, mock_stderr):
        """Progress output should mention the eval ID being run."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="stderr-id-test",
                                      fixture_path=self.fixture_dir)
        run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                        runner=self.runner)
        all_writes = "".join(
            str(c) for c in mock_stderr.write.call_args_list
        )
        self.assertIn("stderr-id-test", all_writes)


# ===========================================================================
# run_eval_suite: suite loading, iteration, filtering
# ===========================================================================

class TestRunEvalSuiteLoading(unittest.TestCase):
    """run_eval_suite loads evals.json and iterates cases x trials."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_loads_evals_json_from_suite_path(self, mock_setup):
        """run_eval_suite must read the evals.json at suite_path."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="load-test",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1)
        # Should have created grading for the eval
        grading_path = os.path.join(
            results_dir, "evals", "load-test", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(grading_path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_runs_correct_number_of_trials(self, mock_setup):
        """run_eval_suite creates trial-1..trial-N for each eval."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="trials-test",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=3)
        for t in [1, 2, 3]:
            path = os.path.join(
                results_dir, "evals", "trials-test", f"trial-{t}", "grading.json"
            )
            self.assertTrue(os.path.exists(path),
                            f"trial-{t}/grading.json should exist")
        # trial-4 should NOT exist
        path = os.path.join(
            results_dir, "evals", "trials-test", "trial-4", "grading.json"
        )
        self.assertFalse(os.path.exists(path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_case_filter_runs_only_matching(self, mock_setup):
        """case_filter limits execution to the specified eval ID."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        cases = [
            _make_skill_eval_case(eval_id="run-me", fixture_path=self.fixture_dir),
            _make_skill_eval_case(eval_id="skip-me", fixture_path=self.fixture_dir),
        ]
        suite_path = _make_suite_json(self.tmpdir, cases)
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1,
                                          case_filter="run-me")
        run_path = os.path.join(
            results_dir, "evals", "run-me", "trial-1", "grading.json"
        )
        skip_path = os.path.join(
            results_dir, "evals", "skip-me", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(run_path))
        self.assertFalse(os.path.exists(skip_path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_dry_run_does_not_execute(self, mock_setup):
        """dry_run=True should not call setup_fixture or runner."""
        case = _make_skill_eval_case(eval_id="dry-run-test",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            run_eval_suite(suite_path, trials=1, dry_run=True)
        mock_setup.assert_not_called()

    @patch("sys.stderr")
    @patch("evals.framework.orchestrator.setup_fixture")
    def test_dry_run_prints_case_ids_to_stderr(self, mock_setup, mock_stderr):
        """dry_run should print case IDs to stderr without executing."""
        cases = [
            _make_skill_eval_case(eval_id="dry-A", fixture_path=self.fixture_dir),
            _make_skill_eval_case(eval_id="dry-B", fixture_path=self.fixture_dir),
        ]
        suite_path = _make_suite_json(self.tmpdir, cases)
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            run_eval_suite(suite_path, trials=1, dry_run=True)
        all_writes = "".join(str(c) for c in mock_stderr.write.call_args_list)
        self.assertIn("dry-A", all_writes)
        self.assertIn("dry-B", all_writes)


# ===========================================================================
# CLI: __main__.py entry point
# ===========================================================================

class TestCLISuiteFlag(unittest.TestCase):
    """CLI AC-1: --suite loads correct JSON and writes to results dir."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_suite_flag_triggers_run(self, mock_setup):
        """python -m evals --suite <path> should run the suite."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="cli-suite",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            with patch("evals.framework.orchestrator.run_eval_suite",
                        wraps=run_eval_suite) as mock_run:
                with patch("sys.argv", ["evals", "--suite", suite_path]):
                    from evals.__main__ import main
                    main()
                mock_run.assert_called_once()
                call_args = mock_run.call_args
                self.assertEqual(call_args[0][0], suite_path)


class TestCLICaseFilter(unittest.TestCase):
    """CLI AC-2: --case filters to single case, invalid ID exits non-zero."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_invalid_case_exits_nonzero(self):
        """--case with non-existent ID should exit non-zero."""
        case = _make_skill_eval_case(eval_id="real-case",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            with patch("sys.argv", ["evals", "--suite", suite_path,
                                     "--case", "nonexistent-id"]):
                from evals.__main__ import main
                with self.assertRaises(SystemExit) as ctx:
                    main()
                self.assertNotEqual(ctx.exception.code, 0)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_valid_case_filter_passed_through(self, mock_setup):
        """--case with valid ID should pass case_filter to run_eval_suite."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        case = _make_skill_eval_case(eval_id="filter-me",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            with patch("evals.framework.orchestrator.run_eval_suite") as mock_run:
                mock_run.return_value = self.tmpdir
                with patch("sys.argv", ["evals", "--suite", suite_path,
                                         "--case", "filter-me"]):
                    from evals.__main__ import main
                    main()
                call_kwargs = mock_run.call_args[1] if mock_run.call_args[1] else {}
                call_args = mock_run.call_args[0] if mock_run.call_args[0] else ()
                # case_filter should be "filter-me" — check args or kwargs
                all_values = list(call_args) + list(call_kwargs.values())
                self.assertIn("filter-me", all_values)


class TestCLITrials(unittest.TestCase):
    """CLI AC-3: --trials N creates trial-1..trial-N directories."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_trials_flag_passed_through(self):
        """--trials 5 should pass trials=5 to run_eval_suite."""
        case = _make_skill_eval_case(eval_id="trial-cli",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            with patch("evals.framework.orchestrator.run_eval_suite") as mock_run:
                mock_run.return_value = self.tmpdir
                with patch("sys.argv", ["evals", "--suite", suite_path,
                                         "--trials", "5"]):
                    from evals.__main__ import main
                    main()
                call_kwargs = mock_run.call_args[1] if mock_run.call_args[1] else {}
                call_args = mock_run.call_args[0] if mock_run.call_args[0] else ()
                all_values = list(call_args) + list(call_kwargs.values())
                self.assertIn(5, all_values)


class TestCLIDryRun(unittest.TestCase):
    """CLI AC-6: --dry-run prints cases without running."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_dry_run_flag_passed_through(self):
        """--dry-run should pass dry_run=True to run_eval_suite."""
        case = _make_skill_eval_case(eval_id="dry-cli",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            with patch("evals.framework.orchestrator.run_eval_suite") as mock_run:
                mock_run.return_value = self.tmpdir
                with patch("sys.argv", ["evals", "--suite", suite_path,
                                         "--dry-run"]):
                    from evals.__main__ import main
                    main()
                call_kwargs = mock_run.call_args[1] if mock_run.call_args[1] else {}
                self.assertTrue(
                    call_kwargs.get("dry_run", False) is True
                    or (len(mock_run.call_args[0]) > 3 and
                        mock_run.call_args[0][3] is True),
                    "dry_run=True must be passed to run_eval_suite"
                )


class TestCLITimeout(unittest.TestCase):
    """CLI AC-7: --timeout passed through."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_timeout_flag_passed_through(self):
        """--timeout 600 should pass timeout=600 to run_eval_suite."""
        case = _make_skill_eval_case(eval_id="timeout-cli",
                                      fixture_path=self.fixture_dir)
        suite_path = _make_suite_json(self.tmpdir, [case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            with patch("evals.framework.orchestrator.run_eval_suite") as mock_run:
                mock_run.return_value = self.tmpdir
                with patch("sys.argv", ["evals", "--suite", suite_path,
                                         "--timeout", "600"]):
                    from evals.__main__ import main
                    main()
                call_kwargs = mock_run.call_args[1] if mock_run.call_args[1] else {}
                call_args = mock_run.call_args[0] if mock_run.call_args[0] else ()
                all_values = list(call_args) + list(call_kwargs.values())
                self.assertIn(600, all_values)


# ===========================================================================
# Cross-cutting: anti-hardcoding and multi-case correctness
# ===========================================================================

class TestAntiHardcoding(unittest.TestCase):
    """Prevent hardcoded returns by varying inputs and verifying distinct outputs."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_different_eval_ids_produce_different_output_dirs(self, mock_setup):
        """Each eval ID produces its own subdirectory, not a shared one."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner()
        for eid in ["alpha", "beta", "gamma"]:
            case = _make_skill_eval_case(eval_id=eid,
                                          fixture_path=self.fixture_dir)
            run_single_eval(case, trial_num=1, results_dir=self.results_dir,
                            runner=runner)
        for eid in ["alpha", "beta", "gamma"]:
            path = os.path.join(
                self.results_dir, "evals", eid, "trial-1", "grading.json"
            )
            self.assertTrue(os.path.exists(path), f"Expected dir for {eid}")
            grading = json.load(open(path))
            self.assertEqual(grading["eval_id"], eid,
                             "eval_id in grading must match the case")

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_different_trials_have_different_trial_numbers(self, mock_setup):
        """Each trial produces grading with the correct trial number, not always 1."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner()
        case = _make_skill_eval_case(eval_id="multi-trial",
                                      fixture_path=self.fixture_dir)
        for t in [1, 2, 3]:
            run_single_eval(case, trial_num=t, results_dir=self.results_dir,
                            runner=runner)
        for t in [1, 2, 3]:
            grading = _read_grading_json(self.results_dir, "multi-trial", t)
            self.assertEqual(grading["trial"], t)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_prompt_varies_with_template_and_args(self, mock_setup):
        """Different prompt_template/args combos produce different prompts."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        runner = MockRunner()
        case_init = _make_skill_eval_case(eval_id="init-p",
                                           fixture_path=self.fixture_dir)
        case_init["prompt_template"] = "init"
        case_init["prompt_args"] = {"project_type": "rust"}
        case_init["skill"] = "sw-init"

        case_build = _make_skill_eval_case(eval_id="build-p",
                                            fixture_path=self.fixture_dir)
        case_build["prompt_template"] = "build"
        case_build["prompt_args"] = {}
        case_build["skill"] = "sw-build"

        run_single_eval(case_init, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        run_single_eval(case_build, trial_num=1, results_dir=self.results_dir,
                        runner=runner)
        prompt_init = runner.calls[0]["prompt"]
        prompt_build = runner.calls[1]["prompt"]
        self.assertNotEqual(prompt_init, prompt_build,
                            "Different templates must produce different prompts")
        self.assertIn("rust", prompt_init)
        self.assertIn("/sw-build", prompt_build)


# ===========================================================================
# Unit 02b-1: smoke filter and baseline CLI
# ===========================================================================

class TestSmokeFilter(unittest.TestCase):
    """AC-4, AC-5: --smoke-only filters to entries with smoke: true.

    Validates the field via validate_suite (AC-4) and the runtime filter
    via run_eval_suite (AC-5)."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.fixture_dir = _make_fixture_dir(self.tmpdir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_smoke_only_runs_only_smoke_tagged_entries(self, mock_setup):
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        smoke_case = _make_skill_eval_case(
            eval_id="smoke-yes", fixture_path=self.fixture_dir
        )
        smoke_case["smoke"] = True
        non_smoke_case = _make_skill_eval_case(
            eval_id="smoke-no", fixture_path=self.fixture_dir
        )
        non_smoke_case["smoke"] = False
        unset_case = _make_skill_eval_case(
            eval_id="smoke-unset", fixture_path=self.fixture_dir
        )
        suite_path = _make_suite_json(
            self.tmpdir, [smoke_case, non_smoke_case, unset_case]
        )
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1, smoke_only=True)

        smoke_yes_path = os.path.join(
            results_dir, "evals", "smoke-yes", "trial-1", "grading.json"
        )
        smoke_no_path = os.path.join(
            results_dir, "evals", "smoke-no", "trial-1", "grading.json"
        )
        unset_path = os.path.join(
            results_dir, "evals", "smoke-unset", "trial-1", "grading.json"
        )
        self.assertTrue(os.path.exists(smoke_yes_path))
        self.assertFalse(os.path.exists(smoke_no_path))
        self.assertFalse(os.path.exists(unset_path))

    @patch("evals.framework.orchestrator.setup_fixture")
    def test_smoke_only_false_runs_all_entries(self, mock_setup):
        """When smoke_only=False (default), all entries run regardless of tag."""
        mock_setup.side_effect = lambda src, dst: shutil.copytree(
            self.fixture_dir, dst
        )
        smoke_case = _make_skill_eval_case(
            eval_id="entry-1", fixture_path=self.fixture_dir
        )
        smoke_case["smoke"] = True
        non_smoke_case = _make_skill_eval_case(
            eval_id="entry-2", fixture_path=self.fixture_dir
        )
        suite_path = _make_suite_json(self.tmpdir, [smoke_case, non_smoke_case])
        with patch("evals.framework.orchestrator.ClaudeCodeRunner") as MockCCR:
            MockCCR.return_value = MockRunner()
            results_dir = run_eval_suite(suite_path, trials=1, smoke_only=False)
        for eval_id in ("entry-1", "entry-2"):
            path = os.path.join(
                results_dir, "evals", eval_id, "trial-1", "grading.json"
            )
            self.assertTrue(os.path.exists(path), f"{eval_id} should have run")

    def test_validate_suite_accepts_boolean_smoke_field(self):
        from evals.framework.orchestrator import validate_suite
        case = _make_skill_eval_case(eval_id="ok", fixture_path=self.fixture_dir)
        case["smoke"] = True
        suite_path = _make_suite_json(self.tmpdir, [case])
        errors = validate_suite(suite_path)
        self.assertEqual(errors, [])

    def test_validate_suite_accepts_missing_smoke_field(self):
        from evals.framework.orchestrator import validate_suite
        case = _make_skill_eval_case(eval_id="ok", fixture_path=self.fixture_dir)
        # No smoke field at all
        suite_path = _make_suite_json(self.tmpdir, [case])
        errors = validate_suite(suite_path)
        self.assertEqual(errors, [])

    def test_validate_suite_rejects_non_boolean_smoke_field(self):
        from evals.framework.orchestrator import validate_suite
        case = _make_skill_eval_case(eval_id="bad", fixture_path=self.fixture_dir)
        case["smoke"] = "true"  # string, not bool
        suite_path = _make_suite_json(self.tmpdir, [case])
        errors = validate_suite(suite_path)
        self.assertTrue(len(errors) >= 1)
        self.assertTrue(any("smoke" in e for e in errors))


class TestBaselineCLI(unittest.TestCase):
    """AC-3, AC-10, AC-11, AC-12, AC-13: baseline CLI flags."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.baselines_dir = os.path.join(self.tmpdir, "baselines")
        os.makedirs(self.baselines_dir, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _write_valid_baseline(self, suite="skill"):
        from evals.framework.baseline import BaselineFile, write_baseline
        b = BaselineFile(
            suite=suite,
            generated_at="2026-04-08T12:00:00Z",
            generated_from_commit="abc1234",
            tolerances={
                "pass_rate_delta": 0.0,
                "duration_multiplier": 1.25,
                "tokens_multiplier": 1.20,
            },
            evals={
                "eval-01": {
                    "pass_rate": 1.0,
                    "duration_ms": 30000,
                    "tokens": {
                        "input_tokens": 10000,
                        "output_tokens": 2000,
                        "cache_creation_input_tokens": 0,
                        "cache_read_input_tokens": 0,
                    },
                },
            },
        )
        path = os.path.join(self.baselines_dir, f"{suite}.json")
        write_baseline(b, path)
        return path

    def test_validate_baselines_dir_returns_empty_findings_for_valid_dir(self):
        self._write_valid_baseline("skill")
        from evals.framework.baseline import validate_baselines_dir
        findings = validate_baselines_dir(self.baselines_dir)
        self.assertIn("skill.json", findings)
        self.assertEqual(findings["skill.json"], [])

    def test_validate_baselines_dir_skips_schema_json(self):
        """schema.json (the JSON Schema document) is NOT a baseline file."""
        with open(os.path.join(self.baselines_dir, "schema.json"), "w") as f:
            f.write('{"$schema": "http://json-schema.org/draft-07/schema#"}')
        self._write_valid_baseline("skill")
        from evals.framework.baseline import validate_baselines_dir
        findings = validate_baselines_dir(self.baselines_dir)
        self.assertNotIn("schema.json", findings)
        self.assertIn("skill.json", findings)

    def test_validate_baselines_dir_missing_directory_returns_empty(self):
        from evals.framework.baseline import validate_baselines_dir
        findings = validate_baselines_dir(os.path.join(self.tmpdir, "nope"))
        self.assertEqual(findings, {})


class TestStructuralEvalCases(unittest.TestCase):
    """AC-1, AC-2, AC-3, AC-11: structural eval validation + execution."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.results_dir = os.path.join(self.tmpdir, "results")
        os.makedirs(self.results_dir, exist_ok=True)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_validate_suite_accepts_structural_case_with_command(self):
        from evals.framework.orchestrator import validate_suite

        suite_path = _make_suite_json(self.tmpdir, [_make_structural_eval_case()])
        errors = validate_suite(suite_path)
        self.assertEqual(errors, [])

    def test_validate_suite_rejects_structural_case_missing_command(self):
        from evals.framework.orchestrator import validate_suite

        case = _make_structural_eval_case()
        del case["command"]
        suite_path = _make_suite_json(self.tmpdir, [case])
        errors = validate_suite(suite_path)
        self.assertTrue(any("command" in err for err in errors), errors)

    def test_validate_suite_rejects_structural_case_with_expectations(self):
        from evals.framework.orchestrator import validate_suite

        case = _make_structural_eval_case()
        case["expectations"] = [{"type": "file_exists", "path": "README.md"}]
        suite_path = _make_suite_json(self.tmpdir, [case])
        errors = validate_suite(suite_path)
        self.assertTrue(any("expectations" in err for err in errors), errors)

    def test_validate_suite_rejects_invalid_type_value(self):
        from evals.framework.orchestrator import validate_suite

        case = _make_skill_eval_case(fixture_path=_make_fixture_dir(self.tmpdir))
        case["type"] = "not-a-real-type"
        suite_path = _make_suite_json(self.tmpdir, [case])
        errors = validate_suite(suite_path)
        self.assertTrue(any("type" in err for err in errors), errors)

    @patch("subprocess.run")
    def test_run_single_eval_structural_success_writes_passing_grading_json(
        self, mock_run
    ):
        import evals.framework.orchestrator as orchestrator

        mock_run.return_value = subprocess.CompletedProcess(
            args=["python", "-c", "print('ok')"],
            returncode=0,
            stdout="ok\n",
            stderr="",
        )
        case = _make_structural_eval_case(eval_id="struct-ok")
        runner = MockRunner()

        run_single_eval(
            case,
            trial_num=1,
            results_dir=self.results_dir,
            runner=runner,
        )

        grading = _read_grading_json(self.results_dir, "struct-ok", 1)
        self.assertEqual(len(runner.calls), 0, "structural evals must not use skill runner")
        self.assertEqual(grading["pass_rate"], 1.0)
        self.assertEqual(grading["execution"]["exit_code"], 0)
        self.assertIn("ok", json.dumps(grading))
        self.assertEqual(
            mock_run.call_args.kwargs["cwd"],
            os.path.dirname(orchestrator._EVALS_BASE_DIR),
        )
        self.assertFalse(mock_run.call_args.kwargs.get("shell", False))

    @patch("subprocess.run")
    def test_run_single_eval_structural_failure_records_exit_detail(self, mock_run):
        mock_run.return_value = subprocess.CompletedProcess(
            args=["python", "-c", "raise SystemExit(3)"],
            returncode=3,
            stdout="",
            stderr="boom\n",
        )
        case = _make_structural_eval_case(eval_id="struct-fail")

        run_single_eval(
            case,
            trial_num=1,
            results_dir=self.results_dir,
            runner=MockRunner(),
        )

        grading = _read_grading_json(self.results_dir, "struct-fail", 1)
        self.assertEqual(grading["pass_rate"], 0.0)
        self.assertEqual(grading["execution"]["exit_code"], 3)
        self.assertIn("boom", json.dumps(grading))

    @patch("subprocess.run")
    def test_run_single_eval_structural_timeout_records_partial_output(self, mock_run):
        timeout_exc = subprocess.TimeoutExpired(
            cmd=["python", "-c", "print('slow')"],
            timeout=30,
            output="partial stdout\n",
            stderr="partial stderr\n",
        )
        mock_run.side_effect = timeout_exc
        case = _make_structural_eval_case(eval_id="struct-timeout")

        run_single_eval(
            case,
            trial_num=1,
            results_dir=self.results_dir,
            runner=MockRunner(),
        )

        grading = _read_grading_json(self.results_dir, "struct-timeout", 1)
        self.assertEqual(grading["pass_rate"], 0.0)
        self.assertEqual(grading["execution"]["exit_code"], 124)
        self.assertIn("TimeoutExpired", grading["error"])
        self.assertEqual(grading["execution"]["stdout"], "partial stdout\n")
        self.assertEqual(grading["execution"]["stderr"], "partial stderr\n")


if __name__ == "__main__":
    unittest.main()
