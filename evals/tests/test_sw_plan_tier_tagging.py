"""Tests for tier tagging and behavioral IC extensions in core/skills/sw-plan/SKILL.md.

RED phase: all tests must fail because the SKILL.md has not been extended yet.

This test suite covers:
  AC-4:    "Spec writing" constraint references protocols/testing-strategy.md for tier tagging
  AC-4(a): References testing-strategy.md by name (declarative pointer)
  AC-4(b): Mentions [tier: X] annotation format for ACs crossing TESTING.md boundaries
  AC-4(c): Does NOT contain procedural tier-selection logic (no if/then tier rules)
  AC-4(d): Protocol reference in Protocol References section
  AC-5:    "Integration criteria" constraint supports both structural IC-{n} and behavioral IC-B{n}
  AC-5(a): IC-B{n} format is defined alongside existing IC-{n} format
  AC-5(b): Behavioral ICs reference observable outputs (return values, state changes, events)
  AC-5(c): "Structurally verifiable" still applies to structural ICs (not removed)
  AC-5(d): spec-review validates IC-B quality
  AC-5(e): Both IC types written to integration-criteria.md

Done when all fail before implementation.
"""

import os
import re
import unittest


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_SKILL_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-plan", "SKILL.md")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_skill():
    """Load the sw-plan SKILL.md file content."""
    with open(_SKILL_PATH, "r") as f:
        return f.read()


def _extract_constraint_block(content, constraint_name):
    """Extract a constraint block by its bold heading.

    Constraint blocks in SKILL.md look like:
        **Constraint name (FREEDOM level):**
        ... content ...

    Returns the content from the bold heading through to the next **bold heading
    or ## heading. Returns None if not found.
    """
    # Match **Constraint name (anything):** through to the next constraint or section
    pattern = rf"\*\*{re.escape(constraint_name)}\s*\([^)]+\):\*\*\s*\n(.*?)(?=\n\*\*[A-Z]|\n## |\Z)"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        return match.group(0).strip()
    return None


def _require_constraint(content, constraint_name):
    """Extract constraint block, raising AssertionError if missing."""
    block = _extract_constraint_block(content, constraint_name)
    if block is None:
        raise AssertionError(
            f"Constraint block '**{constraint_name}**' must exist in SKILL.md"
        )
    return block


def _extract_section(content, heading):
    """Extract ## section content."""
    pattern = rf"^## {re.escape(heading)}\s*\n(.*?)(?=\n## |\Z)"
    match = re.search(pattern, content, re.MULTILINE | re.DOTALL)
    if match:
        return match.group(1).strip()
    return None


# ---------------------------------------------------------------------------
# AC-4: Spec writing constraint references testing-strategy.md for tier tagging
# ---------------------------------------------------------------------------

