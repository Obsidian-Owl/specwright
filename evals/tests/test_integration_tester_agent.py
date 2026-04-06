"""Tests for core/agents/specwright-integration-tester.md agent definition.

RED phase: all tests must fail because the file does not exist yet.

This test suite covers:
  AC-1:    File exists with valid YAML frontmatter
  AC-1(a): System prompt instructs agent to write integration, contract, and E2E tests
  AC-1(b): System prompt explicitly prohibits skip conditions for missing infrastructure
  AC-1(c): System prompt instructs agent to read TESTING.md for boundary classifications
  AC-1(d): System prompt instructs agent to adapt to project language via config.json
           and existing test conventions
  AC-1(e): Structured output format matches specwright-tester's output format
  AC-1(f): Tier-specific test strategies section with required content for each tier

Done when all fail before implementation.
"""

import os
import re
import unittest

import yaml


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_AGENT_PATH = os.path.join(_REPO_ROOT, "core", "agents", "specwright-integration-tester.md")
_TESTER_PATH = os.path.join(_REPO_ROOT, "core", "agents", "specwright-tester.md")

# The exact tools required by the spec
REQUIRED_TOOLS = {"Read", "Write", "Edit", "Bash", "Glob", "Grep"}

# Output format headings from specwright-tester.md that must be matched
REQUIRED_OUTPUT_HEADINGS = [
    "Test file(s)",
    "Coverage map",
    "Edge cases tested",
    "Test type rationale",
    "Weakness audit",
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_agent():
    """Load the agent file, returning (frontmatter_dict, body_text).

    Raises FileNotFoundError if the file does not exist.
    """
    with open(_AGENT_PATH, "r") as f:
        content = f.read()

    # YAML frontmatter is delimited by --- on its own lines
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", content, re.DOTALL)
    if not match:
        raise ValueError("File does not contain valid YAML frontmatter delimited by ---")

    frontmatter = yaml.safe_load(match.group(1))
    body = match.group(2)
    return frontmatter, body


def _load_tester_output_format():
    """Load specwright-tester.md and extract its output format section."""
    with open(_TESTER_PATH, "r") as f:
        content = f.read()
    # Extract the output format section
    match = re.search(r"## Output format\n(.*?)(?:\n## |\Z)", content, re.DOTALL)
    if not match:
        raise ValueError("Could not find '## Output format' in specwright-tester.md")
    return match.group(1).strip()


# ---------------------------------------------------------------------------
# AC-1: File existence and YAML frontmatter structure
# ---------------------------------------------------------------------------

class TestAgentFileExists(unittest.TestCase):
    """AC-1: specwright-integration-tester.md exists."""

    def test_file_exists(self):
        self.assertTrue(
            os.path.isfile(_AGENT_PATH),
            f"Agent definition file must exist at {_AGENT_PATH}"
        )


class TestFrontmatterStructure(unittest.TestCase):
    """AC-1: YAML frontmatter has required fields with correct values."""

    def setUp(self):
        self.frontmatter, self.body = _load_agent()

    def test_frontmatter_has_name_field(self):
        self.assertIn("name", self.frontmatter, "Frontmatter must include 'name'")

    def test_name_is_specwright_integration_tester(self):
        self.assertEqual(
            self.frontmatter["name"], "specwright-integration-tester",
            "Name must be 'specwright-integration-tester'"
        )

    def test_frontmatter_has_description_field(self):
        self.assertIn("description", self.frontmatter, "Frontmatter must include 'description'")

    def test_description_is_nonempty_string(self):
        desc = self.frontmatter["description"]
        self.assertIsInstance(desc, str)
        self.assertTrue(len(desc.strip()) > 10,
                        "Description must be a substantive string, not empty or trivial")

    def test_frontmatter_has_model_field(self):
        self.assertIn("model", self.frontmatter, "Frontmatter must include 'model'")

    def test_model_is_opus(self):
        self.assertEqual(self.frontmatter["model"], "opus",
                         "Model must be 'opus'")

    def test_frontmatter_has_tools_field(self):
        self.assertIn("tools", self.frontmatter, "Frontmatter must include 'tools'")

    def test_tools_contains_all_required_tools(self):
        tools = set(self.frontmatter["tools"])
        missing = REQUIRED_TOOLS - tools
        self.assertEqual(missing, set(),
                         f"Missing required tools: {missing}")

    def test_tools_are_exactly_the_required_set(self):
        """Tools list must contain exactly the specified tools -- no extras."""
        tools = set(self.frontmatter["tools"])
        extra = tools - REQUIRED_TOOLS
        self.assertEqual(extra, set(),
                         f"Unexpected extra tools: {extra}")

    def test_tools_has_no_duplicates(self):
        tools = self.frontmatter["tools"]
        self.assertEqual(len(tools), len(set(tools)),
                         f"Tools list contains duplicates: {tools}")


# ---------------------------------------------------------------------------
# AC-1(a): Instructs agent to write integration, contract, and E2E tests
# ---------------------------------------------------------------------------

class TestACa_IntegrationContractE2E(unittest.TestCase):
    """AC-1(a): System prompt covers integration, contract, and E2E test types."""

    def setUp(self):
        _, self.body = _load_agent()
        self.body_lower = self.body.lower()

    def test_mentions_integration_tests(self):
        self.assertRegex(
            self.body_lower,
            r"integration\s+test",
            "System prompt must instruct agent to write integration tests"
        )

    def test_mentions_contract_tests(self):
        self.assertRegex(
            self.body_lower,
            r"contract\s+test",
            "System prompt must instruct agent to write contract tests"
        )

    def test_mentions_e2e_tests(self):
        # Accept "e2e", "end-to-end", "end to end"
        self.assertRegex(
            self.body_lower,
            r"(e2e|end.to.end)\s+test",
            "System prompt must instruct agent to write E2E tests"
        )

    def test_all_three_test_types_present_not_just_one(self):
        """Guard against partial implementation that only mentions one type."""
        has_integration = bool(re.search(r"integration\s+test", self.body_lower))
        has_contract = bool(re.search(r"contract\s+test", self.body_lower))
        has_e2e = bool(re.search(r"(e2e|end.to.end)\s+test", self.body_lower))
        count = sum([has_integration, has_contract, has_e2e])
        self.assertEqual(count, 3,
                         f"All three test types must be present; found {count}/3")


# ---------------------------------------------------------------------------
# AC-1(b): Prohibits skip conditions for missing infrastructure
# ---------------------------------------------------------------------------

class TestACb_NoSkipConditions(unittest.TestCase):
    """AC-1(b): System prompt explicitly prohibits skip conditions for missing infra."""

    def setUp(self):
        _, self.body = _load_agent()
        self.body_lower = self.body.lower()

    def test_prohibits_skip_for_missing_infrastructure(self):
        """Must explicitly say not to skip when infrastructure is missing."""
        # Look for prohibition language near "skip"
        has_no_skip = bool(re.search(
            r"(never|must not|do not|don.t|prohibit|forbid|no)\s+.{0,40}skip",
            self.body_lower
        ))
        has_skip_prohibition = bool(re.search(
            r"skip.{0,40}(never|must not|do not|don.t|prohibit|forbid|not allowed)",
            self.body_lower
        ))
        self.assertTrue(
            has_no_skip or has_skip_prohibition,
            "System prompt must explicitly prohibit skip conditions for missing infrastructure"
        )

    def test_prohibition_mentions_infrastructure(self):
        """The skip prohibition must be in context of infrastructure."""
        # Find a passage that mentions both skip and infrastructure
        has_infra_skip = bool(re.search(
            r"(skip|t\.skip|pytest\.skip).{0,80}(infrastructure|infra|database|service|unavailable)",
            self.body_lower
        )) or bool(re.search(
            r"(infrastructure|infra|database|service|unavailable).{0,80}(skip|t\.skip|pytest\.skip)",
            self.body_lower
        ))
        self.assertTrue(
            has_infra_skip,
            "Prohibition on skip must reference infrastructure/services being unavailable"
        )

    def test_differs_from_tester_skip_policy(self):
        """The integration tester must NOT have the same skip-condition policy as
        specwright-tester.md, which ALLOWS skip conditions. This test ensures
        the prohibition is genuine, not a copy-paste from the tester agent."""
        with open(_TESTER_PATH, "r") as f:
            tester_content = f.read()
        # The tester allows skip conditions (e.g., t.Skip("requires DATABASE_URL"))
        # The integration tester must prohibit them
        # Verify the integration tester does not contain the same skip-allowing language
        tester_skip_pattern = r"write with a skip condition"
        tester_has_allow = bool(re.search(tester_skip_pattern, tester_content, re.IGNORECASE))
        integration_has_allow = bool(re.search(tester_skip_pattern, self.body, re.IGNORECASE))
        self.assertTrue(tester_has_allow,
                        "Sanity check: tester agent should allow skip conditions")
        self.assertFalse(integration_has_allow,
                         "Integration tester must NOT contain 'write with a skip condition' -- "
                         "it must prohibit skips, not allow them")


# ---------------------------------------------------------------------------
# AC-1(c): Instructs agent to read TESTING.md for boundary classifications
# ---------------------------------------------------------------------------

class TestACc_TestingMdBoundaryClassifications(unittest.TestCase):
    """AC-1(c): System prompt instructs reading TESTING.md for boundary info."""

    def setUp(self):
        _, self.body = _load_agent()

    def test_references_testing_md(self):
        self.assertIn("TESTING.md", self.body,
                       "System prompt must reference TESTING.md")

    def test_references_boundary_classifications(self):
        body_lower = self.body.lower()
        self.assertRegex(
            body_lower,
            r"boundar(y|ies).{0,30}classif",
            "System prompt must mention boundary classifications"
        )

    def test_instructs_reading_not_just_mentioning(self):
        """TESTING.md must be read, not just referenced in passing."""
        body_lower = self.body.lower()
        has_read_action = bool(re.search(
            r"(read|load|check|consult|parse|examine).{0,30}testing\.md",
            body_lower
        )) or bool(re.search(
            r"testing\.md.{0,30}(read|load|check|consult|parse|examine)",
            body_lower
        ))
        self.assertTrue(
            has_read_action,
            "System prompt must instruct the agent to READ TESTING.md, not just mention it"
        )


# ---------------------------------------------------------------------------
# AC-1(d): Adapt to project language via config.json and test conventions
# ---------------------------------------------------------------------------

class TestACd_AdaptToProjectLanguage(unittest.TestCase):
    """AC-1(d): System prompt instructs adapting to project language."""

    def setUp(self):
        _, self.body = _load_agent()
        self.body_lower = self.body.lower()

    def test_references_config_json(self):
        self.assertIn("config.json", self.body,
                       "System prompt must reference config.json")

    def test_instructs_reading_config_json(self):
        has_read = bool(re.search(
            r"(read|load|check|consult|parse|examine).{0,30}config\.json",
            self.body_lower
        )) or bool(re.search(
            r"config\.json.{0,30}(read|load|check|consult|parse|examine)",
            self.body_lower
        ))
        self.assertTrue(
            has_read,
            "System prompt must instruct reading config.json, not just mentioning it"
        )

    def test_references_existing_test_conventions(self):
        """Must instruct agent to look at existing test files/conventions."""
        has_conventions = bool(re.search(
            r"(existing|project).{0,30}(test|convention|pattern|style)",
            self.body_lower
        ))
        self.assertTrue(
            has_conventions,
            "System prompt must instruct adapting to existing test conventions"
        )

    def test_adapts_to_language_not_hardcoded(self):
        """Must instruct adapting to the project's language, not assume a specific one."""
        has_adapt = bool(re.search(
            r"(adapt|detect|discover|determine|identify).{0,40}(language|stack|framework|runtime)",
            self.body_lower
        )) or bool(re.search(
            r"(language|stack|framework|runtime).{0,40}(adapt|detect|discover|determine|identify)",
            self.body_lower
        ))
        self.assertTrue(
            has_adapt,
            "System prompt must instruct adapting to the project's language/stack"
        )


# ---------------------------------------------------------------------------
# AC-1(e): Structured output format matching specwright-tester's format
# ---------------------------------------------------------------------------

class TestACe_OutputFormatMatchesTester(unittest.TestCase):
    """AC-1(e): Output format matches specwright-tester's output format."""

    def setUp(self):
        _, self.body = _load_agent()
        self.tester_output = _load_tester_output_format()

    def test_has_output_format_section(self):
        self.assertRegex(
            self.body,
            r"## Output format",
            "System prompt must include an '## Output format' section"
        )

    def test_includes_test_files_heading(self):
        self.assertIn("Test file(s)", self.body,
                       "Output format must include 'Test file(s)' heading")

    def test_includes_coverage_map_heading(self):
        self.assertIn("Coverage map", self.body,
                       "Output format must include 'Coverage map' heading")

    def test_includes_edge_cases_heading(self):
        self.assertIn("Edge cases tested", self.body,
                       "Output format must include 'Edge cases tested' heading")

    def test_includes_test_type_rationale_heading(self):
        self.assertIn("Test type rationale", self.body,
                       "Output format must include 'Test type rationale' heading")

    def test_includes_weakness_audit_heading(self):
        self.assertIn("Weakness audit", self.body,
                       "Output format must include 'Weakness audit' heading")

    def test_all_tester_output_headings_present(self):
        """Cross-check: every heading in specwright-tester's output format must appear."""
        missing = [h for h in REQUIRED_OUTPUT_HEADINGS if h not in self.body]
        self.assertEqual(missing, [],
                         f"Output format is missing headings from specwright-tester: {missing}")


# ---------------------------------------------------------------------------
# AC-1(f): Tier-specific test strategies section
# ---------------------------------------------------------------------------

class TestACf_TierSpecificStrategies(unittest.TestCase):
    """AC-1(f): Tier-specific test strategies for integration, contract, and E2E."""

    def setUp(self):
        _, self.body = _load_agent()
        self.body_lower = self.body.lower()

    def test_has_tier_strategies_section(self):
        """Must have a section about tier-specific or test-type-specific strategies."""
        has_section = bool(re.search(
            r"##\s+.*(tier|strateg|test.type)",
            self.body_lower
        ))
        self.assertTrue(
            has_section,
            "System prompt must include a section header about tier-specific strategies"
        )

    # -- Integration tier --

    def test_integration_tier_mentions_real_infrastructure(self):
        """Integration tier must require real infrastructure."""
        has_real_infra = bool(re.search(
            r"integration.{0,100}real\s+(infrastructure|component|service|database|system)",
            self.body_lower
        )) or bool(re.search(
            r"real\s+(infrastructure|component|service|database|system).{0,100}integration",
            self.body_lower
        ))
        self.assertTrue(
            has_real_infra,
            "Integration tier strategy must mention real infrastructure"
        )

    def test_integration_tier_mentions_cross_component_data_flow(self):
        """Integration tier must mention cross-component data flow."""
        has_data_flow = bool(re.search(
            r"(cross.component|cross.service|cross.module|between\s+component).{0,60}(data\s+flow|flow|communicat|interact)",
            self.body_lower
        )) or bool(re.search(
            r"(data\s+flow|data.flows).{0,60}(cross.component|component|between)",
            self.body_lower
        ))
        self.assertTrue(
            has_data_flow,
            "Integration tier strategy must mention cross-component data flow"
        )

    # -- Contract tier --

    def test_contract_tier_mentions_interface_shapes(self):
        """Contract tier must mention interface shapes."""
        has_interface = bool(re.search(
            r"contract.{0,100}interface\s+(shape|definition|signature|schema|boundar)",
            self.body_lower
        )) or bool(re.search(
            r"interface\s+(shape|definition|signature|schema|boundar).{0,100}contract",
            self.body_lower
        ))
        self.assertTrue(
            has_interface,
            "Contract tier strategy must mention interface shapes"
        )

    def test_contract_tier_mentions_wire_formats(self):
        """Contract tier must mention wire formats."""
        has_wire = bool(re.search(
            r"contract.{0,100}wire\s+(format|protocol|schema)",
            self.body_lower
        )) or bool(re.search(
            r"wire\s+(format|protocol|schema).{0,100}contract",
            self.body_lower
        ))
        self.assertTrue(
            has_wire,
            "Contract tier strategy must mention wire formats"
        )

    # -- E2E tier --

    def test_e2e_tier_mentions_full_user_flows(self):
        """E2E tier must mention full user flows."""
        has_user_flow = bool(re.search(
            r"(e2e|end.to.end).{0,100}(full\s+user|user\s+flow|complete\s+flow|full\s+flow)",
            self.body_lower
        )) or bool(re.search(
            r"(full\s+user|user\s+flow|complete\s+flow|full\s+flow).{0,100}(e2e|end.to.end)",
            self.body_lower
        ))
        self.assertTrue(
            has_user_flow,
            "E2E tier strategy must mention full user flows"
        )

    def test_all_three_tiers_have_distinct_strategies(self):
        """All three tier strategies must be present -- not just one or two."""
        # Extract text after a "tier" or "strategies" header
        tier_section = re.search(
            r"##[^\n]*(tier|strateg|test.type)[^\n]*\n(.*?)(?:\n## |\Z)",
            self.body_lower, re.DOTALL
        )
        self.assertIsNotNone(tier_section,
                             "Must have a tier strategies section")
        assert tier_section is not None  # type narrowing for Pyright
        section_text = tier_section.group(2)

        has_integration = bool(re.search(r"integration", section_text))
        has_contract = bool(re.search(r"contract", section_text))
        has_e2e = bool(re.search(r"(e2e|end.to.end)", section_text))

        self.assertTrue(has_integration,
                        "Tier strategies section must cover integration")
        self.assertTrue(has_contract,
                        "Tier strategies section must cover contract")
        self.assertTrue(has_e2e,
                        "Tier strategies section must cover E2E")


# ---------------------------------------------------------------------------
# Cross-cutting: structural integrity
# ---------------------------------------------------------------------------

class TestStructuralIntegrity(unittest.TestCase):
    """Cross-cutting tests for file structure and consistency."""

    def setUp(self):
        self.frontmatter, self.body = _load_agent()

    def test_body_is_substantive(self):
        """System prompt must be substantive, not a trivially short placeholder."""
        # A real agent definition should be at least a few hundred words
        word_count = len(self.body.split())
        self.assertGreater(word_count, 150,
                           f"System prompt is too short ({word_count} words) to be substantive")

    def test_frontmatter_description_mentions_integration_testing(self):
        """Description should indicate this agent's purpose."""
        desc_lower = self.frontmatter["description"].lower()
        has_integration = "integration" in desc_lower
        has_testing = "test" in desc_lower
        self.assertTrue(
            has_integration and has_testing,
            f"Description should mention integration testing, got: {self.frontmatter['description']}"
        )

    def test_does_not_contain_tester_skip_allow_policy(self):
        """Must not copy the tester's policy of allowing t.Skip for infra."""
        # The tester says: "If infrastructure is unavailable, write with a skip condition"
        self.assertNotRegex(
            self.body,
            r"[Ii]f infrastructure is unavailable.*skip condition",
            "Must not contain the tester's skip-allowing policy"
        )

    def test_body_has_multiple_sections(self):
        """A well-structured agent file has multiple ## sections."""
        sections = re.findall(r"^## ", self.body, re.MULTILINE)
        self.assertGreaterEqual(
            len(sections), 4,
            f"Expected at least 4 sections (##), found {len(sections)}"
        )


if __name__ == "__main__":
    unittest.main()
