"""Tests for documentation updates reflecting the new integration tester agent.

RED phase: all tests must fail because delegation.md, DESIGN.md, and CLAUDE.md
have not yet been updated to include specwright-integration-tester.

This test suite covers:
  AC-6:    core/protocols/delegation.md agent roster table includes
           specwright-integration-tester with correct model, use case, constraint.
  AC-7(a): DESIGN.md reflects 7 agents (was 6).
  AC-7(b): DESIGN.md mentions the integration tester's role.
  AC-7(c): DESIGN.md references the tier tagging system in testing strategy.
  AC-8:    CLAUDE.md (adapters/claude-code/CLAUDE.md) reflects the new agent.

Done when all fail before implementation.
"""

import os
import re
import unittest


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_DELEGATION_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "delegation.md")
_DESIGN_PATH = os.path.join(_REPO_ROOT, "DESIGN.md")
_CLAUDE_MD_PATH = os.path.join(_REPO_ROOT, "adapters", "claude-code", "CLAUDE.md")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_file(path):
    """Load a file and return its content as a string."""
    with open(path, "r") as f:
        return f.read()


def _extract_table_rows(content, header_pattern):
    """Extract markdown table rows after a header matching header_pattern.

    Returns a list of row strings (excluding the header row and separator).
    """
    # Find the header
    match = re.search(header_pattern, content, re.MULTILINE)
    if not match:
        return []

    # Get text after the header
    after_header = content[match.end():]

    # Find the table: look for lines starting with |
    rows = []
    in_table = False
    for line in after_header.split("\n"):
        stripped = line.strip()
        if stripped.startswith("|"):
            in_table = True
            # Skip separator rows (|---|---|...)
            if re.match(r"^\|[\s\-:|]+\|$", stripped):
                continue
            rows.append(stripped)
        elif in_table:
            # We've left the table
            break
    return rows


def _parse_table_row(row):
    """Parse a markdown table row into a list of cell values (stripped).
    For '| a | b | c |', returns ['a', 'b', 'c']."""
    cells = row.split("|")
    # Remove empty first and last elements from leading/trailing |
    if cells and cells[0].strip() == "":
        cells = cells[1:]
    if cells and cells[-1].strip() == "":
        cells = cells[:-1]
    return [cell.strip() for cell in cells]


# ===========================================================================
# AC-6: delegation.md agent roster includes specwright-integration-tester
# ===========================================================================

class TestDelegationRosterEntry(unittest.TestCase):
    """AC-6: delegation.md Agent Roster table includes the integration tester."""

    def setUp(self):
        self.content = _load_file(_DELEGATION_PATH)
        self.rows = _extract_table_rows(self.content, r"^## Agent Roster")

    def test_roster_contains_integration_tester_row(self):
        """The roster table must have a row for specwright-integration-tester."""
        agent_names = []
        for row in self.rows:
            cells = _parse_table_row(row)
            if cells:
                agent_names.append(cells[0].strip())
        self.assertIn(
            "specwright-integration-tester",
            agent_names,
            f"Agent Roster must include specwright-integration-tester. "
            f"Found agents: {agent_names}"
        )

    def test_roster_has_seven_agent_rows(self):
        """The roster must have exactly 7 agent rows (was 6, +1 for integration tester)."""
        # Filter out the header row
        data_rows = [r for r in self.rows if not r.startswith("| Agent")]
        self.assertEqual(
            len(data_rows), 7,
            f"Expected 7 agent rows in roster, found {len(data_rows)}"
        )