class TestAC4_SpecWritingReferencesTierTagging(unittest.TestCase):
    """AC-4: The 'Spec writing' constraint references testing-strategy.md for tier tagging."""

    def setUp(self):
        self.content = _load_skill()
        self.spec_writing = _require_constraint(self.content, "Spec writing")
        self.spec_writing_lower = self.spec_writing.lower()

    def test_spec_writing_references_testing_strategy_protocol(self):
        """AC-4(a): Must reference testing-strategy.md by path."""
        self.assertIn(
            "testing-strategy.md",
            self.spec_writing,
            "Spec writing constraint must reference protocols/testing-strategy.md"
        )

    def test_spec_writing_references_protocol_path_not_just_filename(self):
        """AC-4(a): Must use the full protocol path, not just the filename."""
        has_protocol_path = bool(re.search(
            r"protocols/testing-strategy\.md",
            self.spec_writing
        ))
        self.assertTrue(
            has_protocol_path,
            "Must reference 'protocols/testing-strategy.md' (full path), not just 'testing-strategy.md'"
        )

    def test_spec_writing_mentions_tier_annotation_format(self):
        """AC-4(b): Must mention [tier: X] annotation format."""
        has_tier_format = bool(re.search(
            r"\[tier:\s*\w+\]",
            self.spec_writing, re.IGNORECASE
        ))
        self.assertTrue(
            has_tier_format,
            "Spec writing constraint must mention [tier: X] annotation format"
        )

    def test_tier_annotation_tied_to_boundary_crossing(self):
        """AC-4(b): Tier tagging applies to ACs that cross boundaries classified in TESTING.md."""
        has_boundary_context = bool(re.search(
            r"(boundar|testing\.md).{0,80}\[?tier",
            self.spec_writing_lower
        )) or bool(re.search(
            r"tier.{0,80}(boundar|testing\.md)",
            self.spec_writing_lower
        ))
        self.assertTrue(
            has_boundary_context,
            "Tier tagging must be connected to boundary classifications in TESTING.md"
        )

    def test_no_procedural_tier_selection_logic(self):
        """AC-4(c): SKILL.md must NOT contain procedural tier-selection logic.

        The tier classification rules live in the protocol. The skill should
        only declaratively reference the protocol, not reproduce if/then rules
        for which tier to assign.
        """
        # Look for procedural patterns: if/when X then tier Y
        procedural_patterns = [
            r"if.{0,40}(internal|external|expensive).{0,40}(assign|use|tag|set).{0,20}(unit|integration|contract|e2e)",
            r"(internal|external|expensive)\s*(→|->|maps?\s+to|:)\s*(unit|integration|contract|e2e)",
            r"when.{0,30}boundary\s+is\s+(internal|external|expensive).{0,30}tier\s+(is|=|:)",
            r"\|\s*(internal|external|expensive)\s*\|.{0,30}(unit|integration|contract|e2e)\s*\|",
        ]
        for pattern in procedural_patterns:
            match = re.search(pattern, self.spec_writing_lower)
            self.assertIsNone(
                match,
                f"Spec writing must NOT contain procedural tier-selection logic. "
                f"Found: '{match.group(0) if match else ''}' matching pattern '{pattern}'. "
                f"Tier rules belong in the protocol, not the skill."
            )

    def test_no_tier_classification_rules_table(self):
        """AC-4(c): Must not contain a mapping table from boundaries to tiers."""
        # A table with boundary-to-tier mappings would be procedural
        has_mapping_table = bool(re.search(
            r"\|.*boundar.*\|.*tier.*\|",
            self.spec_writing_lower
        )) or bool(re.search(
            r"\|.*tier.*\|.*boundar.*\|",
            self.spec_writing_lower
        ))
        self.assertFalse(
            has_mapping_table,
            "Spec writing must not contain a boundary-to-tier mapping table. "
            "Tier classification rules belong in protocols/testing-strategy.md."
        )

    def test_reference_is_declarative_not_duplicative(self):
        """AC-4(c): The reference must be a pointer, not a reproduction of the protocol.

        Count how many distinct tier names appear in the spec writing block.
        If all four tiers (unit, integration, contract, e2e) are mentioned with
        classification rules, the skill is reproducing the protocol.
        """
        tier_mentions = {
            "unit": bool(re.search(r"\btier.*unit\b|\bunit.*tier\b", self.spec_writing_lower)),
            "integration": bool(re.search(r"\btier.*integration\b|\bintegration.*tier\b", self.spec_writing_lower)),
            "contract": bool(re.search(r"\btier.*contract\b|\bcontract.*tier\b", self.spec_writing_lower)),
            "e2e": bool(re.search(r"\btier.*(e2e|end.to.end)\b|\b(e2e|end.to.end).*tier\b", self.spec_writing_lower)),
        }
        # A declarative reference might mention 1-2 tiers as examples in [tier: X] format.
        # But if all 4 appear WITH classification context, the protocol is being duplicated.
        all_four_with_rules = all(tier_mentions.values())
        if all_four_with_rules:
            # Check if they have classification rules (not just mentioned in passing)
            has_rules = bool(re.search(
                r"(internal.{0,40}integration|external.{0,40}contract|expensive.{0,40}integration)",
                self.spec_writing_lower
            ))
            self.assertFalse(
                has_rules,
                "Spec writing reproduces tier classification rules that belong in the protocol. "
                "Use a declarative reference to protocols/testing-strategy.md instead."
            )

    def test_existing_spec_writing_content_preserved(self):
        """The existing spec writing content must not be removed."""
        # These are key phrases from the current spec writing block
        self.assertIn(
            "brutal tests",
            self.spec_writing_lower,
            "Original 'brutal tests' guidance must be preserved"
        )
        self.assertIn(
            "patterns.md",
            self.spec_writing_lower,
            "Original patterns.md reference must be preserved"
        )
        self.assertIn(
            "boundary conditions",
            self.spec_writing_lower,
            "Original 'boundary conditions' guidance must be preserved"
        )


