"""Regression coverage for Unit 04 support-surface status-card alignment."""

from pathlib import Path
import unittest

from evals.tests._text_helpers import load_text


ROOT_DIR = Path(__file__).resolve().parents[2]
STATUS_SKILL = ROOT_DIR / "core" / "skills" / "sw-status" / "SKILL.md"
DOCTOR_SKILL = ROOT_DIR / "core" / "skills" / "sw-doctor" / "SKILL.md"
INIT_SKILL = ROOT_DIR / "core" / "skills" / "sw-init" / "SKILL.md"
GUARD_SKILL = ROOT_DIR / "core" / "skills" / "sw-guard" / "SKILL.md"
AGENTS_DOC = ROOT_DIR / "AGENTS.md"
CLAUDE_DOC = ROOT_DIR / "CLAUDE.md"
CLAUDE_ADAPTER_DOC = ROOT_DIR / "adapters" / "claude-code" / "CLAUDE.md"
SUPPORT_SURFACE_SHELL = ROOT_DIR / "tests" / "test-support-surface-cutover-docs.sh"
CLAUDE_BUILD_TEST = ROOT_DIR / "tests" / "test-claude-code-build.sh"

COMMAND_EXPECTATIONS = {
    ROOT_DIR / "adapters" / "codex" / "commands" / "sw-status.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-adopt",
    ],
    ROOT_DIR / "adapters" / "codex" / "commands" / "sw-doctor.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-status --repair",
    ],
    ROOT_DIR / "adapters" / "codex" / "commands" / "sw-init.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-status",
    ],
    ROOT_DIR / "adapters" / "codex" / "commands" / "sw-guard.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-adopt",
    ],
    ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-status.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-adopt",
    ],
    ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-doctor.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-status --repair",
    ],
    ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-init.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-status",
    ],
    ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-guard.md": [
        ".specwright-local/",
        "git-admin",
        "/sw-adopt",
    ],
}


class TestSupportSkillVocabulary(unittest.TestCase):
    def test_support_skills_name_project_visible_runtime_and_explicit_adoption(self) -> None:
        expectations = {
            STATUS_SKILL: ["project-visible", ".specwright-local", "git-admin", "/sw-adopt"],
            DOCTOR_SKILL: ["project-visible", ".specwright-local", "git-admin", "/sw-adopt"],
            INIT_SKILL: ["project-visible", ".specwright-local", "git-admin", "/sw-status"],
            GUARD_SKILL: ["project-visible", ".specwright-local", "git-admin", "/sw-adopt"],
        }

        for path, phrases in expectations.items():
            text = load_text(path)
            for phrase in phrases:
                with self.subTest(path=path.name, phrase=phrase):
                    self.assertIn(phrase, text)


class TestCommandAndGuidanceSurfaceVocabulary(unittest.TestCase):
    def test_command_wrappers_call_out_runtime_roots_and_adoption_story(self) -> None:
        for path, phrases in COMMAND_EXPECTATIONS.items():
            text = load_text(path)
            for phrase in phrases:
                with self.subTest(path=path.name, phrase=phrase):
                    self.assertIn(phrase, text)

    def test_guidance_docs_name_runtime_default_and_status_entrypoint(self) -> None:
        expectations = {
            AGENTS_DOC: [".specwright-local/", "git-admin", "/sw-adopt", "/sw-status"],
            CLAUDE_DOC: [".specwright-local/", "git-admin", "/sw-adopt", "/sw-status"],
            CLAUDE_ADAPTER_DOC: [".specwright-local/", "git-admin", "/sw-adopt", "/sw-status"],
        }

        for path, phrases in expectations.items():
            text = load_text(path)
            for phrase in phrases:
                with self.subTest(path=path.name, phrase=phrase):
                    self.assertIn(phrase, text)


class TestPackagedSurfaceProof(unittest.TestCase):
    def test_support_surface_shell_covers_runtime_root_and_adoption_cutover(self) -> None:
        text = load_text(SUPPORT_SURFACE_SHELL)
        for phrase in (
            ".specwright-local/",
            "git-admin",
            "/sw-adopt",
            "/sw-status",
            "support-surface.runtime-root-adoption-cutover",
        ):
            with self.subTest(phrase=phrase):
                self.assertIn(phrase, text)

    def test_claude_build_harness_requires_runtime_root_adoption_coverage_marker(self) -> None:
        text = load_text(CLAUDE_BUILD_TEST)
        self.assertIn("tests/test-support-surface-cutover-docs.sh", text)
        self.assertIn("support-surface.runtime-root-adoption-cutover", text)


if __name__ == "__main__":
    unittest.main()
