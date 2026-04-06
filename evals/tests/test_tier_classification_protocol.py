"""Tests for tier classification extension in core/protocols/testing-strategy.md.

RED phase: all tests must fail because the Tier Classification section does not
exist yet in the protocol file.

This test suite covers:
  AC-2:    "## Tier Classification" section exists in testing-strategy.md
  AC-2(a): Defines four tiers (unit, integration, contract, e2e) with classification rules
  AC-2(b): Maps boundary classifications to tier tags
           (internal -> integration, external -> contract, expensive -> integration w/ rationale)
  AC-2(c): Specifies the [tier: X] annotation format for acceptance criteria
  AC-2(d): Documents that untagged ACs default to unit tier
  AC-2(e): Section is positioned after "Boundary Classifications" and before "Pipeline Flow"
  AC-3:    Pipeline Flow sw-plan row references [tier: X] annotation format

Done when all fail before implementation.
"""

import os
import re
import unittest


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_PROTOCOL_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "testing-strategy.md")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_protocol():
    """Load the testing-strategy.md protocol file content."""
    with open(_PROTOCOL_PATH, "r") as f:
        return f.read()


def _extract_section(content, heading):
    """Extract the content of a ## section by its heading text.

    Returns the text between the heading and the next ## heading (or EOF).
    Returns None if the section is not found.
    """
    pattern = rf"^## {re.escape(heading)}\s*\n(.*?)(?=\n## |\Z)"
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        return match.group(1).strip()
    return None


def _require_section(content: str, heading: str) -> str:
    """Extract section, raising AssertionError if missing. Returns str (not Optional)."""
    section = _extract_section(content, heading)
    if section is None:
        raise AssertionError(f"Section '## {heading}' must exist in testing-strategy.md")
    return section


def _get_h2_headings(content):
    """Return all ## headings in document order."""
    return re.findall(r"^## (.+)$", content, re.MULTILINE)


# ---------------------------------------------------------------------------
# AC-2: Tier Classification section exists
# ---------------------------------------------------------------------------

class TestTierClassificationSectionExists(unittest.TestCase):
    """AC-2: testing-strategy.md contains a '## Tier Classification' section."""

    def setUp(self):
        self.content = _load_protocol()

    def test_tier_classification_heading_exists(self):
        """The file must contain a '## Tier Classification' heading."""
        self.assertRegex(
            self.content,
            r"(?m)^## Tier Classification\s*$",
            "testing-strategy.md must contain a '## Tier Classification' section heading"
        )

    def test_tier_classification_section_is_substantive(self):
        """The section must have meaningful content, not just a heading."""
        section = _extract_section(self.content, "Tier Classification")
        self.assertIsNotNone(section,
                             "Tier Classification section must exist")
        assert section is not None
        word_count = len(section.split())
        self.assertGreater(word_count, 30,
                           f"Tier Classification section is too short ({word_count} words) "
                           "to cover all required content")


# ---------------------------------------------------------------------------
# AC-2(a): Defines four tiers with classification rules
# ---------------------------------------------------------------------------