class TestAC4_ProtocolReferencesSection(unittest.TestCase):
    """AC-4(d): testing-strategy.md should appear in Protocol References section."""

    def setUp(self):
        self.content = _load_skill()
        self.protocol_refs = _extract_section(self.content, "Protocol References")

    def test_protocol_references_section_exists(self):
        """Sanity: Protocol References section must exist."""
        self.assertIsNotNone(
            self.protocol_refs,
            "Protocol References section must exist in SKILL.md"
        )

    def test_testing_strategy_in_protocol_references(self):
        """testing-strategy.md must appear in the Protocol References section."""
        self.assertIsNotNone(self.protocol_refs)
        assert self.protocol_refs is not None
        self.assertIn(
            "testing-strategy.md",
            self.protocol_refs,
            "protocols/testing-strategy.md must be listed in Protocol References"
        )


# ---------------------------------------------------------------------------
# AC-5: Integration criteria supports structural and behavioral ICs
# ---------------------------------------------------------------------------

class TestAC5_BehavioralICFormatDefined(unittest.TestCase):
    """AC-5(a): IC-B{n} format is defined alongside IC-{n}."""

    def setUp(self):
        self.content = _load_skill()
        self.ic_block = _require_constraint(self.content, "Integration criteria")
        self.ic_lower = self.ic_block.lower()

    def test_ic_b_format_defined(self):
        """Must define IC-B{n} format for behavioral integration criteria."""
        has_ic_b = bool(re.search(r"IC-B\{?n\}?", self.ic_block)) or bool(
            re.search(r"IC-B\d", self.ic_block)
        )
        self.assertTrue(
            has_ic_b,
            "Integration criteria must define IC-B{n} format for behavioral ICs"
        )

    def test_ic_b_format_is_checklist_item(self):
        """IC-B{n} must use the checklist format like IC-{n}."""
        # Look for: - [ ] IC-B{n}: ...
        has_checklist = bool(re.search(
            r"-\s*\[\s*\]\s*IC-B\{n\}:",
            self.ic_block
        ))
        self.assertTrue(
            has_checklist,
            "IC-B{n} must use checklist format: '- [ ] IC-B{n}: {description}'"
        )

    def test_original_ic_format_still_present(self):
        """Original IC-{n} format must still be defined."""
        # Must have IC-{n} that is NOT IC-B{n}
        has_structural_ic = bool(re.search(
            r"IC-\{?n\}?(?!.*B)",
            self.ic_block
        )) or bool(re.search(
            r"-\s*\[\s*\]\s*IC-\d+:",
            self.ic_block
        ))
        self.assertTrue(
            has_structural_ic,
            "Original IC-{n} structural format must still be defined"
        )

    def test_both_formats_coexist(self):
        """Both IC-{n} and IC-B{n} formats must be present in the same block."""
        has_structural = bool(re.search(r"IC-\{?n\}?[^B]|IC-\d+[^B]", self.ic_block))
        has_behavioral = bool(re.search(r"IC-B", self.ic_block))
        self.assertTrue(
            has_structural and has_behavioral,
            f"Both IC-{{n}} (structural={has_structural}) and IC-B{{n}} "
            f"(behavioral={has_behavioral}) must coexist"
        )

    def test_ic_b_has_concrete_example(self):
        """IC-B format must include a concrete example, not just an abstract template."""
        # Look for an example that shows what a behavioral IC actually looks like
        # The example should reference observable outputs, not just say "IC-B{n}"
        has_example = bool(re.search(
            r"IC-B\d.*?:",
            self.ic_block
        )) or bool(re.search(
            r"(example|e\.g\.|valid).{0,40}IC-B",
            self.ic_lower
        ))
        self.assertTrue(
            has_example,
            "IC-B format must include a concrete example (like IC-B1: ...) "
            "not just an abstract template"
        )


