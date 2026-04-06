"""Tests for language-aligned building skills.

Covers:
  AC-1 to AC-5: Language pattern files exist with correct structure
  AC-6 to AC-8: sw-build context envelope includes language patterns
  AC-9: File names match config.json language values
"""

import os
import re
import unittest

_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_LANG_DIR = os.path.join(_REPO_ROOT, "core", "skills", "lang-building")
_SW_BUILD_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-build", "SKILL.md")

LANGUAGES = {
    "go": {"idioms": ["error handling", "interface"], "anti": True},
    "python": {"idioms": ["context manager", "type hint", "decorator"], "anti": True},
    "typescript": {"idioms": ["strict", "type narrow", "generic"], "anti": True},
    "rust": {"idioms": ["ownership", "borrow", "result", "option", "trait"], "anti": True},
    "java": {"idioms": ["optional", "stream", "record"], "anti": True},
}


def _load_lang(name):
    path = os.path.join(_LANG_DIR, f"{name}.md")
    with open(path, "r") as f:
        return f.read()


def _load_sw_build():
    with open(_SW_BUILD_PATH, "r") as f:
        return f.read()


# ===========================================================================
# AC-1 to AC-5: Language pattern files
# ===========================================================================

class TestLanguageFilesExist(unittest.TestCase):
    """All 5 language files must exist."""

    def test_go_exists(self):
        self.assertTrue(os.path.isfile(os.path.join(_LANG_DIR, "go.md")))

    def test_python_exists(self):
        self.assertTrue(os.path.isfile(os.path.join(_LANG_DIR, "python.md")))

    def test_typescript_exists(self):
        self.assertTrue(os.path.isfile(os.path.join(_LANG_DIR, "typescript.md")))

    def test_rust_exists(self):
        self.assertTrue(os.path.isfile(os.path.join(_LANG_DIR, "rust.md")))

    def test_java_exists(self):
        self.assertTrue(os.path.isfile(os.path.join(_LANG_DIR, "java.md")))


class TestLanguageFilesUnder300Lines(unittest.TestCase):
    """Each file must be under 300 lines."""

    def _check_lines(self, name):
        content = _load_lang(name)
        lines = content.count("\n") + 1
        self.assertLessEqual(lines, 300, f"{name}.md has {lines} lines (max 300)")

    def test_go(self):
        self._check_lines("go")

    def test_python(self):
        self._check_lines("python")

    def test_typescript(self):
        self._check_lines("typescript")

    def test_rust(self):
        self._check_lines("rust")

    def test_java(self):
        self._check_lines("java")


class TestNoYAMLFrontmatter(unittest.TestCase):
    """Files must NOT have YAML frontmatter (they are reference docs, not skills)."""

    def _check_no_frontmatter(self, name):
        content = _load_lang(name)
        self.assertFalse(
            content.startswith("---"),
            f"{name}.md must NOT start with YAML frontmatter '---'"
        )

    def test_go(self):
        self._check_no_frontmatter("go")

    def test_python(self):
        self._check_no_frontmatter("python")

    def test_typescript(self):
        self._check_no_frontmatter("typescript")

    def test_rust(self):
        self._check_no_frontmatter("rust")

    def test_java(self):
        self._check_no_frontmatter("java")


class TestLanguageIdiomsPresent(unittest.TestCase):
    """Each file must contain its language-specific idioms."""

    def _check_idioms(self, name, expected_terms):
        content = _load_lang(name).lower()
        for term in expected_terms:
            self.assertTrue(
                bool(re.search(re.escape(term), content)),
                f"{name}.md must mention '{term}'"
            )

    def test_go_idioms(self):
        self._check_idioms("go", LANGUAGES["go"]["idioms"])

    def test_python_idioms(self):
        self._check_idioms("python", LANGUAGES["python"]["idioms"])

    def test_typescript_idioms(self):
        self._check_idioms("typescript", LANGUAGES["typescript"]["idioms"])

    def test_rust_idioms(self):
        self._check_idioms("rust", LANGUAGES["rust"]["idioms"])

    def test_java_idioms(self):
        self._check_idioms("java", LANGUAGES["java"]["idioms"])


class TestAntiPatternsSection(unittest.TestCase):
    """Each file must have an anti-patterns section."""

    def _check_anti(self, name):
        content = _load_lang(name).lower()
        has_anti = bool(re.search(r"anti.pattern", content))
        self.assertTrue(has_anti, f"{name}.md must have an anti-patterns section")

    def test_go(self):
        self._check_anti("go")

    def test_python(self):
        self._check_anti("python")

    def test_typescript(self):
        self._check_anti("typescript")

    def test_rust(self):
        self._check_anti("rust")

    def test_java(self):
        self._check_anti("java")