class TestAC2a_FourTiersDefined(unittest.TestCase):
    """AC-2(a): Four tiers (unit, integration, contract, e2e) with classification rules."""

    def setUp(self):
        self.content = _load_protocol()
        self.section = _require_section(self.content, "Tier Classification")
        self.section_lower = self.section.lower()

    def test_defines_unit_tier(self):
        """The section must define a unit tier."""
        self.assertRegex(
            self.section_lower,
            r"\bunit\b",
            "Tier Classification must define a 'unit' tier"
        )

    def test_defines_integration_tier(self):
        """The section must define an integration tier."""
        self.assertRegex(
            self.section_lower,
            r"\bintegration\b",
            "Tier Classification must define an 'integration' tier"
        )

    def test_defines_contract_tier(self):
        """The section must define a contract tier."""
        self.assertRegex(
            self.section_lower,
            r"\bcontract\b",
            "Tier Classification must define a 'contract' tier"
        )

    def test_defines_e2e_tier(self):
        """The section must define an e2e tier."""
        self.assertRegex(
            self.section_lower,
            r"\b(e2e|end.to.end)\b",
            "Tier Classification must define an 'e2e' tier"
        )

    def test_all_four_tiers_present(self):
        """Guard against partial implementation: all four tiers must be present."""
        has_unit = bool(re.search(r"\bunit\b", self.section_lower))
        has_integration = bool(re.search(r"\bintegration\b", self.section_lower))
        has_contract = bool(re.search(r"\bcontract\b", self.section_lower))
        has_e2e = bool(re.search(r"\b(e2e|end.to.end)\b", self.section_lower))
        count = sum([has_unit, has_integration, has_contract, has_e2e])
        self.assertEqual(count, 4,
                         f"All four tiers must be defined; found {count}/4")

    def test_unit_tier_has_classification_rule(self):
        """The unit tier must have a classification rule, not just a name."""
        # Look for unit appearing near descriptive text (not just in a list)
        has_rule = bool(re.search(
            r"unit.{0,120}(isolat|single|no.depend|pure|without.boundar|no.external|self.contained|in.process)",
            self.section_lower
        )) or bool(re.search(
            r"(isolat|single|no.depend|pure|without.boundar|no.external|self.contained|in.process).{0,120}unit",
            self.section_lower
        ))
        self.assertTrue(
            has_rule,
            "Unit tier must include a classification rule describing when code qualifies as unit-testable"
        )

    def test_integration_tier_has_classification_rule(self):
        """Integration tier must describe what qualifies for integration testing."""
        has_rule = bool(re.search(
            r"integration.{0,120}(boundar|cross|real|multi|component|layer|module|service|database)",
            self.section_lower
        )) or bool(re.search(
            r"(boundar|cross|real|multi|component|layer|module|service|database).{0,120}integration",
            self.section_lower
        ))
        self.assertTrue(
            has_rule,
            "Integration tier must include a classification rule describing boundary-crossing behavior"
        )

    def test_contract_tier_has_classification_rule(self):
        """Contract tier must describe what qualifies for contract testing."""
        has_rule = bool(re.search(
            r"contract.{0,120}(external|interface|api|schema|wire|third.party|vendor|mock)",
            self.section_lower
        )) or bool(re.search(
            r"(external|interface|api|schema|wire|third.party|vendor|mock).{0,120}contract",
            self.section_lower
        ))
        self.assertTrue(
            has_rule,
            "Contract tier must include a classification rule describing external interface validation"
        )

    def test_e2e_tier_has_classification_rule(self):
        """E2E tier must describe what qualifies for end-to-end testing."""
        has_rule = bool(re.search(
            r"(e2e|end.to.end).{0,120}(full|complete|user|flow|system|critical|path|journey)",
            self.section_lower
        )) or bool(re.search(
            r"(full|complete|user|flow|system|critical|path|journey).{0,120}(e2e|end.to.end)",
            self.section_lower
        ))
        self.assertTrue(
            has_rule,
            "E2E tier must include a classification rule describing full system/user flow testing"
        )


# ---------------------------------------------------------------------------
# AC-2(b): Maps boundary classifications to tier tags
# ---------------------------------------------------------------------------