class TestAC5_BehavioralICReferencesObservables(unittest.TestCase):
    """AC-5(b): Behavioral ICs reference observable outputs."""

    def setUp(self):
        self.content = _load_skill()
        self.ic_block = _require_constraint(self.content, "Integration criteria")
        self.ic_lower = self.ic_block.lower()

    def test_behavioral_ics_reference_observable_outputs(self):
        """IC-B must reference observable outputs, not structural properties."""
        observable_terms = [
            r"return\s+value",
            r"state\s+change",
            r"emit(ted|s)?\s+event",
            r"observable\s+output",
            r"observable",
        ]
        has_observable = any(
            bool(re.search(term, self.ic_lower)) for term in observable_terms
        )
        self.assertTrue(
            has_observable,
            "Behavioral ICs must reference observable outputs "
            "(return values, state changes, emitted events)"
        )

    def test_behavioral_distinct_from_structural(self):
        """Behavioral ICs must be explicitly distinguished from structural ICs.

        The block must explain WHY there are two types, or at minimum
        contrast them (structural = file paths/exports, behavioral = observable outputs).
        """
        has_distinction = bool(re.search(
            r"(structural|IC-\{?n\}?).{0,120}(behavioral|IC-B)",
            self.ic_lower
        )) or bool(re.search(
            r"(behavioral|IC-B).{0,120}(structural|IC-\{?n\}?)",
            self.ic_lower
        ))
        self.assertTrue(
            has_distinction,
            "Must explicitly distinguish structural ICs from behavioral ICs"
        )

    def test_behavioral_does_not_reference_file_paths_as_requirement(self):
        """Behavioral IC definition must NOT require file paths or import relationships.

        Those are structural properties. Behavioral ICs are about observable outcomes.
        The definition/description of IC-B should not say 'reference specific module paths'.
        """
        # Find text specifically about IC-B / behavioral ICs
        ic_b_context = re.search(
            r"(behavioral|IC-B).{0,300}",
            self.ic_lower, re.DOTALL
        )
        if ic_b_context:
            ic_b_text = ic_b_context.group(0)
            requires_paths = bool(re.search(
                r"(must|require|shall).{0,40}(module path|file path|import relationship|export name)",
                ic_b_text
            ))
            self.assertFalse(
                requires_paths,
                "Behavioral IC definition must not require file paths or imports -- "
                "those are structural properties"
            )


class TestAC5_StructurallyVerifiablePreserved(unittest.TestCase):
    """AC-5(c): 'Structurally verifiable' requirement still applies to structural ICs."""

    def setUp(self):
        self.content = _load_skill()
        self.ic_block = _require_constraint(self.content, "Integration criteria")
        self.ic_lower = self.ic_block.lower()

    def test_structurally_verifiable_still_present(self):
        """The phrase 'structurally verifiable' must still appear."""
        self.assertIn(
            "structurally verifiable",
            self.ic_lower,
            "'Structurally verifiable' requirement must be preserved"
        )

    def test_structurally_verifiable_applies_to_structural_ics(self):
        """'Structurally verifiable' must be scoped to structural ICs, not all ICs."""
        # After adding behavioral ICs, the "structurally verifiable" rule should
        # apply specifically to structural ICs (IC-{n}), not universally to all ICs.
        # Look for scoping language connecting structural/IC-{n} to the verifiable requirement.
        has_scoped = bool(re.search(
            r"(structural|IC-\{?n\}?).{0,80}structurally verifiable",
            self.ic_lower
        )) or bool(re.search(
            r"structurally verifiable.{0,80}(structural|IC-\{?n\}?)",
            self.ic_lower
        ))
        self.assertTrue(
            has_scoped,
            "'Structurally verifiable' must be scoped to structural ICs (IC-{n}), "
            "not applied universally to all ICs including behavioral ones"
        )

    def test_structural_ic_still_requires_module_paths(self):
        """Structural ICs must still reference module paths, export names, etc."""
        has_paths = bool(re.search(
            r"module\s+path|export\s+name|import\s+relationship",
            self.ic_lower
        ))
        self.assertTrue(
            has_paths,
            "Structural ICs must still require module paths, export names, "
            "or import relationships"
        )

    def test_structural_example_preserved(self):
        """The existing structural IC example should be preserved or equivalent."""
        # Current example: "Module `src/routes/index.ts` imports handler from..."
        has_example = bool(re.search(
            r"(example|e\.g\.).{0,60}(module|import|src/)",
            self.ic_lower
        ))
        self.assertTrue(
            has_example,
            "Structural IC must retain a concrete example showing module/import verification"
        )