class TestDelegationRosterModel(unittest.TestCase):
    """AC-6: specwright-integration-tester must have model: opus."""

    def setUp(self):
        self.content = _load_file(_DELEGATION_PATH)
        self.rows = _extract_table_rows(self.content, r"^## Agent Roster")
        self.agent_row = None
        for row in self.rows:
            if "specwright-integration-tester" in row:
                self.agent_row = row
                break

    def test_model_is_opus(self):
        """The model column for integration tester must be 'opus'."""
        self.assertIsNotNone(
            self.agent_row,
            "Cannot find specwright-integration-tester row in roster"
        )
        cells = _parse_table_row(self.agent_row)
        # Table columns: Agent | Model | Use for | Constraint
        # cells[0]=Agent, cells[1]=Model, cells[2]=Use for, cells[3]=Constraint
        self.assertTrue(
            len(cells) >= 4,
            f"Row must have at least 4 columns, got {len(cells)}: {self.agent_row}"
        )
        self.assertEqual(
            cells[1].strip(), "opus",
            f"Model must be 'opus', got '{cells[1].strip()}'"
        )


class TestDelegationRosterUseCase(unittest.TestCase):
    """AC-6: Use case must be 'Write integration/contract/E2E tests at boundaries'."""

    def setUp(self):
        self.content = _load_file(_DELEGATION_PATH)
        self.rows = _extract_table_rows(self.content, r"^## Agent Roster")
        self.agent_row = None
        for row in self.rows:
            if "specwright-integration-tester" in row:
                self.agent_row = row
                break

    def test_use_case_mentions_integration(self):
        """Use case must mention integration tests."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        use_case = cells[2].strip().lower()
        self.assertIn("integration", use_case,
                       f"Use case must mention 'integration', got: '{cells[2].strip()}'")

    def test_use_case_mentions_contract(self):
        """Use case must mention contract tests."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        use_case = cells[2].strip().lower()
        self.assertIn("contract", use_case,
                       f"Use case must mention 'contract', got: '{cells[2].strip()}'")

    def test_use_case_mentions_e2e(self):
        """Use case must mention E2E tests."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        use_case = cells[2].strip().lower()
        self.assertRegex(
            use_case, r"e2e|end.to.end",
            f"Use case must mention 'E2E' or 'end-to-end', got: '{cells[2].strip()}'"
        )

    def test_use_case_mentions_boundaries(self):
        """Use case must mention boundaries."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        use_case = cells[2].strip().lower()
        self.assertIn("boundar", use_case,
                       f"Use case must mention 'boundaries', got: '{cells[2].strip()}'")

    def test_use_case_exact_text(self):
        """Use case must match the specified text exactly."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        use_case = cells[2].strip()
        self.assertEqual(
            use_case,
            "Write integration/contract/E2E tests at boundaries",
            f"Use case text must match spec exactly, got: '{use_case}'"
        )


class TestDelegationRosterConstraint(unittest.TestCase):
    """AC-6: Constraint must be 'No skip conditions. No mocking internal boundaries.'"""

    def setUp(self):
        self.content = _load_file(_DELEGATION_PATH)
        self.rows = _extract_table_rows(self.content, r"^## Agent Roster")
        self.agent_row = None
        for row in self.rows:
            if "specwright-integration-tester" in row:
                self.agent_row = row
                break

    def test_constraint_mentions_no_skip(self):
        """Constraint must prohibit skip conditions."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        constraint = cells[3].strip().lower()
        self.assertIn("no skip", constraint,
                       f"Constraint must mention 'No skip', got: '{cells[3].strip()}'")

    def test_constraint_mentions_no_mocking_internal(self):
        """Constraint must prohibit mocking internal boundaries."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        constraint = cells[3].strip().lower()
        self.assertRegex(
            constraint,
            r"no mock.*internal",
            f"Constraint must mention 'No mocking internal boundaries', got: '{cells[3].strip()}'"
        )

    def test_constraint_exact_text(self):
        """Constraint must match the specified text exactly."""
        self.assertIsNotNone(self.agent_row, "Row not found")
        cells = _parse_table_row(self.agent_row)
        constraint = cells[3].strip()
        self.assertEqual(
            constraint,
            "No skip conditions. No mocking internal boundaries.",
            f"Constraint text must match spec exactly, got: '{constraint}'"
        )


# ===========================================================================
# AC-7: DESIGN.md updates
# ===========================================================================

class TestDesignAgentCount(unittest.TestCase):
    """AC-7(a): DESIGN.md reflects 7 agents (was 6)."""

    def setUp(self):
        self.content = _load_file(_DESIGN_PATH)

    def test_no_reference_to_6_agents(self):
        """DESIGN.md must not say '6 agents' anywhere."""
        matches = re.findall(r"6\s+agents", self.content)
        self.assertEqual(
            len(matches), 0,
            f"DESIGN.md still contains '6 agents' ({len(matches)} occurrences). "
            "Must be updated to 7."
        )

    def test_directory_structure_says_7_agents(self):
        """The directory structure comment must say '7 agents'."""
        # The specific line: │   └── agents/            # Custom subagent definitions (6 agents)
        match = re.search(
            r"agents/.*#.*?(\d+)\s+agents",
            self.content
        )
        self.assertIsNotNone(
            match,
            "Could not find agents/ line with agent count in directory structure"
        )
        assert match is not None
        count = int(match.group(1))
        self.assertEqual(
            count, 7,
            f"Directory structure agents count must be 7, got {count}"
        )

    def test_contains_7_agents_somewhere(self):
        """DESIGN.md must reference '7 agents' at least once."""
        self.assertRegex(
            self.content,
            r"7\s+agents",
            "DESIGN.md must contain '7 agents'"
        )


class TestDesignIntegrationTesterRole(unittest.TestCase):
    """AC-7(b): DESIGN.md mentions the integration tester's role."""

    def setUp(self):
        self.content = _load_file(_DESIGN_PATH)
        self.content_lower = self.content.lower()

    def test_mentions_integration_tester_agent(self):
        """DESIGN.md must mention the integration tester agent by name or role."""
        has_name = "specwright-integration-tester" in self.content
        has_role = bool(re.search(
            r"integration\s+tester", self.content_lower
        ))
        self.assertTrue(
            has_name or has_role,
            "DESIGN.md must mention the integration tester agent"
        )

    def test_integration_tester_in_testing_or_agent_context(self):
        """The mention must be in a testing or agent context, not incidental."""
        # Look for it near testing strategy, agents section, or TESTING.md description
        has_in_context = bool(re.search(
            r"(integrat\w+\s+tester|specwright-integration-tester).{0,200}"
            r"(boundar|test|agent|TESTING\.md)",
            self.content, re.DOTALL | re.IGNORECASE
        )) or bool(re.search(
            r"(boundar|test|agent|TESTING\.md).{0,200}"
            r"(integrat\w+\s+tester|specwright-integration-tester)",
            self.content, re.DOTALL | re.IGNORECASE
        ))
        self.assertTrue(
            has_in_context,
            "Integration tester mention must be in a testing/agent context"
        )

    def test_testing_md_description_updated(self):
        """The TESTING.md description should mention the integration tester agent
        alongside the existing 'tester agent' reference."""
        # Current text: "consumed by tester agent and gate-tests"
        # Should now also mention integration tester
        has_both = bool(re.search(
            r"(tester\s+agent|specwright-tester).{0,50}(integration.tester|specwright-integration-tester)",
            self.content, re.IGNORECASE
        )) or bool(re.search(
            r"(integration.tester|specwright-integration-tester).{0,50}(tester\s+agent|specwright-tester)",
            self.content, re.IGNORECASE
        ))
        self.assertTrue(
            has_both,
            "TESTING.md description should reference both tester and integration tester agents"
        )


