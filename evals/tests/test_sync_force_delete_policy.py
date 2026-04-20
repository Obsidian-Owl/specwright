"""Regression coverage for Unit 04 — sw-sync force-delete policy."""

from pathlib import Path
import unittest

from evals.tests._text_helpers import assert_multiline_regex, load_text


ROOT_DIR = Path(__file__).resolve().parents[2]
SYNC_SKILL = ROOT_DIR / "core" / "skills" / "sw-sync" / "SKILL.md"
GIT_PROTOCOL = ROOT_DIR / "core" / "protocols" / "git.md"


class TestSyncForceDeleteClassification(unittest.TestCase):
    """AC-3: the branch classes stay explicit and deterministic."""

    def setUp(self):
        self.skill_text = load_text(SYNC_SKILL)
        self.git_text = load_text(GIT_PROTOCOL)

    def test_skill_covers_all_four_branch_classes(self):
        cases = (
            (
                "safe-delete",
                r"`safe-delete`[\s\S]{0,120}`git branch -d`",
            ),
            (
                "force-delete-candidate",
                r"`force-delete-candidate`[\s\S]{0,180}`\[gone\]`",
            ),
            (
                "protected",
                r"Never delete a branch that appears in that protection set|Never use `git branch -D` for merged-only, protected, invalid, or[\s\S]{0,40}live-session-owned branches",
            ),
            (
                "invalid-or-rejected",
                r"git check-ref-format --branch|Reject names that start with `-`, contain shell metacharacters or control[\s\S]{0,20}whitespace",
            ),
        )

        for case_name, pattern in cases:
            with self.subTest(case_name=case_name):
                assert_multiline_regex(self, self.skill_text, pattern)

    def test_force_delete_candidate_requires_gone_signal_and_second_confirmation(self):
        assert_multiline_regex(
            self,
            self.skill_text,
            r"`force-delete-candidate`[\s\S]{0,220}`\[gone\]`",
        )
        assert_multiline_regex(
            self,
            self.skill_text,
            r"explicit second confirmation[\s\S]{0,120}`git branch -D`",
        )

    def test_git_protocol_keeps_branch_d_as_default_cleanup_path(self):
        assert_multiline_regex(
            self,
            self.git_text,
            r"keep `git branch -d` as the default delete path",
        )

    def test_git_protocol_scopes_branch_d_override_to_gone_only(self):
        assert_multiline_regex(
            self,
            self.git_text,
            r"allow `git branch -D` only for branches flagged `\[gone\]`",
        )
        assert_multiline_regex(
            self,
            self.git_text,
            r"explicit second confirmation before any `\[gone\]`-only `git branch -D`",
        )

    def test_git_protocol_forbids_force_delete_for_rejected_classes(self):
        assert_multiline_regex(
            self,
            self.git_text,
            r"never use `git branch -D` for merged-only, protected, invalid, or[\s\S]{0,20}live-session-owned branches",
        )


if __name__ == "__main__":
    unittest.main()