class TestAC5_SpecReviewValidatesICB(unittest.TestCase):
    """AC-5(d): spec-review validates IC-B quality."""

    def setUp(self):
        self.content = _load_skill()
        self.ic_block = _require_constraint(self.content, "Integration criteria")
        self.ic_lower = self.ic_block.lower()

    def test_spec_review_validates_ic_b(self):
        """spec-review must be mentioned in context of IC-B validation."""
        has_spec_review = bool(re.search(
            r"spec.review.{0,80}IC-B",
            self.ic_lower
        )) or bool(re.search(
            r"IC-B.{0,80}spec.review",
            self.ic_lower
        )) or bool(re.search(
            r"spec.review.{0,80}behavioral",
            self.ic_lower
        )) or bool(re.search(
            r"behavioral.{0,80}spec.review",
            self.ic_lower
        ))
        self.assertTrue(
            has_spec_review,
            "spec-review must validate IC-B (behavioral IC) quality"
        )

    def test_spec_review_reference_is_about_quality_validation(self):
        """spec-review mention must be about validation/quality, not incidental."""
        has_quality_context = bool(re.search(
            r"spec.review.{0,60}(validat|qualit|review|check|verif)",
            self.ic_lower
        )) or bool(re.search(
            r"(validat|qualit|review|check|verif).{0,60}spec.review",
            self.ic_lower
        ))
        self.assertTrue(
            has_quality_context,
            "spec-review reference must be about validation/quality of IC-B, "
            "not an incidental mention"
        )


class TestAC5_BothTypesWrittenToIntegrationCriteria(unittest.TestCase):
    """AC-5(e): Both IC types written to integration-criteria.md."""

    def setUp(self):
        self.content = _load_skill()
        self.ic_block = _require_constraint(self.content, "Integration criteria")
        self.ic_lower = self.ic_block.lower()

    def test_integration_criteria_md_still_referenced(self):
        """integration-criteria.md must still be the output file."""
        self.assertIn(
            "integration-criteria.md",
            self.ic_block,
            "Both IC types must be written to integration-criteria.md"
        )

    def test_both_types_go_to_same_file(self):
        """Both structural and behavioral ICs must go to integration-criteria.md.

        Guard against an implementation that puts IC-B in a separate file.
        """
        # The block should NOT introduce a separate file for behavioral ICs
        separate_file_patterns = [
            r"behavioral.{0,60}(separate|different|new)\s+file",
            r"IC-B.{0,60}(separate|different|new)\s+file",
            r"behavioral-criteria\.md",
            r"behavioral-integration\.md",
        ]
        for pattern in separate_file_patterns:
            match = re.search(pattern, self.ic_lower)
            self.assertIsNone(
                match,
                f"Behavioral ICs must NOT go to a separate file. "
                f"Found: '{match.group(0) if match else ''}'"
            )


# ---------------------------------------------------------------------------
# Cross-cutting: SKILL.md stays declarative
# ---------------------------------------------------------------------------

