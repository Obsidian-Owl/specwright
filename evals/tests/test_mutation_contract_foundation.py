"""Tests for WU-01 Task 1: mutation config defaults and detection vocabulary.

RED phase: these tests must fail until `.specwright/config.json` defines the
mutation block and `core/protocols/guardrails-detection.md` documents the
supported mutation tools and three detection states.
"""

import json
import os
import re
import unittest


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_CONFIG_PATH = os.path.join(_REPO_ROOT, ".specwright", "config.json")
_DETECTION_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "guardrails-detection.md")


def _load_json(path):
    with open(path, "r") as f:
        return json.load(f)


def _load_text(path):
    with open(path, "r") as f:
        return f.read()


class TestMutationConfigExists(unittest.TestCase):
    """AC-1: config exposes the mutation block under gates.tests."""

    def setUp(self):
        self.config = _load_json(_CONFIG_PATH)

    def test_tests_gate_has_mutation_block(self):
        tests_config = self.config["gates"]["tests"]
        self.assertIn(
            "mutation",
            tests_config,
            "config.gates.tests must define a mutation block",
        )

    def test_mutation_block_has_required_top_level_keys(self):
        mutation = self.config["gates"]["tests"]["mutation"]
        expected_keys = {
            "mode",
            "detectedTool",
            "explicitTool",
            "thresholds",
            "timeoutSeconds",
            "llmFallback",
            "equivalentTriage",
            "nondeterminism",
            "acceptedMutants",
        }
        self.assertTrue(
            expected_keys.issubset(mutation.keys()),
            f"mutation block missing keys: {sorted(expected_keys - set(mutation.keys()))}",
        )


class TestMutationConfigDefaults(unittest.TestCase):
    """AC-1: mutation defaults match the approved design."""

    def setUp(self):
        self.mutation = _load_json(_CONFIG_PATH)["gates"]["tests"]["mutation"]

    def test_mode_defaults_to_auto(self):
        self.assertEqual(self.mutation["mode"], "auto")

    def test_thresholds_default_to_50_65_80(self):
        self.assertEqual(
            self.mutation["thresholds"],
            {"break": 50, "low": 65, "high": 80},
        )

    def test_timeout_defaults_to_600_seconds(self):
        self.assertEqual(self.mutation["timeoutSeconds"], 600)

    def test_llm_fallback_defaults_to_auto_on_zero_mutants(self):
        self.assertEqual(self.mutation["llmFallback"]["mode"], "auto-on-zero-mutants")

    def test_llm_fallback_redacts_secrets(self):
        self.assertIs(self.mutation["llmFallback"]["redactSecrets"], True)

    def test_nondeterminism_defaults_pin_seed(self):
        nondeterminism = self.mutation["nondeterminism"]
        self.assertIs(nondeterminism["pinSeed"], True)
        self.assertIn("seed", nondeterminism)


class TestMutationDetectionProtocol(unittest.TestCase):
    """AC-2 + AC-6: detection protocol names supported tools and states."""

    def setUp(self):
        self.content = _load_text(_DETECTION_PATH)
        self.lower = self.content.lower()

    def test_lists_supported_mutation_tools(self):
        for tool in (
            "pit",
            "stryker",
            "cargo-mutants",
            "mutmut",
            "infection",
            "gremlins",
            "gomu",
        ):
            with self.subTest(tool=tool):
                self.assertIn(tool, self.lower)

    def test_mentions_configured_state(self):
        self.assertRegex(
            self.lower,
            r"(installed|tool).{0,40}(config|configured).{0,80}(t1|tool-backed|mutation)",
        )

    def test_mentions_installed_but_unconfigured_state(self):
        self.assertRegex(
            self.lower,
            r"(installed|binary).{0,80}(no config|unconfigured|without config)",
        )

    def test_mentions_absent_state(self):
        self.assertRegex(
            self.lower,
            r"(no tool|tool absent|neither present|not installed)",
        )

    def test_distinguishes_three_states_in_one_detection_flow(self):
        patterns = [
            r"(installed|tool).{0,40}(config|configured)",
            r"(installed|binary).{0,80}(no config|unconfigured|without config)",
            r"(no tool|tool absent|neither present|not installed)",
        ]
        for pattern in patterns:
            self.assertRegex(self.lower, pattern)


if __name__ == "__main__":
    unittest.main()
