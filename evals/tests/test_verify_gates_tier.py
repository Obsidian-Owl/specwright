"""Tests for WU-03: Deliverable verification, tier distribution, and IC-B mapping.

Covers:
  AC-1 to AC-5: Deliverable verification in sw-verify
  AC-6 to AC-8: Tier distribution in gate-tests
  AC-9 to AC-11: Behavioral IC mapping in gate-spec
"""

import os
import re
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_VERIFY_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-verify", "SKILL.md")
_GATE_TESTS_PATH = os.path.join(_REPO_ROOT, "core", "skills", "gate-tests", "SKILL.md")
_GATE_SPEC_PATH = os.path.join(_REPO_ROOT, "core", "skills", "gate-spec", "SKILL.md")


def _load(path):
    with open(path, "r") as f:
        return f.read()


# ===========================================================================
# AC-1 to AC-5: Deliverable Verification in sw-verify
# ===========================================================================

class TestAC1_DeliverableVerificationExists(unittest.TestCase):
    """AC-1: sw-verify has a deliverable verification constraint."""

    def setUp(self):
        self.content = _load(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_deliverable_verification_heading_or_constraint(self):
        """Must contain a 'Deliverable verification' section or constraint."""
        has_dv = bool(re.search(
            r"deliverable\s+verification",
            self.lower
        ))
        self.assertTrue(has_dv, "sw-verify must contain 'Deliverable verification'")

    def test_activation_requires_multi_wu(self):
        """Activation requires workUnits >1 entry."""
        has_multi = bool(re.search(
            r"(workunits|work.units).{0,80}(>.*1|more\s+than\s+one|multiple|multi)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_multi, "Must require multiple work units for activation")

    def test_activation_requires_last_unit(self):
        """Current unit must be last in sequence."""
        has_last = bool(re.search(
            r"(last|final).{0,40}(unit|sequence)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_last, "Must activate on last/final unit")

    def test_activation_requires_prior_shipped_or_verified(self):
        """All prior units must be shipped or verified."""
        has_shipped = bool(re.search(
            r"prior.{0,60}(shipped|verified)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_shipped, "Must require prior units shipped or verified")

    def test_activation_requires_gates_pass_or_warn(self):
        """Must only activate when standard gates are PASS or WARN, not FAIL."""
        has_guard = bool(re.search(
            r"(pass|warn).{0,60}(not\s+fail|not\s+error)",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"gate.{0,60}(pass|warn).{0,40}(fail|error)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_guard, "Must require gates PASS/WARN before activating")

    def test_labeled_as_inline_not_gate(self):
        """Must be labeled as inline phase, not a gate."""
        has_inline = bool(re.search(
            r"inline.{0,30}(phase|step)|not\s+a\s+gate",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_inline, "Must be labeled as inline phase, not a gate")


class TestAC2_ICBEvidenceMapping(unittest.TestCase):
    """AC-2: Deliverable verification maps IC-Bs to test evidence."""

    def setUp(self):
        self.content = _load(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_loads_integration_criteria(self):
        """Must reference integration-criteria.md."""
        self.assertIn("integration-criteria", self.lower)

    def test_identifies_behavioral_ics(self):
        """Must identify IC-B entries."""
        has_icb = bool(re.search(r"ic-b", self.lower))
        self.assertTrue(has_icb, "Must reference IC-B entries")

    def test_block_for_missing_evidence(self):
        """IC-Bs without evidence produce BLOCK."""
        has_block = bool(re.search(
            r"ic-b.{0,200}block|block.{0,200}ic-b",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_block, "IC-Bs without evidence must produce BLOCK")

    def test_references_gate_evidence(self):
        """Must check gate-tests or gate-build evidence for passing results."""
        has_evidence = bool(re.search(
            r"(gate.tests|gate.build).{0,80}evidence",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"evidence.{0,80}(gate.tests|gate.build)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_evidence, "Must reference gate evidence for passing results")


class TestAC3_NoBehavioralICs(unittest.TestCase):
    """AC-3: No IC-Bs → SKIP with INFO, not BLOCK."""

    def setUp(self):
        self.content = _load(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_skip_when_no_icbs(self):
        """Must produce SKIP when no IC-Bs defined."""
        has_skip = bool(re.search(
            r"(no\s+ic-b|no\s+behavioral).{0,80}skip",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_skip, "Must SKIP when no IC-Bs are defined")

    def test_skip_when_file_absent(self):
        """Must handle missing integration-criteria.md explicitly with SKIP."""
        has_absent = bool(re.search(
            r"(does\s+not\s+exist|not\s+found|absent|missing).{0,80}skip",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_absent, "Must SKIP when integration-criteria.md is absent")


class TestAC4_IntegrationTestCommands(unittest.TestCase):
    """AC-4: Runs configured integration/e2e test commands."""

    def setUp(self):
        self.content = _load(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_runs_integration_command(self):
        """Must reference commands.test:integration."""
        has_int = bool(re.search(r"commands\.test:integration", self.lower))
        self.assertTrue(has_int, "Must reference commands.test:integration")

    def test_runs_e2e_command(self):
        """Must reference commands.test:e2e."""
        has_e2e = bool(re.search(r"commands\.test:e2e", self.lower))
        self.assertTrue(has_e2e, "Must reference commands.test:e2e")

    def test_failing_commands_block(self):
        """Failing commands must produce BLOCK."""
        has_block = bool(re.search(
            r"(fail|failing).{0,60}block",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_block, "Failing test commands must produce BLOCK")

    def test_unconfigured_commands_warn(self):
        """Unconfigured commands must produce WARN."""
        has_warn = bool(re.search(
            r"(unconfigured|not\s+configured).{0,60}warn",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_warn, "Unconfigured test commands must produce WARN")


class TestAC5_EvidenceSection(unittest.TestCase):
    """AC-5: Produces a Deliverable Verification section in report."""

    def setUp(self):
        self.content = _load(_VERIFY_PATH)
        self.lower = self.content.lower()

    def test_section_in_report(self):
        """Must produce a Deliverable Verification section in the verify report."""
        has_section = bool(re.search(
            r"deliverable\s+verification.{0,80}(section|report|evidence)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_section, "Must produce a Deliverable Verification section")

    def test_after_standard_gates(self):
        """Must be positioned after standard gate results."""
        has_after = bool(re.search(
            r"after.{0,60}(standard|six|6).{0,30}gate",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_after, "Must be after standard gates")


# ===========================================================================
# AC-6 to AC-8: Tier Distribution in gate-tests
# ===========================================================================

class TestAC6_TierDistributionDimension(unittest.TestCase):
    """AC-6: gate-tests has a tier distribution quality dimension."""

    def setUp(self):
        self.content = _load(_GATE_TESTS_PATH)
        self.lower = self.content.lower()

    def test_tier_distribution_mentioned(self):
        """Must mention tier distribution as a quality dimension."""
        has_td = bool(re.search(r"tier\s+distribution", self.lower))
        self.assertTrue(has_td, "gate-tests must mention 'tier distribution'")

    def test_checks_tier_tagged_acs(self):
        """Must check ACs tagged with non-unit tiers."""
        has_check = bool(re.search(
            r"\[tier:\s*(integration|contract|e2e)\]",
            self.lower
        ))
        self.assertTrue(has_check, "Must reference specific tier tags")

    def test_uses_heuristics(self):
        """Must use heuristics to classify test tier."""
        has_heuristic = bool(re.search(
            r"heuristic|real\s+infrastructure|multiple\s+modules|schema|full\s+flow",
            self.lower
        ))
        self.assertTrue(has_heuristic, "Must describe heuristics for tier classification")


class TestAC7_TierDistributionVerdicts(unittest.TestCase):
    """AC-7: Tier distribution verdict logic."""

    def setUp(self):
        self.content = _load(_GATE_TESTS_PATH)
        self.lower = self.content.lower()

    def test_block_for_failing_tier_tests(self):
        """Non-unit ACs with failing tier tests must BLOCK."""
        has_block = bool(re.search(
            r"(fail|failing).{0,80}block",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_block, "Failing tier tests must produce BLOCK")

    def test_block_for_unit_only_tests(self):
        """Non-unit ACs with only unit tests must BLOCK."""
        has_block = bool(re.search(
            r"(only\s+unit|unit.tier\s+test).{0,80}block",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"block.{0,80}(only\s+unit|unit.tier)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_block, "Non-unit ACs with only unit tests must BLOCK")

    def test_pass_when_no_non_unit_acs(self):
        """Zero non-unit ACs must produce PASS."""
        has_pass = bool(re.search(
            r"(zero|no)\s+non.unit.{0,60}pass",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_pass, "Zero non-unit ACs must produce PASS")


class TestAC8_NoFalsePositives(unittest.TestCase):
    """AC-8: No false positives when TESTING.md absent and no tier tags."""

    def setUp(self):
        self.content = _load(_GATE_TESTS_PATH)
        self.lower = self.content.lower()

    def test_info_when_no_data(self):
        """Must produce INFO when no tier-tagged ACs exist, not false positives."""
        has_info = bool(re.search(
            r"(no\s+tier|no\s+data|absent).{0,80}info",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"info.{0,80}(no\s+tier|no\s+data)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_info, "Must produce INFO (not BLOCK/WARN) when no tier data")


# ===========================================================================
# AC-9 to AC-11: Behavioral IC Mapping in gate-spec
# ===========================================================================

class TestAC9_GateSpecICBParsing(unittest.TestCase):
    """AC-9: gate-spec parses IC-B entries on final WU."""

    def setUp(self):
        self.content = _load(_GATE_SPEC_PATH)
        self.lower = self.content.lower()

    def test_parses_icb_entries(self):
        """Must parse IC-B entries from integration-criteria.md."""
        has_icb = bool(re.search(r"ic-b", self.lower))
        self.assertTrue(has_icb, "gate-spec must reference IC-B entries")

    def test_references_integration_criteria(self):
        """Must reference integration-criteria.md."""
        has_ref = bool(re.search(r"integration-criteria", self.lower))
        self.assertTrue(has_ref, "Must reference integration-criteria.md")

    def test_final_wu_condition(self):
        """Must activate on final work unit."""
        has_final = bool(re.search(
            r"final.{0,30}(work\s+unit|wu|unit)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_final, "Must activate on final work unit")


class TestAC10_ICBComplianceMatrix(unittest.TestCase):
    """AC-10: IC-B entries use compliance matrix format."""

    def setUp(self):
        self.content = _load(_GATE_SPEC_PATH)
        self.lower = self.content.lower()

    def test_icb_mapped_like_acs(self):
        """IC-Bs must use same compliance matrix format as ACs."""
        has_matrix = bool(re.search(
            r"ic-b.{0,120}(compliance|matrix|evidence)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_matrix, "IC-Bs must be in the compliance matrix")

    def test_icb_fail_without_test_evidence(self):
        """IC-B without test evidence must FAIL."""
        has_fail = bool(re.search(
            r"ic-b.{0,200}(without|no)\s+test.{0,40}fail",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"fail.{0,200}ic-b.{0,60}(without|no)\s+test",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_fail, "IC-Bs without test evidence must FAIL")

    def test_complementary_with_deliverable_verification(self):
        """Must note that gate-spec FAIL and deliverable BLOCK are complementary."""
        has_comp = bool(re.search(
            r"complementary|gate.spec.{0,80}deliverable|deliverable.{0,80}gate.spec",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_comp, "Must note complementary relationship with deliverable verification")


class TestAC11_NoChangeWhenNotFinalWU(unittest.TestCase):
    """AC-11: gate-spec unchanged when not on final WU or file absent."""

    def setUp(self):
        self.content = _load(_GATE_SPEC_PATH)
        self.lower = self.content.lower()

    def test_no_icb_when_not_final(self):
        """Must operate as before when not on final WU."""
        has_condition = bool(re.search(
            r"(not\s+on|not\s+the).{0,30}final.{0,60}(as\s+before|no\s+(behavioral|ic-b)|unchanged|exactly)",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"(no\s+ic-b|no\s+behavioral).{0,60}(operat|unchanged|skip|as\s+before)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_condition, "Must operate as before when not on final WU or no IC-Bs")

    def test_handles_file_absent(self):
        """Must handle integration-criteria.md not existing."""
        has_absent = bool(re.search(
            r"(does\s+not\s+exist|not\s+exist).{0,60}(no\s+behavioral|as\s+before|operat)",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"integration-criteria.{0,40}(does\s+not\s+exist|not\s+exist|absent)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_absent, "Must handle missing integration-criteria.md explicitly")


# ===========================================================================
# Document integrity
# ===========================================================================

class TestVerifyIntegrity(unittest.TestCase):
    """Existing sw-verify constraints preserved."""

    def setUp(self):
        self.content = _load(_VERIFY_PATH)

    def test_stage_boundary(self):
        self.assertIn("Stage boundary", self.content)

    def test_gate_execution_order(self):
        self.assertIn("Gate execution order", self.content)

    def test_gate_handoff(self):
        self.assertIn("Gate handoff", self.content)

    def test_six_gates_listed(self):
        self.assertIn("build, tests, security, wiring, semantic, spec", self.content.lower())


class TestGateTestsIntegrity(unittest.TestCase):
    """Existing gate-tests dimensions preserved."""

    def setUp(self):
        self.content = _load(_GATE_TESTS_PATH)

    def test_assertion_strength(self):
        self.assertIn("Assertion strength", self.content)

    def test_boundary_coverage(self):
        self.assertIn("Boundary coverage", self.content)

    def test_mock_discipline(self):
        self.assertIn("Mock discipline", self.content)

    def test_mutation_resistance(self):
        self.assertIn("Mutation resistance", self.content)


class TestGateSpecIntegrity(unittest.TestCase):
    """Existing gate-spec behavior preserved."""

    def setUp(self):
        self.content = _load(_GATE_SPEC_PATH)

    def test_criteria_extraction(self):
        self.assertIn("Criteria extraction", self.content)

    def test_compliance_matrix(self):
        self.assertIn("Compliance matrix", self.content)

    def test_evidence_mapping(self):
        self.assertIn("Evidence mapping", self.content)


if __name__ == "__main__":
    unittest.main()