class TestDeclarativeInvariant(unittest.TestCase):
    """Charter invariant: SKILL.md files define goals and constraints, never procedures."""

    def setUp(self):
        self.content = _load_skill()
        self.spec_writing = _require_constraint(self.content, "Spec writing")

    def test_spec_writing_does_not_contain_step_by_step(self):
        """Must not contain step-by-step instructions for tier assignment."""
        step_patterns = [
            r"step\s+\d",
            r"first,?\s+.{0,40}then",
            r"1\.\s+(check|read|look|scan).{0,40}testing\.md",
            r"for\s+each\s+(ac|criterion).{0,40}(check|determine|look\s+up)",
        ]
        spec_lower = self.spec_writing.lower()
        for pattern in step_patterns:
            match = re.search(pattern, spec_lower)
            self.assertIsNone(
                match,
                f"Spec writing must not contain procedural steps. "
                f"Found: '{match.group(0) if match else ''}'"
            )

    def test_no_algorithm_for_tier_assignment(self):
        """Must not describe an algorithm for determining tier values."""
        algo_patterns = [
            r"(check|scan|read)\s+testing\.md.{0,60}(assign|tag|annotate)\s+\[?tier",
            r"look\s+up.{0,40}boundary.{0,40}(assign|tag|set)\s+tier",
            r"(iterate|loop|for\s+each).{0,40}(ac|criterion|criteria).{0,40}tier",
        ]
        spec_lower = self.spec_writing.lower()
        for pattern in algo_patterns:
            match = re.search(pattern, spec_lower)
            self.assertIsNone(
                match,
                f"Spec writing must not describe a tier assignment algorithm. "
                f"Found: '{match.group(0) if match else ''}'"
            )


# ---------------------------------------------------------------------------
# Cross-cutting: document integrity
# ---------------------------------------------------------------------------

class TestDocumentIntegrity(unittest.TestCase):
    """Existing structure must not be broken by modifications."""

    def setUp(self):
        self.content = _load_skill()

    def test_all_original_constraints_preserved(self):
        """All pre-existing constraint blocks must still exist."""
        required_constraints = [
            "Stage boundary",
            "Pre-condition check",
            "Decompose",
            "Integration criteria",
            "Spec writing",
            "Spec per-unit loop",
            "Spec pre-review",
            "Code budget",
            "Gate handoff",
            "State mutations",
        ]
        for constraint_name in required_constraints:
            block = _extract_constraint_block(self.content, constraint_name)
            self.assertIsNotNone(
                block,
                f"Constraint block '**{constraint_name}**' must still exist"
            )

    def test_frontmatter_preserved(self):
        """YAML frontmatter must still be present."""
        self.assertTrue(
            self.content.startswith("---\n"),
            "YAML frontmatter must be preserved"
        )

    def test_goal_section_preserved(self):
        """## Goal section must still exist."""
        self.assertIn("## Goal", self.content)

    def test_inputs_section_preserved(self):
        """## Inputs section must still exist."""
        self.assertIn("## Inputs", self.content)

    def test_outputs_section_preserved(self):
        """## Outputs section must still exist."""
        self.assertIn("## Outputs", self.content)

    def test_failure_modes_preserved(self):
        """## Failure Modes section must still exist."""
        self.assertIn("## Failure Modes", self.content)

    def test_integration_criteria_still_multi_unit_only(self):
        """IC constraint must still specify it is multi-unit only."""
        ic_block = _require_constraint(self.content, "Integration criteria")
        self.assertIn(
            "multi-unit",
            ic_block.lower(),
            "Integration criteria must still specify multi-unit only"
        )

    def test_integration_criteria_re_entry_behavior_preserved(self):
        """Re-entry/replanning behavior for ICs must be preserved."""
        ic_block = _require_constraint(self.content, "Integration criteria")
        self.assertIn(
            "re-entry",
            ic_block.lower(),
            "Re-entry/replanning behavior must be preserved"
        )

    def test_gate_wiring_consumption_preserved(self):
        """gate-wiring consumption note must be preserved."""
        ic_block = _require_constraint(self.content, "Integration criteria")
        self.assertIn(
            "gate-wiring",
            ic_block.lower(),
            "gate-wiring consumption note must be preserved"
        )


if __name__ == "__main__":
    unittest.main()
