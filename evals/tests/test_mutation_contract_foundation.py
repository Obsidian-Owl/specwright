"""Tests for WU-01 Task 1: mutation config defaults and detection vocabulary.

RED phase: these tests must fail until `.specwright/config.json` defines the
mutation block and `core/protocols/guardrails-detection.md` documents the
supported mutation tools and three detection states.
"""

import json
import os
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_CONFIG_PATH = os.path.join(_REPO_ROOT, ".specwright", "config.json")
_DETECTION_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "guardrails-detection.md")
_EVIDENCE_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "evidence.md")
_APPROVALS_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "approvals.md")
_BUILD_QUALITY_PATH = os.path.join(
    _REPO_ROOT, "core", "protocols", "build-quality.md"
)


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


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


class TestSemanticToolDefaults(unittest.TestCase):
    """Regression: tracked config must not bake author environment state."""

    def setUp(self):
        self.tools = _load_json(_CONFIG_PATH)["gates"]["semantic"]["tools"]

    def test_ast_grep_detection_defaults_to_neutral_state(self):
        self.assertIsNone(self.tools["ast-grep"]["detected"])


class TestMutationDetectionProtocol(unittest.TestCase):
    """AC-2 + AC-6: detection protocol names supported tools and states."""

    def setUp(self):
        self.content = load_text(_DETECTION_PATH)
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
        assert_multiline_regex(
            self,
            self.lower,
            r"(installed|tool).{0,40}(config|configured).{0,80}(t1|tool-backed|mutation)",
        )

    def test_mentions_installed_but_unconfigured_state(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"(installed|binary).{0,80}(no config|unconfigured|without config)",
        )

    def test_mentions_absent_state(self):
        assert_multiline_regex(
            self,
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
            assert_multiline_regex(self, self.lower, pattern)

    def test_t3_fallback_names_the_qualitative_bypass_classes(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"t3.{0,80}hardcoded returns.+partial implementations.+boundary skips",
        )


class TestMutationEvidenceProtocol(unittest.TestCase):
    """AC-3 + AC-6: evidence protocol documents tiered mutation disclosures."""

    def setUp(self):
        self.content = load_text(_EVIDENCE_PATH)
        self.lower = self.content.lower()

    def test_removes_r2_not_implemented_carve_out(self):
        self.assertNotIn("r2 is not implemented", self.lower)

    def test_documents_tier_aware_escalation_signal(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"mutation resistance.+50%\+ of test files.+t1/t2.+2\+\s+bypass classes.+t3",
        )

    def test_requires_mutation_evidence_to_disclose_the_tier(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"mutation evidence.+disclose.+tier",
        )

    def test_t2_disclosure_notes_redaction_without_secret_values(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"t2.+redact.+without.+reveal.+secret",
        )

    def test_t3_definition_names_preserved_bypass_classes(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"t3.+hardcoded returns.+partial.+implementations.+boundary skips",
        )


class TestMutationApprovalProtocol(unittest.TestCase):
    """AC-4 + AC-6: approvals protocol captures accepted-mutant lineage."""

    def setUp(self):
        self.content = load_text(_APPROVALS_PATH)
        self.lower = self.content.lower()

    def test_preserves_standard_status_vocabulary(self):
        for status in ("APPROVED", "STALE", "SUPERSEDED"):
            with self.subTest(status=status):
                self.assertIn(status, self.content)

    def test_defines_accepted_mutant_lineage_as_auditable_record(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"accepted[- ]mutant.+approval record",
        )

    def test_accepted_mutant_records_expire(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"accepted[- ]mutant.{0,200}(?:90 days|expires? at|expires?)",
        )

    def test_accepted_mutants_are_not_silent_config_waivers(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"accepted[- ]mutant.+not.+silent.+waiver",
        )

    def test_accept_mutant_command_is_implemented_as_a_verify_recording_path(self):
        self.assertIn(
            "`sw-verify --accept-mutant {id} --reason \"{prose}\"`",
            self.content,
        )
        self.assertNotIn("planned — implemented in a later unit", self.content)
        assert_multiline_regex(
            self,
            self.lower,
            r"sw-verify.+record.+accepted[- ]mutant.+(?:expiry|expires?)",
        )


class TestBuildTimeMutationSignalProtocol(unittest.TestCase):
    """AC-5 + AC-6: build-quality protocol keeps mutation advisory during build."""

    def setUp(self):
        self.content = load_text(_BUILD_QUALITY_PATH)
        self.lower = self.content.lower()

    def test_build_time_mutation_signal_is_advisory_only(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"build-time mutation.+advisory",
        )

    def test_tool_backed_mutation_errors_do_not_block_red_to_green(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"tool-backed mutation errors?.+cannot block.+red.?to.?green",
        )

    def test_build_time_mutation_notes_are_recorded(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"mutation.+recorded.+(?:as-built notes|build-time notes)",
        )


class TestMutationContractDrift(unittest.TestCase):
    """AC-6: shared mutation surfaces keep cross-file vocabulary aligned."""

    def setUp(self):
        self.config = _load_json(_CONFIG_PATH)["gates"]["tests"]["mutation"]
        self.detection = load_text(_DETECTION_PATH)
        self.evidence = load_text(_EVIDENCE_PATH)
        self.approvals = load_text(_APPROVALS_PATH)

    def test_approvals_name_the_accepted_mutants_config_key(self):
        self.assertIn("acceptedMutants", self.config)
        self.assertIn("acceptedMutants", self.approvals)

    def test_mutation_fallback_never_becomes_a_silent_skip(self):
        # `guardrails-detection.md` uses the canonical phrase "silently skipping";
        # `evidence.md` documents the same contract as "silent skip".
        self.assertIn("silently skipping", self.detection)
        assert_multiline_regex(
            self,
            self.evidence.lower(),
            r"mutation.+never.+silent skip",
        )

    def test_tier_vocabulary_is_shared_across_detection_and_evidence(self):
        for label in ("T1", "T2", "T3"):
            with self.subTest(label=label):
                self.assertIn(label, self.detection)
                self.assertIn(label, self.evidence)


if __name__ == "__main__":
    unittest.main()