class TestAC2b_BoundaryToTierMapping(unittest.TestCase):
    """AC-2(b): Maps TESTING.md boundary classifications to tier tags."""

    def setUp(self):
        self.content = _load_protocol()
        self.section = _require_section(self.content, "Tier Classification")
        self.section_lower = self.section.lower()

    def test_internal_boundary_maps_to_integration(self):
        """Internal boundary must map to integration tier."""
        # Must show internal -> integration relationship
        has_mapping = bool(re.search(
            r"internal.{0,60}integration",
            self.section_lower
        ))
        self.assertTrue(
            has_mapping,
            "Internal boundary classification must map to integration tier"
        )

    def test_external_boundary_maps_to_contract(self):
        """External boundary must map to contract tier."""
        has_mapping = bool(re.search(
            r"external.{0,60}contract",
            self.section_lower
        ))
        self.assertTrue(
            has_mapping,
            "External boundary classification must map to contract tier"
        )

    def test_expensive_boundary_maps_to_integration(self):
        """Expensive boundary must map to integration tier."""
        has_mapping = bool(re.search(
            r"expensive.{0,60}integration",
            self.section_lower
        ))
        self.assertTrue(
            has_mapping,
            "Expensive boundary classification must map to integration tier"
        )

    def test_expensive_mapping_requires_documented_rationale(self):
        """Expensive -> integration mapping must require documented rationale."""
        has_rationale_req = bool(re.search(
            r"expensive.{0,120}(rationale|justif|document|reason|explain)",
            self.section_lower
        )) or bool(re.search(
            r"(rationale|justif|document|reason|explain).{0,120}expensive",
            self.section_lower
        ))
        self.assertTrue(
            has_rationale_req,
            "Expensive boundary mapping must require documented rationale"
        )

    def test_all_three_boundary_mappings_present(self):
        """Guard against partial implementation: all three boundary types must be mapped."""
        has_internal = bool(re.search(r"internal.{0,60}integration", self.section_lower))
        has_external = bool(re.search(r"external.{0,60}contract", self.section_lower))
        has_expensive = bool(re.search(r"expensive.{0,60}integration", self.section_lower))
        count = sum([has_internal, has_external, has_expensive])
        self.assertEqual(count, 3,
                         f"All three boundary-to-tier mappings must be present; found {count}/3")

    def test_mapping_is_not_just_incidental_word_proximity(self):
        """The mapping must be structured (table, definition list, or explicit 'maps to'),
        not just accidental proximity of words."""
        # Look for structured mapping indicators
        has_structure = bool(re.search(
            r"(internal\s*[\|→:].{0,30}integration|internal.{0,20}(maps?\s+to|->|→)\s*.{0,10}integration)",
            self.section_lower
        )) or bool(re.search(
            r"\|\s*internal\s*\|.*integration",
            self.section_lower
        )) or bool(re.search(
            r"internal.{0,5}boundar.{0,30}integration",
            self.section_lower
        ))
        self.assertTrue(
            has_structure,
            "Boundary-to-tier mapping must be structured (table, arrow, or explicit 'maps to'), "
            "not incidental word proximity"
        )


# ---------------------------------------------------------------------------
# AC-2(c): Specifies [tier: X] annotation format
# ---------------------------------------------------------------------------

class TestAC2c_TierAnnotationFormat(unittest.TestCase):
    """AC-2(c): Specifies the [tier: X] annotation format for acceptance criteria."""

    def setUp(self):
        self.content = _load_protocol()
        self.section = _require_section(self.content, "Tier Classification")

    def test_contains_tier_annotation_format(self):
        """Must contain the literal [tier: X] format or a concrete example."""
        # Accept [tier: X], [tier: unit], [tier: integration], etc.
        has_format = bool(re.search(
            r"\[tier:\s*\w+\]",
            self.section, re.IGNORECASE
        ))
        self.assertTrue(
            has_format,
            "Tier Classification must specify the [tier: X] annotation format"
        )

    def test_tier_annotation_shows_at_least_two_concrete_examples(self):
        """Must show concrete examples, not just the abstract [tier: X] pattern.
        At least two different tier values must appear in annotation format."""
        matches = re.findall(
            r"\[tier:\s*(\w+)\]",
            self.section, re.IGNORECASE
        )
        unique_tiers = set(t.lower() for t in matches)
        # Remove placeholder values like 'x' or 'X'
        concrete_tiers = unique_tiers - {"x"}
        self.assertGreaterEqual(
            len(concrete_tiers), 2,
            f"Must show at least 2 concrete tier annotation examples; found: {concrete_tiers}"
        )

    def test_annotation_format_mentions_acceptance_criteria(self):
        """The annotation format must be described in context of acceptance criteria."""
        section_lower = self.section.lower()
        has_ac_context = bool(re.search(
            r"(acceptance\s+criter|ac\b).{0,60}\[tier:",
            section_lower
        )) or bool(re.search(
            r"\[tier:.{0,60}(acceptance\s+criter|ac\b)",
            section_lower
        ))
        self.assertTrue(
            has_ac_context,
            "[tier: X] format must be described in context of acceptance criteria"
        )


