"""Contract tests for Unit 02 - worktree ownership and adoption contract.

Task 1 starts with the protocol and lifecycle-skill surface. Later tasks extend
the module with runtime proofs for live-owner detection and subordinate-session
boundaries.
"""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from evals.framework.git_env import sanitized_git_env
from evals.tests._text_helpers import assert_multiline_regex, load_text


ROOT_DIR = Path(__file__).resolve().parents[2]
STATE_PROTOCOL = ROOT_DIR / "core" / "protocols" / "state.md"
PARALLEL_PROTOCOL = ROOT_DIR / "core" / "protocols" / "parallel-build.md"
STATE_PATHS_MODULE = ROOT_DIR / "adapters" / "shared" / "specwright-state-paths.mjs"

SW_DESIGN_SKILL = ROOT_DIR / "core" / "skills" / "sw-design" / "SKILL.md"
SW_PLAN_SKILL = ROOT_DIR / "core" / "skills" / "sw-plan" / "SKILL.md"
SW_BUILD_SKILL = ROOT_DIR / "core" / "skills" / "sw-build" / "SKILL.md"
SW_VERIFY_SKILL = ROOT_DIR / "core" / "skills" / "sw-verify" / "SKILL.md"
SW_SHIP_SKILL = ROOT_DIR / "core" / "skills" / "sw-ship" / "SKILL.md"
SW_STATUS_SKILL = ROOT_DIR / "core" / "skills" / "sw-status" / "SKILL.md"
SW_ADOPT_SKILL = ROOT_DIR / "core" / "skills" / "sw-adopt" / "SKILL.md"

LIFECYCLE_SKILLS = {
    "sw-design": SW_DESIGN_SKILL,
    "sw-plan": SW_PLAN_SKILL,
    "sw-build": SW_BUILD_SKILL,
    "sw-verify": SW_VERIFY_SKILL,
    "sw-ship": SW_SHIP_SKILL,
    "sw-status": SW_STATUS_SKILL,
}


def _run(args: list[str], cwd: Path, *, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    runtime_env = None
    if env is not None:
        runtime_env = sanitized_git_env(env)
    elif args and args[0] == "git":
        runtime_env = sanitized_git_env()

    return subprocess.run(
        args,
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
        env=runtime_env,
    )


def _run_node_json(repo_path: Path, script: str) -> dict:
    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        check=False,
        cwd=repo_path,
        env=sanitized_git_env({"STATE_PATHS_MODULE": str(STATE_PATHS_MODULE)}),
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "node execution failed")
    return json.loads(result.stdout)


def _init_git_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _run(["git", "init"], cwd=path)
    _run(["git", "config", "user.name", "Specwright Tests"], cwd=path)
    _run(["git", "config", "user.email", "specwright-tests@example.com"], cwd=path)
    _run(["git", "branch", "-M", "main"], cwd=path)
    (path / "README.md").write_text("fixture\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=path)
    _run(["git", "commit", "-m", "chore: init fixture"], cwd=path)


def _git_path(repo_path: Path, *args: str) -> Path:
    output = _run(["git", *args], cwd=repo_path).stdout.strip()
    candidate = Path(output)
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo_path / candidate).resolve()


def _derive_worktree_id(git_dir: Path, git_common_dir: Path) -> str:
    if git_dir == git_common_dir:
        return "main-worktree"

    if git_dir.parent == git_common_dir / "worktrees" and git_dir.name and git_dir.name != "main-worktree":
        return git_dir.name

    if git_dir.name and git_dir.name not in {".git", "main-worktree"}:
        return git_dir.name

    raise AssertionError("unable to derive worktree id for fixture")


