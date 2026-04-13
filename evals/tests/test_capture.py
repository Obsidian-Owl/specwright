"""Tests for evals.framework.capture — state snapshots and timing.

AC-9: capture_snapshot() copies .specwright/ and outputs JSON manifest
AC-10: capture_timing() writes timing.json from RunResult
"""

import json
import os
import shutil
import subprocess
import tempfile
import unittest

from evals.framework.capture import capture_snapshot, capture_timing
from evals.framework.git_env import sanitized_git_env


class TestCaptureSnapshotBasic(unittest.TestCase):
    """AC-9: capture_snapshot produces a manifest with expected fields."""

    def _run_git(self, args):
        subprocess.run(
            ["git", *args],
            cwd=self.workdir,
            check=True,
            capture_output=True,
            env=sanitized_git_env(),
        )

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        self.output_dir = tempfile.mkdtemp()
        # Create .specwright/ structure
        sw_dir = os.path.join(self.workdir, ".specwright", "state")
        os.makedirs(sw_dir)
        work_dir = os.path.join(self.workdir, ".specwright", "work", "test-work")
        os.makedirs(work_dir)
        # Write workflow.json
        workflow = {"version": "2.0", "currentWork": {"status": "building"}}
        with open(os.path.join(sw_dir, "workflow.json"), "w") as f:
            json.dump(workflow, f)
        # Write a dummy artifact
        with open(os.path.join(work_dir, "spec.md"), "w") as f:
            f.write("# Spec")
        # Init git repo for git status
        self._run_git(["init", "-q"])
        self._run_git(["config", "user.name", "Eval Test"])
        self._run_git(["config", "user.email", "evals@example.com"])
        # Stage specific files (not git add -A per constitution)
        self._run_git(
            ["add",
             os.path.join(".specwright", "state", "workflow.json"),
             os.path.join(".specwright", "work", "test-work", "spec.md")]
        )
        self._run_git(["commit", "-q", "-m", "init"])

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)
        shutil.rmtree(self.output_dir, ignore_errors=True)

    def test_returns_dict_with_workflow_state(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIn("workflow_state", manifest)
        self.assertEqual(manifest["workflow_state"]["currentWork"]["status"], "building")

    def test_returns_dict_with_artifacts_list(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIn("artifacts", manifest)
        self.assertIsInstance(manifest["artifacts"], list)
        self.assertTrue(any("spec.md" in a for a in manifest["artifacts"]))

    def test_returns_dict_with_git_status(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIn("git_status", manifest)
        self.assertIsInstance(manifest["git_status"], str)

    def test_returns_dict_with_timestamp(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIn("timestamp", manifest)
        self.assertIsInstance(manifest["timestamp"], str)

    def test_returns_dict_with_snapshot_dir(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIn("snapshot_dir", manifest)
        self.assertEqual(manifest["snapshot_dir"], self.output_dir)

    def test_copies_specwright_dir_to_output(self):
        capture_snapshot(self.workdir, self.output_dir)
        copied = os.path.join(self.output_dir, ".specwright")
        self.assertTrue(os.path.isdir(copied))


class TestCaptureSnapshotMissingSpecwright(unittest.TestCase):
    """AC-9: When .specwright/ doesn't exist, returns partial manifest."""

    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        self.output_dir = tempfile.mkdtemp()
        subprocess.run(
            ["git", "init", "-q"],
            cwd=self.workdir,
            check=True,
            capture_output=True,
            env=sanitized_git_env(),
        )

    def tearDown(self):
        shutil.rmtree(self.workdir, ignore_errors=True)
        shutil.rmtree(self.output_dir, ignore_errors=True)

    def test_workflow_state_is_none(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIsNone(manifest["workflow_state"])

    def test_artifacts_is_empty_list(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertEqual(manifest["artifacts"], [])

    def test_error_field_present(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertIn("error", manifest)

    def test_snapshot_dir_present_when_specwright_missing(self):
        manifest = capture_snapshot(self.workdir, self.output_dir)
        self.assertEqual(manifest["snapshot_dir"], self.output_dir)


class TestCaptureTimingBasic(unittest.TestCase):
    """AC-10: capture_timing writes timing.json from RunResult-like data."""

    def setUp(self):
        self.output_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.output_dir, ignore_errors=True)

    def test_writes_timing_json_file(self):
        run_result = _make_run_result(tokens={"input_tokens": 100}, duration_ms=500, exit_code=0)
        capture_timing(run_result, self.output_dir)
        path = os.path.join(self.output_dir, "timing.json")
        self.assertTrue(os.path.exists(path))

    def test_timing_json_contains_expected_fields(self):
        run_result = _make_run_result(tokens={"input_tokens": 100}, duration_ms=500, exit_code=0)
        capture_timing(run_result, self.output_dir)
        path = os.path.join(self.output_dir, "timing.json")
        with open(path) as f:
            data = json.load(f)
        self.assertEqual(data["tokens"], {"input_tokens": 100})
        self.assertEqual(data["duration_ms"], 500)
        self.assertEqual(data["exit_code"], 0)
        self.assertIn("timestamp", data)

    def test_handles_none_tokens(self):
        run_result = _make_run_result(tokens=None, duration_ms=None, exit_code=1)
        capture_timing(run_result, self.output_dir)
        path = os.path.join(self.output_dir, "timing.json")
        with open(path) as f:
            data = json.load(f)
        self.assertIsNone(data["tokens"])
        self.assertIsNone(data["duration_ms"])


def _make_run_result(tokens=None, duration_ms=None, exit_code=0):
    """Create a simple object with RunResult-like attributes."""
    class _FakeResult:
        pass
    r = _FakeResult()
    r.tokens = tokens
    r.duration_ms = duration_ms
    r.exit_code = exit_code
    return r


if __name__ == "__main__":
    unittest.main()