class TestSubstantiveContent(unittest.TestCase):
    """Files must have substantive content (not just headings)."""

    def _check_substantive(self, name):
        content = _load_lang(name)
        word_count = len(content.split())
        self.assertGreater(
            word_count, 200,
            f"{name}.md has only {word_count} words (needs >200 for substantive content)"
        )

    def test_go(self):
        self._check_substantive("go")

    def test_python(self):
        self._check_substantive("python")

    def test_typescript(self):
        self._check_substantive("typescript")

    def test_rust(self):
        self._check_substantive("rust")

    def test_java(self):
        self._check_substantive("java")


# ===========================================================================
# AC-6 to AC-8: sw-build context envelope
# ===========================================================================

class TestSwBuildContextEnvelope(unittest.TestCase):
    """AC-6, AC-7: sw-build includes language patterns in context envelope."""

    def setUp(self):
        self.content = _load_sw_build()
        self.lower = self.content.lower()

    def test_mentions_lang_building(self):
        """Must reference lang-building directory."""
        has_ref = bool(re.search(r"lang-building", self.lower))
        self.assertTrue(has_ref, "sw-build must reference lang-building")

    def test_language_patterns_in_context_envelope(self):
        """Language patterns must be listed in the context envelope."""
        has_lang_in_env = bool(re.search(
            r"(context|envelope|delegat).{0,300}lang(uage)?.{0,40}pattern",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_lang_in_env, "Context envelope must include language patterns")

    def test_positioned_between_constitution_and_commands(self):
        """Language patterns must be between constitution and build commands."""
        # Find positions of constitution ref and build commands ref
        const_pos = self.lower.find("constitution")
        cmd_pos = self.lower.find("build and test commands")
        lang_pos = self.lower.find("lang-building")
        if const_pos >= 0 and cmd_pos >= 0 and lang_pos >= 0:
            self.assertGreater(lang_pos, const_pos,
                               "lang-building must appear after constitution in context envelope")
            self.assertLess(lang_pos, cmd_pos,
                            "lang-building must appear before build/test commands in context envelope")
        else:
            self.fail("Could not find positioning landmarks in context envelope")

    def test_deterministic_detection_rule(self):
        """Must specify deterministic language detection (languages[0] or file extension)."""
        has_rule = bool(re.search(
            r"(languages\[0\]|primary\s+language|project\.languages)",
            self.lower
        ))
        self.assertTrue(has_rule, "Must specify deterministic language detection rule")

    def test_skip_when_missing(self):
        """Must skip silently when language file doesn't exist."""
        has_skip = bool(re.search(
            r"(skip|absent|not\s+exist|unavailable).{0,60}(silent|graceful)",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"if.{0,40}(available|exist)",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_skip, "Must handle missing language files gracefully")


class TestSwBuildIntegrationStep(unittest.TestCase):
    """AC-8: INTEGRATION step also includes language patterns."""

    def setUp(self):
        self.content = _load_sw_build()
        self.lower = self.content.lower()

    def test_integration_step_mentions_language_patterns(self):
        """INTEGRATION step must include language patterns in its delegation."""
        # Find the INTEGRATION step section and check for language reference
        has_lang_in_int = bool(re.search(
            r"integration.{0,500}lang(uage)?.{0,40}pattern",
            self.lower, re.DOTALL
        )) or bool(re.search(
            r"lang(uage)?.{0,40}pattern.{0,500}integration",
            self.lower, re.DOTALL
        ))
        self.assertTrue(has_lang_in_int, "INTEGRATION step must reference language patterns")


# ===========================================================================
# AC-9: File names match config.json language values
# ===========================================================================

class TestFileNamesMatchConfigValues(unittest.TestCase):
    """AC-9: File names correspond to config.json project.languages values."""

    def test_standard_language_names(self):
        """Files use standard language names that would appear in config.json.
        Note: This intentionally hardcodes the expected set rather than reading
        config.json — the test validates that shipped files match the spec'd
        language set. Config.json coupling is the orchestrator's responsibility."""
        expected = {"go.md", "python.md", "typescript.md", "rust.md", "java.md"}
        actual = set(f for f in os.listdir(_LANG_DIR) if f.endswith(".md"))
        # Use issubset to allow future language additions without breaking this test
        self.assertTrue(
            expected.issubset(actual),
            f"Required language files missing. Expected at least {expected}, got {actual}"
        )


# ===========================================================================
# Document integrity
# ===========================================================================

class TestSwBuildIntegrity(unittest.TestCase):
    """Existing sw-build constraints preserved."""

    def setUp(self):
        self.content = _load_sw_build()

    def test_red_phase(self):
        self.assertIn("RED", self.content)

    def test_green_phase(self):
        self.assertIn("GREEN", self.content)

    def test_refactor_phase(self):
        self.assertIn("REFACTOR", self.content)

    def test_integration_step(self):
        self.assertIn("INTEGRATION", self.content)

    def test_regression_check(self):
        self.assertIn("REGRESSION CHECK", self.content)


if __name__ == "__main__":
    unittest.main()