def _runtime_roots(repo_path: Path) -> dict[str, Path | str]:
    git_dir = _git_path(repo_path, "rev-parse", "--path-format=absolute", "--git-dir")
    git_common_dir = _git_path(repo_path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return {
        "gitDir": git_dir,
        "gitCommonDir": git_common_dir,
        "repoStateRoot": git_common_dir / "specwright",
        "worktreeStateRoot": git_dir / "specwright",
        "worktreeId": _derive_worktree_id(git_dir, git_common_dir),
    }


def _write_shared_config(repo_path: Path) -> None:
    roots = _runtime_roots(repo_path)
    config_path = Path(roots["repoStateRoot"]) / "config.json"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text('{\n  "version": "2.0"\n}\n', encoding="utf-8")


def _write_workflow(
    repo_path: Path,
    *,
    work_id: str,
    status: str,
    branch: str,
    unit_id: str,
    owner_worktree_id: str,
) -> None:
    roots = _runtime_roots(repo_path)
    workflow_path = Path(roots["repoStateRoot"]) / "work" / work_id / "workflow.json"
    workflow_path.parent.mkdir(parents=True, exist_ok=True)
    workflow_path.write_text(
        json.dumps(
            {
                "version": "3.0",
                "id": work_id,
                "status": status,
                "workDir": f"work/{work_id}",
                "unitId": unit_id,
                "tasksCompleted": [],
                "tasksTotal": 3,
                "branch": branch,
                "attachment": {
                    "worktreeId": owner_worktree_id,
                    "mode": "top-level",
                },
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def _write_session(
    repo_path: Path,
    *,
    worktree_id: str,
    branch: str,
    work_id: str,
    mode: str = "top-level",
    worktree_path: str | None = None,
) -> None:
    roots = _runtime_roots(repo_path)
    session_path = Path(roots["worktreeStateRoot"]) / "session.json"
    session_path.parent.mkdir(parents=True, exist_ok=True)
    session_path.write_text(
        json.dumps(
            {
                "version": "3.0",
                "worktreeId": worktree_id,
                "worktreePath": worktree_path or str(repo_path.resolve()),
                "branch": branch,
                "attachedWorkId": work_id,
                "mode": mode,
                "lastSeenAt": "2026-04-21T00:00:00Z",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def _inspect_ownership(repo_path: Path) -> dict:
    return _run_node_json(
        repo_path,
        """
        const {
          buildStatusView,
          findSelectedWorkOwnerConflict,
          loadSpecwrightState
        } = await import(process.env.STATE_PATHS_MODULE);

        const state = loadSpecwrightState({ cwd: process.cwd() });
        process.stdout.write(JSON.stringify({
          ownerConflict: findSelectedWorkOwnerConflict(state, { cwd: process.cwd() }),
          statusView: buildStatusView(state, { cwd: process.cwd() })
        }));
        """,
    )


class TestStateProtocolOwnershipContract(unittest.TestCase):
    """Task 1 RED: the protocol must define explicit ownership and adoption."""

    def setUp(self) -> None:
        self.state_text = load_text(STATE_PROTOCOL)

    def test_session_json_is_declared_live_ownership_truth(self) -> None:
        assert_multiline_regex(
            self,
            self.state_text,
            r"session\.json[\s\S]{0,180}live ownership truth|"
            r"live ownership truth[\s\S]{0,180}session\.json",
        )

    def test_same_work_adoption_is_explicit_not_branch_takeover(self) -> None:
        assert_multiline_regex(
            self,
            self.state_text,
            r"explicit same-work adoption[\s\S]{0,220}not[\s\S]{0,80}"
            r"implicit branch(?:-based)? takeover|"
            r"implicit branch(?:-based)? takeover[\s\S]{0,220}"
            r"explicit same-work adoption",
        )

    def test_subordinate_sessions_cannot_rewrite_other_worktree_sessions(self) -> None:
        self.assertIn("rewrite another worktree's `session.json`", self.state_text)


class TestParallelBuildSubordinateBoundaries(unittest.TestCase):
    """Task 1 RED: helper worktrees must stay subordinate-only."""

    def setUp(self) -> None:
        self.parallel_text = load_text(PARALLEL_PROTOCOL)

    def test_parallel_build_keeps_parent_session_as_only_top_level_owner(self) -> None:
        assert_multiline_regex(
            self,
            self.parallel_text,
            r"only top-level owner|never creates a second top-level owner",
        )

    def test_parallel_build_forbids_shared_workflow_mutation_from_helpers(self) -> None:
        assert_multiline_regex(
            self,
            self.parallel_text,
            r"must not[\s\S]{0,140}mutate shared workflow state|"
            r"shared workflow state[\s\S]{0,140}parent-only",
        )


class TestLifecycleSkillOwnershipStops(unittest.TestCase):
    """Task 2 RED: lifecycle skills must point to explicit adoption."""

    def test_lifecycle_skills_reference_explicit_sw_adopt_flow(self) -> None:
        for skill_name, path in LIFECYCLE_SKILLS.items():
            with self.subTest(skill_name=skill_name):
                text = load_text(path)
                assert_multiline_regex(
                    self,
                    text,
                    r"another live top-level worktree|other live top-level worktree|owned elsewhere",
                )
                self.assertIn("/sw-adopt", text)


class TestSwAdoptSkillContract(unittest.TestCase):
    """Task 1 RED: /sw-adopt must exist as an explicit current-worktree flow."""

    def setUp(self) -> None:
        self.assertTrue(SW_ADOPT_SKILL.exists(), "sw-adopt skill must exist")
        self.skill_text = load_text(SW_ADOPT_SKILL)

    def test_skill_frontmatter_names_sw_adopt(self) -> None:
        self.assertIn("name: sw-adopt", self.skill_text)

    def test_skill_attaches_only_current_worktree_session(self) -> None:
        assert_multiline_regex(
            self,
            self.skill_text,
            r"attach(?:es)? only the current worktree|current worktree session only",
        )

    def test_skill_validates_live_dead_state_and_branch_consistency(self) -> None:
        assert_multiline_regex(
            self,
            self.skill_text,
            r"live-versus-dead session state|live versus dead session state",
        )
        assert_multiline_regex(
            self,
            self.skill_text,
            r"branch consistency|recorded branch",
        )

    def test_skill_never_rewrites_another_worktree_session(self) -> None:
        self.assertIn("never rewrites another worktree's `session.json`", self.skill_text)


class TestRuntimeOwnershipHelpers(unittest.TestCase):
    """Task 3 GREEN: preserve runtime proofs for live/dead ownership rules."""

    def test_live_top_level_owner_conflict_survives_branch_match(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            primary = Path(tmpdir) / "primary"
            linked = Path(tmpdir) / "linked"
            _init_git_repo(primary)
            _run(
                [
                    "git",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "worktree",
                    "add",
                    "-q",
                    "-b",
                    "linked-branch",
                    str(linked),
                    "HEAD",
                ],
                cwd=primary,
            )

            _write_shared_config(primary)
            _write_workflow(
                primary,
                work_id="work-shared",
                status="building",
                branch="shared-branch",
                unit_id="unit-shared",
                owner_worktree_id="main-worktree",
            )
            _write_session(
                primary,
                worktree_id="main-worktree",
                branch="shared-branch",
                work_id="work-shared",
            )
            _write_session(
                linked,
                worktree_id="linked-branch",
                branch="shared-branch",
                work_id="work-shared",
            )

            ownership = _inspect_ownership(linked)
            self.assertEqual(ownership["ownerConflict"]["workId"], "work-shared")
            self.assertEqual(ownership["ownerConflict"]["ownerWorktreeId"], "main-worktree")

    def test_subordinate_session_does_not_claim_top_level_ownership(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            primary = Path(tmpdir) / "primary"
            linked = Path(tmpdir) / "linked"
            _init_git_repo(primary)
            _run(
                [
                    "git",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "worktree",
                    "add",
                    "-q",
                    "-b",
                    "linked-helper",
                    str(linked),
                    "HEAD",
                ],
                cwd=primary,
            )

            _write_shared_config(primary)
            _write_workflow(
                primary,
                work_id="work-shared",
                status="building",
                branch="main",
                unit_id="unit-shared",
                owner_worktree_id="main-worktree",
            )
            _write_session(
                primary,
                worktree_id="main-worktree",
                branch="main",
                work_id="work-shared",
            )
            _write_session(
                linked,
                worktree_id="linked-helper",
                branch="specwright-wt-task-1",
                work_id="work-shared",
                mode="subordinate",
            )

            ownership = _inspect_ownership(primary)
            self.assertIsNone(ownership["ownerConflict"])

    def test_dead_top_level_session_becomes_stale_attachment_not_live_owner(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            primary = Path(tmpdir) / "primary"
            linked = Path(tmpdir) / "linked"
            _init_git_repo(primary)
            _run(
                [
                    "git",
                    "-c",
                    "core.hooksPath=/dev/null",
                    "worktree",
                    "add",
                    "-q",
                    "-b",
                    "linked-dead",
                    str(linked),
                    "HEAD",
                ],
                cwd=primary,
            )

            _write_shared_config(primary)
            _write_workflow(
                primary,
                work_id="work-shared",
                status="building",
                branch="main",
                unit_id="unit-shared",
                owner_worktree_id="main-worktree",
            )
            _write_session(
                primary,
                worktree_id="main-worktree",
                branch="main",
                work_id="work-shared",
            )
            _write_session(
                linked,
                worktree_id="linked-dead",
                branch="linked-dead",
                work_id="work-shared",
                worktree_path=str(linked / "missing-worktree"),
            )

            ownership = _inspect_ownership(primary)
            self.assertIsNone(ownership["ownerConflict"])
            self.assertEqual(
                ownership["statusView"]["staleAttachments"],
                [
                    {
                        "worktreeId": "linked",
                        "attachedWorkId": "work-shared",
                        "deadReason": "missing-worktree-directory",
                    }
                ],
            )


if __name__ == "__main__":
    unittest.main()
