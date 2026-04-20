"""Contract tests for Unit 02 - runtime mode config and path model.

Task 1 starts with the tracked config and context protocol surface. Later tasks
extend this module with resolver and migration-safety proofs.
"""

import json
import os
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_CONFIG_PATH = os.path.join(_REPO_ROOT, ".specwright", "config.json")
_CONTEXT_PROTOCOL_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "context.md")


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


class TestRuntimeModeConfigDefaults(unittest.TestCase):
    """AC-1: tracked config defines runtime mode without changing artifact mode."""

    def setUp(self):
        self.config = _load_json(_CONFIG_PATH)
        self.git_config = self.config["git"]

    def test_git_config_has_runtime_block(self):
        self.assertIn(
            "runtime",
            self.git_config,
            "config.git must define a runtime block",
        )

    def test_runtime_block_has_required_keys(self):
        runtime = self.git_config["runtime"]
        expected_keys = {"mode", "projectVisibleRoot"}
        self.assertTrue(
            expected_keys.issubset(runtime.keys()),
            f"runtime block missing keys: {sorted(expected_keys - set(runtime.keys()))}",
        )

    def test_runtime_mode_defaults_to_git_admin(self):
        self.assertEqual(
            self.git_config["runtime"]["mode"],
            "git-admin",
            "existing installs should stay on git-admin until they opt in",
        )

    def test_project_visible_root_defaults_to_dot_specwright_local(self):
        self.assertEqual(
            self.git_config["runtime"]["projectVisibleRoot"],
            ".specwright-local",
        )

    def test_work_artifacts_block_remains_separate_from_runtime_block(self):
        self.assertIn("workArtifacts", self.git_config)
        self.assertIn("runtime", self.git_config)
        self.assertIsInstance(self.git_config["workArtifacts"], dict)
        self.assertIsInstance(self.git_config["runtime"], dict)


class TestRuntimeModeContextProtocol(unittest.TestCase):
    """AC-1: context protocol documents the runtime-mode vocabulary and split."""

    def setUp(self):
        self.content = load_text(_CONTEXT_PROTOCOL_PATH)
        self.lower = self.content.lower()

    def test_protocol_mentions_runtime_mode_keys(self):
        self.assertIn("git.runtime.mode", self.content)
        self.assertIn("git.runtime.projectVisibleRoot", self.content)

    def test_protocol_names_both_runtime_modes(self):
        self.assertIn("git-admin", self.lower)
        self.assertIn("project-visible", self.lower)

    def test_project_visible_root_is_described_as_git_common_dir_parent_relative(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"project-visible.{0,200}git common-dir parent|git common-dir parent.{0,200}project-visible",
        )

    def test_protocol_describes_project_visible_runtime_split(self):
        for needle in (
            "repoStateRoot",
            "worktreeStateRoot",
            "workArtifactsRoot",
            ".specwright-local",
        ):
            with self.subTest(needle=needle):
                self.assertIn(needle, self.content)

        assert_multiline_regex(
            self,
            self.lower,
            r"project-visible.{0,240}repo state root.{0,120}worktree state root.{0,120}work artifacts root",
        )

    def test_work_artifact_publication_remains_independent(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"work-artifact publication.+separate.+runtime mode|runtime mode.+separate.+work-artifact publication",
        )


if __name__ == "__main__":
    unittest.main()