# ---------------------------------------------------------------------------
# AC-2(d): Untagged ACs default to unit tier
# ---------------------------------------------------------------------------

class TestAC2d_UntaggedDefaultsToUnit(unittest.TestCase):
    """AC-2(d): Documents that untagged ACs default to unit tier."""

    def setUp(self):
        self.content = _load_protocol()
        self.section = _require_section(self.content, "Tier Classification")
        self.section_lower = self.section.lower()

    def test_mentions_default_behavior(self):
        """Must document what happens when an AC has no tier tag."""
        has_default = bool(re.search(
            r"(default|untagged|without.{0,15}tag|no.{0,10}tag|missing.{0,10}tag|not.{0,10}annotated|omit)",
            self.section_lower
        ))
        self.assertTrue(
            has_default,
            "Must document default behavior for untagged acceptance criteria"
        )

    def test_default_is_unit_tier(self):
        """The default tier for untagged ACs must be unit."""
        # Must show the connection between default/untagged AND unit
        has_unit_default = bool(re.search(
            r"(default|untagged|without.{0,15}tag|no.{0,10}tag|missing.{0,10}tag|omit).{0,60}unit",
            self.section_lower
        )) or bool(re.search(
            r"unit.{0,60}(default|untagged|without.{0,15}tag|no.{0,10}tag|missing.{0,10}tag|omit)",
            self.section_lower
        ))
        self.assertTrue(
            has_unit_default,
            "Untagged/default ACs must default to unit tier, not another tier"
        )

    def test_default_is_not_integration_or_e2e(self):
        """The default must specifically be unit, not integration or e2e.
        Guards against an implementation that says 'defaults to integration'."""
        # Check that 'default' is NOT near integration/contract/e2e without also being near unit
        integration_default = bool(re.search(
            r"(default|untagged).{0,30}integration",
            self.section_lower
        ))
        e2e_default = bool(re.search(
            r"(default|untagged).{0,30}(e2e|end.to.end)",
            self.section_lower
        ))
        contract_default = bool(re.search(
            r"(default|untagged).{0,30}contract",
            self.section_lower
        ))
        unit_default = bool(re.search(
            r"(default|untagged).{0,30}unit",
            self.section_lower
        ))
        # Unit default must be present, and if other tiers appear near 'default',
        # unit must also be explicitly stated as THE default
        self.assertTrue(
            unit_default,
            "The default tier must be explicitly stated as 'unit'"
        )
        if integration_default or e2e_default or contract_default:
            # If other tiers appear near 'default', the section might say
            # "defaults to X not Y" -- that's fine as long as unit is the default.
            # But if unit_default is False, we already failed above.
            pass


# ---------------------------------------------------------------------------
# AC-2(e): Section positioning
# ---------------------------------------------------------------------------