class TestDesignTierTagging(unittest.TestCase):
    """AC-7(c): DESIGN.md references the tier tagging system."""

    def setUp(self):
        self.content = _load_file(_DESIGN_PATH)
        self.content_lower = self.content.lower()

    def test_mentions_tier_tagging(self):
        """DESIGN.md must reference tier tagging or tier classification."""
        has_tier = bool(re.search(
            r"tier\s+(tag|classif|annot)",
            self.content_lower
        ))
        self.assertTrue(
            has_tier,
            "DESIGN.md must mention tier tagging/classification/annotation"
        )

    def test_tier_in_testing_strategy_context(self):
        """Tier tagging must appear in the testing strategy context."""
        # The TESTING.md section or testing-strategy.md reference should mention tiers
        has_tier_in_testing = bool(re.search(
            r"(testing|TESTING\.md|testing.strategy).{0,150}tier",
            self.content, re.DOTALL | re.IGNORECASE
        )) or bool(re.search(
            r"tier.{0,150}(testing|TESTING\.md|testing.strategy)",
            self.content, re.DOTALL | re.IGNORECASE
        ))
        self.assertTrue(
            has_tier_in_testing,
            "Tier tagging must be referenced in a testing strategy context in DESIGN.md"
        )


# ===========================================================================
# AC-8: CLAUDE.md updates
# ===========================================================================