class TestAC2e_SectionPositioning(unittest.TestCase):
    """AC-2(e): Tier Classification is after Boundary Classifications, before Pipeline Flow."""

    def setUp(self):
        self.content = _load_protocol()
        self.headings = _get_h2_headings(self.content)

    def test_tier_classification_in_headings(self):
        """Tier Classification must appear in the document's ## headings."""
        self.assertIn(
            "Tier Classification", self.headings,
            f"'Tier Classification' not found in ## headings: {self.headings}"
        )

    def test_boundary_classifications_exists(self):
        """Sanity check: Boundary Classifications heading must still exist."""
        self.assertIn(
            "Boundary Classifications", self.headings,
            "Boundary Classifications heading must still exist in the document"
        )

    def test_pipeline_flow_exists(self):
        """Sanity check: Pipeline Flow heading must still exist."""
        self.assertIn(
            "Pipeline Flow", self.headings,
            "Pipeline Flow heading must still exist in the document"
        )

    def test_tier_classification_after_boundary_classifications(self):
        """Tier Classification must come after Boundary Classifications."""
        if "Tier Classification" not in self.headings:
            self.fail("Tier Classification heading not found")
        if "Boundary Classifications" not in self.headings:
            self.fail("Boundary Classifications heading not found")
        bc_idx = self.headings.index("Boundary Classifications")
        tc_idx = self.headings.index("Tier Classification")
        self.assertGreater(
            tc_idx, bc_idx,
            f"Tier Classification (index {tc_idx}) must come after "
            f"Boundary Classifications (index {bc_idx})"
        )

    def test_tier_classification_before_pipeline_flow(self):
        """Tier Classification must come before Pipeline Flow."""
        if "Tier Classification" not in self.headings:
            self.fail("Tier Classification heading not found")
        if "Pipeline Flow" not in self.headings:
            self.fail("Pipeline Flow heading not found")
        tc_idx = self.headings.index("Tier Classification")
        pf_idx = self.headings.index("Pipeline Flow")
        self.assertLess(
            tc_idx, pf_idx,
            f"Tier Classification (index {tc_idx}) must come before "
            f"Pipeline Flow (index {pf_idx})"
        )

    def test_tier_classification_immediately_before_pipeline_flow(self):
        """Tier Classification should be the section immediately before Pipeline Flow,
        with no other ## sections between them."""
        if "Tier Classification" not in self.headings:
            self.fail("Tier Classification heading not found")
        if "Pipeline Flow" not in self.headings:
            self.fail("Pipeline Flow heading not found")
        tc_idx = self.headings.index("Tier Classification")
        pf_idx = self.headings.index("Pipeline Flow")
        self.assertEqual(
            tc_idx + 1, pf_idx,
            f"Tier Classification (index {tc_idx}) must be immediately before "
            f"Pipeline Flow (index {pf_idx}), but there are {pf_idx - tc_idx - 1} "
            f"sections between them: {self.headings[tc_idx+1:pf_idx]}"
        )


# ---------------------------------------------------------------------------
# AC-3: Pipeline Flow sw-plan row references [tier: X]
# ---------------------------------------------------------------------------