class TestClaudeMdAgentReference(unittest.TestCase):
    """AC-8: CLAUDE.md reflects the new agent."""

    def setUp(self):
        self.content = _load_file(_CLAUDE_MD_PATH)
        self.content_lower = self.content.lower()

    def test_mentions_integration_tester(self):
        """CLAUDE.md must reference the integration tester agent."""
        has_ref = (
            "specwright-integration-tester" in self.content
            or "integration tester" in self.content_lower
            or "integration-tester" in self.content_lower
        )
        self.assertTrue(
            has_ref,
            "CLAUDE.md must mention the integration tester agent"
        )

    def test_agents_section_updated(self):
        """The agents/ architecture description or any agent listing must
        reference integration testing capability."""
        # Look near the agents/ line or any agent-related section
        has_in_agents_context = bool(re.search(
            r"agents?.{0,100}integrat\w+.test",
            self.content_lower
        )) or bool(re.search(
            r"integrat\w+.test.{0,100}agents?",
            self.content_lower
        ))
        self.assertTrue(
            has_in_agents_context,
            "Agent listing in CLAUDE.md must reference integration testing"
        )


# ===========================================================================
# Cross-cutting: consistency between all three files
# ===========================================================================

class TestCrossFileConsistency(unittest.TestCase):
    """Verify consistency across delegation.md, DESIGN.md, and CLAUDE.md."""

    def setUp(self):
        self.delegation = _load_file(_DELEGATION_PATH)
        self.design = _load_file(_DESIGN_PATH)
        self.claude_md = _load_file(_CLAUDE_MD_PATH)

    def test_all_three_files_mention_integration_tester(self):
        """All three files must mention the integration tester."""
        for name, content in [
            ("delegation.md", self.delegation),
            ("DESIGN.md", self.design),
            ("CLAUDE.md", self.claude_md),
        ]:
            has_ref = (
                "specwright-integration-tester" in content
                or "integration-tester" in content.lower()
                or "integration tester" in content.lower()
            )
            self.assertTrue(
                has_ref,
                f"{name} must mention the integration tester"
            )

    def test_agent_count_consistent_between_delegation_and_design(self):
        """The number of agents in delegation.md roster must match DESIGN.md's count."""
        # Count roster rows in delegation.md
        rows = _extract_table_rows(self.delegation, r"^## Agent Roster")
        data_rows = [r for r in rows if not r.startswith("| Agent")]
        delegation_count = len(data_rows)

        # Extract count from DESIGN.md directory structure
        match = re.search(
            r"agents/.*#.*?(\d+)\s+agents",
            self.design
        )
        self.assertIsNotNone(match, "DESIGN.md must have agent count")
        assert match is not None
        design_count = int(match.group(1))

        self.assertEqual(
            delegation_count, design_count,
            f"Agent count mismatch: delegation.md has {delegation_count} rows, "
            f"DESIGN.md says {design_count} agents"
        )

    def test_delegation_model_matches_opus(self):
        """Double-check: the model in delegation.md for integration tester is opus,
        matching what the agent file itself specifies."""
        rows = _extract_table_rows(self.delegation, r"^## Agent Roster")
        for row in rows:
            if "specwright-integration-tester" in row:
                cells = _parse_table_row(row)
                self.assertEqual(cells[1].strip(), "opus",
                                 "Model in delegation roster must match agent definition (opus)")
                return
        self.fail("specwright-integration-tester not found in delegation.md roster")


if __name__ == "__main__":
    unittest.main()