class TestAC3_PipelineFlowTierTagging(unittest.TestCase):
    """AC-3: Pipeline Flow's sw-plan row references [tier: X] annotation format."""

    def setUp(self):
        self.content = _load_protocol()
        self.pipeline_section = _require_section(self.content, "Pipeline Flow")
        self.pipeline_lower = self.pipeline_section.lower()

    def test_sw_plan_subsection_mentions_tier_annotation(self):
        """The sw-plan subsection within Pipeline Flow must mention [tier: X] format."""
        # Extract the sw-plan subsection
        plan_match = re.search(
            r"###\s*sw-plan.*?\n(.*?)(?=\n### |\Z)",
            self.pipeline_section, re.DOTALL | re.IGNORECASE
        )
        self.assertIsNotNone(
            plan_match,
            "Pipeline Flow must contain a ### sw-plan subsection"
        )
        assert plan_match is not None
        plan_text = plan_match.group(1)
        has_tier_format = bool(re.search(r"\[tier:\s*\w+\]", plan_text, re.IGNORECASE))
        self.assertTrue(
            has_tier_format,
            "sw-plan subsection must reference [tier: X] annotation format"
        )

    def test_sw_plan_no_longer_uses_old_annotation_format(self):
        """The old [unit test]/[integration test] annotation must be replaced or unified
        with the new [tier: X] format."""
        plan_match = re.search(
            r"###\s*sw-plan.*?\n(.*?)(?=\n### |\Z)",
            self.pipeline_section, re.DOTALL | re.IGNORECASE
        )
        self.assertIsNotNone(plan_match, "Pipeline Flow must contain a ### sw-plan subsection")
        assert plan_match is not None
        plan_text = plan_match.group(1)
        # The old format used: `[unit test]`, `[integration test]`, `[E2E test]`
        has_old_format = bool(re.search(
            r"`\[(unit|integration|E2E)\s+test\]`",
            plan_text
        ))
        self.assertFalse(
            has_old_format,
            "sw-plan subsection must replace old `[unit test]`/`[integration test]`/`[E2E test]` "
            "annotations with the new [tier: X] format"
        )

    def test_consuming_skills_table_sw_plan_row_updated(self):
        """The Consuming Skills table's sw-plan row should reference tier tagging."""
        # The Consuming Skills section has a table with sw-plan row
        skills_section = _extract_section(self.content, "Consuming Skills")
        if skills_section is None:
            self.skipTest("Consuming Skills section not found")
        # Find the sw-plan table row
        plan_row_match = re.search(
            r"\|\s*`sw-plan`\s*\|(.*?)\|",
            skills_section
        )
        self.assertIsNotNone(plan_row_match, "Consuming Skills table must have sw-plan row")
        assert plan_row_match is not None
        plan_row_text = plan_row_match.group(1).lower()
        has_tier_ref = bool(re.search(r"tier", plan_row_text))
        self.assertTrue(
            has_tier_ref,
            "Consuming Skills table sw-plan row should reference tier tagging"
        )

    def test_pipeline_flow_sw_plan_mentions_architect(self):
        """The sw-plan section must specify that the architect annotates ACs."""
        plan_match = re.search(
            r"###\s*sw-plan.*?\n(.*?)(?=\n### |\Z)",
            self.pipeline_section, re.DOTALL | re.IGNORECASE
        )
        self.assertIsNotNone(plan_match, "Pipeline Flow must contain a ### sw-plan subsection")
        assert plan_match is not None
        plan_text_lower = plan_match.group(1).lower()
        has_architect = bool(re.search(r"architect", plan_text_lower))
        self.assertTrue(
            has_architect,
            "sw-plan subsection must specify that the architect annotates ACs with tier tags"
        )


# ---------------------------------------------------------------------------
# Cross-cutting: document integrity after modifications
# ---------------------------------------------------------------------------

class TestDocumentIntegrity(unittest.TestCase):
    """Cross-cutting: existing sections are not broken by the modifications."""

    def setUp(self):
        self.content = _load_protocol()
        self.headings = _get_h2_headings(self.content)

    def test_existing_sections_preserved(self):
        """All pre-existing sections must still exist after modification."""
        required_sections = [
            "Precedence",
            "Consuming Skills",
            "Boundary Classifications",
            "Pipeline Flow",
            "Test Commands Section",
            "When TESTING.md Does Not Exist",
        ]
        for section in required_sections:
            self.assertIn(
                section, self.headings,
                f"Pre-existing section '{section}' must be preserved"
            )

    def test_boundary_classifications_content_unchanged(self):
        """Boundary Classifications section must retain its three subsections."""
        bc_section = _extract_section(self.content, "Boundary Classifications")
        self.assertIsNotNone(bc_section, "Boundary Classifications must exist")
        assert bc_section is not None
        for subsection in ["### Internal", "### External", "### Expensive"]:
            self.assertIn(
                subsection, bc_section,
                f"Boundary Classifications must still contain '{subsection}'"
            )


if __name__ == "__main__":
    unittest.main()
