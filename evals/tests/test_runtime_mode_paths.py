"""Contract tests for Unit 01 - root and layout resolution foundation.

Task 1 starts with the tracked config and context protocol surface. Later tasks
extend this module with resolver and migration-safety proofs.
"""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from evals.framework.git_env import outer_git_env, sanitized_git_env
from evals.tests._text_helpers import assert_multiline_regex, load_text


_REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
_CONFIG_PATH = os.path.join(_REPO_ROOT, ".specwright", "config.json")
_CONTEXT_PROTOCOL_PATH = os.path.join(_REPO_ROOT, "core", "protocols", "context.md")
_GITIGNORE_PATH = os.path.join(_REPO_ROOT, ".gitignore")
_SW_INIT_SKILL_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-init", "SKILL.md")
_SW_GUARD_SKILL_PATH = os.path.join(_REPO_ROOT, "core", "skills", "sw-guard", "SKILL.md")
_STATE_PATHS_MODULE_PATH = os.path.join(
    _REPO_ROOT, "adapters", "shared", "specwright-state-paths.mjs"
)


def _load_json(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def _run(args, cwd, *, env=None):
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


def _init_git_repo(path: Path, *, env=None) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _run(["git", "init"], cwd=path, env=env)
    _run(["git", "config", "user.name", "Specwright Tests"], cwd=path, env=env)
    _run(["git", "config", "user.email", "specwright-tests@example.com"], cwd=path, env=env)
    _run(["git", "branch", "-M", "main"], cwd=path, env=env)
    (path / "README.md").write_text("fixture\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=path, env=env)
    _run(["git", "commit", "-m", "chore: init fixture"], cwd=path, env=env)


def _git_path(repo_path: Path, *args: str, env=None) -> Path:
    output = _run(["git", *args], cwd=repo_path, env=env).stdout.strip()
    candidate = Path(output)
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo_path / candidate).resolve()


def _derive_worktree_id(git_dir: Path, git_common_dir: Path) -> str:
    if git_dir == git_common_dir:
        return "main-worktree"

    if git_dir.parent == git_common_dir / "worktrees":
        if git_dir.name and git_dir.name != "main-worktree":
            return git_dir.name

    if git_dir.name and git_dir.name not in {".git", "main-worktree"}:
        return git_dir.name

    return "worktree-" + hashlib.sha256(str(git_dir).encode("utf-8")).hexdigest()[:12]


def _write_config(
    repo_path: Path,
    *,
    runtime_mode: str | None,
    project_visible_root: str = ".specwright-local",
    work_artifacts_mode: str = "clone-local",
    tracked_root: str | None = None,
) -> None:
    git_config = {
        "workArtifacts": {
            "mode": work_artifacts_mode,
            "trackedRoot": tracked_root,
        },
    }
    if runtime_mode is not None:
        git_config["runtime"] = {
            "mode": runtime_mode,
            "projectVisibleRoot": project_visible_root,
        }

    config_path = repo_path / ".specwright" / "config.json"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(
        json.dumps(
            {
                "version": "2.0",
                "git": git_config,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def _runtime_roots(
    repo_path: Path,
    *,
    runtime_mode: str,
    project_visible_root: str = ".specwright-local",
    env=None,
) -> dict[str, Path | str]:
    git_dir = _git_path(repo_path, "rev-parse", "--git-dir", env=env)
    git_common_dir = _git_path(repo_path, "rev-parse", "--git-common-dir", env=env)
    worktree_id = _derive_worktree_id(git_dir, git_common_dir)

    if runtime_mode == "project-visible":
        shared_runtime_root = git_common_dir.parent / project_visible_root
        repo_state_root = shared_runtime_root / "repo"
        worktree_state_root = shared_runtime_root / "worktrees" / worktree_id
        clone_local_work_artifacts_root = repo_state_root / "work"
    else:
        shared_runtime_root = git_common_dir / "specwright"
        repo_state_root = git_common_dir / "specwright"
        worktree_state_root = git_dir / "specwright"
        clone_local_work_artifacts_root = repo_state_root / "work"

    return {
        "gitDir": git_dir,
        "gitCommonDir": git_common_dir,
        "worktreeId": worktree_id,
        "sharedRuntimeRoot": shared_runtime_root,
        "repoStateRoot": repo_state_root,
        "worktreeStateRoot": worktree_state_root,
        "cloneLocalWorkArtifactsRoot": clone_local_work_artifacts_root,
    }


def _write_shared_state(
    repo_path: Path,
    *,
    runtime_mode: str,
    work_id: str = "runtime-proof",
    work_dir: str = "runtime-proof",
    env=None,
) -> None:
    roots = _runtime_roots(repo_path, runtime_mode=runtime_mode, env=env)
    repo_state_root = roots["repoStateRoot"]
    worktree_state_root = roots["worktreeStateRoot"]
    branch = _run(["git", "branch", "--show-current"], cwd=repo_path, env=env).stdout.strip()

    workflow_path = repo_state_root / "work" / work_id / "workflow.json"
    session_path = worktree_state_root / "session.json"
    workflow_path.parent.mkdir(parents=True, exist_ok=True)
    session_path.parent.mkdir(parents=True, exist_ok=True)

    workflow_path.write_text(
        json.dumps(
            {
                "version": "3.0",
                "id": work_id,
                "status": "building",
                "workDir": work_dir,
                "unitId": "02-project-visible-runtime-foundation",
                "tasksCompleted": [],
                "tasksTotal": 3,
                "currentTask": "task-1",
                "branch": branch,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    session_path.write_text(
        json.dumps(
            {
                "version": "3.0",
                "worktreeId": roots["worktreeId"],
                "worktreePath": str(repo_path.resolve()),
                "branch": branch,
                "attachedWorkId": work_id,
                "mode": "top-level",
                "lastSeenAt": "2026-04-20T00:00:00Z",
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def _inspect_runtime_state(repo_path: Path, *, env=None) -> dict:
    script = """
const { resolveSpecwrightRoots, loadSpecwrightState, normalizeActiveWork } =
  await import(process.env.STATE_PATHS_MODULE);

const roots = resolveSpecwrightRoots({ cwd: process.cwd() });
const state = loadSpecwrightState({ cwd: process.cwd() });
const work = normalizeActiveWork(state);

process.stdout.write(JSON.stringify({
  roots: roots.ok ? {
    projectRoot: roots.projectRoot,
    gitDir: roots.gitDir,
    gitCommonDir: roots.gitCommonDir,
    repoStateRoot: roots.repoStateRoot,
    worktreeStateRoot: roots.worktreeStateRoot,
    workArtifactsRoot: roots.workArtifactsRoot,
    worktreeId: roots.worktreeId
  } : roots,
  layout: state.layout,
  sharedConfigPath: state.sharedConfigPath ?? null,
  workflowPath: state.workflowPath ?? null,
  artifactsRoot: work?.artifactsRoot ?? null,
  workDirPath: work?.workDirPath ?? null
}));
"""
    extra_env = {"STATE_PATHS_MODULE": _STATE_PATHS_MODULE_PATH}
    if env is not None:
        extra_env = {**env, **extra_env}
    completed = _run(
        ["node", "--input-type=module", "-e", script],
        cwd=repo_path,
        env=extra_env,
    )
    return json.loads(completed.stdout)


def _resolve_roots(repo_path: Path, *, env=None) -> dict:
    script = """
const { resolveSpecwrightRoots } = await import(process.env.STATE_PATHS_MODULE);
process.stdout.write(JSON.stringify(resolveSpecwrightRoots({ cwd: process.cwd() })));
"""
    extra_env = {"STATE_PATHS_MODULE": _STATE_PATHS_MODULE_PATH}
    if env is not None:
        extra_env = {**env, **extra_env}
    completed = _run(
        ["node", "--input-type=module", "-e", script],
        cwd=repo_path,
        env=extra_env,
    )
    return json.loads(completed.stdout)


class TestRuntimeModeConfigDefaults(unittest.TestCase):
    """AC-1: tracked config defines runtime mode without changing artifact mode."""

    def setUp(self):
        self.config = _load_json(_CONFIG_PATH)
        self.git_config = self.config["git"]

    def test_git_config_has_runtime_block(self):
        self.assertIn(
            "runtime",
            self.git_config,
            "config.git must define a runtime block",
        )

    def test_runtime_block_has_required_keys(self):
        runtime = self.git_config["runtime"]
        expected_keys = {"mode", "projectVisibleRoot"}
        self.assertTrue(
            expected_keys.issubset(runtime.keys()),
            f"runtime block missing keys: {sorted(expected_keys - set(runtime.keys()))}",
        )

    def test_runtime_mode_defaults_to_git_admin(self):
        self.assertEqual(
            self.git_config["runtime"]["mode"],
            "git-admin",
            "existing installs should stay on git-admin until they opt in",
        )

    def test_project_visible_root_defaults_to_dot_specwright_local(self):
        self.assertEqual(
            self.git_config["runtime"]["projectVisibleRoot"],
            ".specwright-local",
        )

    def test_work_artifacts_block_remains_separate_from_runtime_block(self):
        self.assertIn("workArtifacts", self.git_config)
        self.assertIn("runtime", self.git_config)
        self.assertIsInstance(self.git_config["workArtifacts"], dict)
        self.assertIsInstance(self.git_config["runtime"], dict)

    def test_tracked_work_artifacts_default_root_is_repo_visible(self):
        self.assertEqual(
            self.git_config["workArtifacts"]["trackedRoot"],
            ".specwright/works",
            "the tracked work-artifact default root should live under .specwright/works",
        )


class TestRuntimeModeContextProtocol(unittest.TestCase):
    """AC-1: context protocol documents the runtime-mode vocabulary and split."""

    def setUp(self):
        self.content = load_text(_CONTEXT_PROTOCOL_PATH)
        self.lower = self.content.lower()

    def test_protocol_mentions_runtime_mode_keys(self):
        self.assertIn("git.runtime.mode", self.content)
        self.assertIn("git.runtime.projectVisibleRoot", self.content)

    def test_protocol_names_both_runtime_modes(self):
        self.assertIn("git-admin", self.lower)
        self.assertIn("project-visible", self.lower)

    def test_project_visible_root_is_described_as_git_common_dir_parent_relative(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"project-visible.{0,200}git common-dir parent|git common-dir parent.{0,200}project-visible",
        )

    def test_protocol_describes_project_visible_runtime_split(self):
        for needle in (
            "repoStateRoot",
            "worktreeStateRoot",
            "workArtifactsRoot",
            "{repoStateRoot}/work",
            ".specwright-local",
        ):
            with self.subTest(needle=needle):
                self.assertIn(needle, self.content)

        assert_multiline_regex(
            self,
            self.lower,
            r"project-visible.{0,240}repo state root.{0,120}worktree state root.{0,120}work artifacts root",
        )

    def test_work_artifact_publication_remains_independent(self):
        assert_multiline_regex(
            self,
            self.lower,
            r"work-artifact publication.+separate.+runtime mode|runtime mode.+separate.+work-artifact publication",
        )


class TestInteractiveDefaultRecommendations(unittest.TestCase):
    """AC-1: init and guard recommend the new interactive defaults."""

    def setUp(self):
        self.sw_init = load_text(_SW_INIT_SKILL_PATH)
        self.sw_guard = load_text(_SW_GUARD_SKILL_PATH)

    def test_sw_init_recommends_project_visible_and_tracked_work_docs(self):
        assert_multiline_regex(
            self,
            self.sw_init.lower(),
            r"recommend `project-visible`.{0,220}tracked work-artifact root|tracked work-artifact root.{0,220}recommend `project-visible`",
        )

    def test_sw_guard_recommends_project_visible_and_tracked_work_docs(self):
        assert_multiline_regex(
            self,
            self.sw_guard.lower(),
            r"recommend `project-visible`.{0,220}tracked work-artifact|tracked work-artifact.{0,220}recommend `project-visible`",
        )


class TestRuntimeModeResolverPaths(unittest.TestCase):
    """AC-2/AC-3: resolver supports git-admin and project-visible runtime roots."""

    def test_git_admin_primary_worktree_keeps_runtime_under_git_admin(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "git-admin-repo"
            _init_git_repo(repo_path)
            _write_config(repo_path, runtime_mode="git-admin")
            _write_shared_state(repo_path, runtime_mode="git-admin")

            data = _inspect_runtime_state(repo_path)

            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str((repo_path / ".git" / "specwright").resolve()),
            )
            self.assertEqual(
                data["roots"]["worktreeStateRoot"],
                str((repo_path / ".git" / "specwright").resolve()),
            )
            self.assertEqual(
                data["roots"]["workArtifactsRoot"],
                str((repo_path / ".git" / "specwright" / "work").resolve()),
            )
            self.assertEqual(
                data["workflowPath"],
                str((repo_path / ".git" / "specwright" / "work" / "runtime-proof" / "workflow.json").resolve()),
            )

    def test_project_visible_primary_worktree_moves_runtime_out_of_git(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "project-visible-repo"
            _init_git_repo(repo_path)
            _write_config(repo_path, runtime_mode="project-visible")
            _write_shared_state(repo_path, runtime_mode="project-visible")

            data = _inspect_runtime_state(repo_path)
            visible_root = (repo_path / ".specwright-local").resolve()

            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str(visible_root / "repo"),
            )
            self.assertEqual(
                data["roots"]["worktreeStateRoot"],
                str(visible_root / "worktrees" / "main-worktree"),
            )
            self.assertEqual(
                data["roots"]["workArtifactsRoot"],
                str(visible_root / "repo" / "work"),
            )
            self.assertEqual(
                data["workflowPath"],
                str(visible_root / "repo" / "work" / "runtime-proof" / "workflow.json"),
            )
            self.assertEqual(
                data["artifactsRoot"],
                str(visible_root / "repo" / "work"),
            )
            self.assertEqual(
                data["workDirPath"],
                str(visible_root / "repo" / "work" / "runtime-proof"),
            )

    def test_project_visible_linked_worktree_keys_state_by_worktree_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            main_repo_path = Path(tmp) / "main-repo"
            linked_repo_path = Path(tmp) / "linked-repo"
            _init_git_repo(main_repo_path)
            _run(
                ["git", "worktree", "add", "-b", "runtime-linked", str(linked_repo_path), "HEAD"],
                cwd=main_repo_path,
            )
            _write_config(linked_repo_path, runtime_mode="project-visible")

            data = _inspect_runtime_state(linked_repo_path)
            visible_root = (main_repo_path / ".specwright-local").resolve()

            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str(visible_root / "repo"),
            )
            self.assertEqual(
                data["roots"]["worktreeStateRoot"],
                str(visible_root / "worktrees" / "linked-repo"),
            )
            self.assertEqual(data["roots"]["worktreeId"], "linked-repo")
            self.assertEqual(
                data["roots"]["workArtifactsRoot"],
                str(visible_root / "repo" / "work"),
            )

    def test_project_visible_linked_worktree_named_main_worktree_uses_non_primary_id(self):
        with tempfile.TemporaryDirectory() as tmp:
            main_repo_path = Path(tmp) / "main-repo"
            linked_repo_path = Path(tmp) / "main-worktree"
            _init_git_repo(main_repo_path)
            _run(
                ["git", "worktree", "add", "-b", "runtime-main-worktree", str(linked_repo_path), "HEAD"],
                cwd=main_repo_path,
            )
            _write_config(linked_repo_path, runtime_mode="project-visible")

            data = _inspect_runtime_state(linked_repo_path)
            visible_root = (main_repo_path / ".specwright-local").resolve()

            self.assertTrue(data["roots"]["worktreeId"].startswith("worktree-"))
            self.assertNotEqual(data["roots"]["worktreeId"], "main-worktree")
            self.assertEqual(
                data["roots"]["worktreeStateRoot"],
                str(visible_root / "worktrees" / data["roots"]["worktreeId"]),
            )
            self.assertNotEqual(
                data["roots"]["worktreeStateRoot"],
                str(visible_root / "worktrees" / "main-worktree"),
            )

    def test_tracked_work_artifacts_override_stays_independent_in_project_visible_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "tracked-artifacts-repo"
            _init_git_repo(repo_path)
            _write_config(
                repo_path,
                runtime_mode="project-visible",
                work_artifacts_mode="tracked",
                tracked_root=".specwright/audit-work",
            )
            _write_shared_state(repo_path, runtime_mode="project-visible")

            data = _inspect_runtime_state(repo_path)
            visible_root = (repo_path / ".specwright-local").resolve()

            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str(visible_root / "repo"),
            )
            self.assertEqual(
                data["roots"]["workArtifactsRoot"],
                str((repo_path / ".specwright" / "audit-work").resolve()),
            )
            self.assertEqual(
                data["artifactsRoot"],
                str((repo_path / ".specwright" / "audit-work").resolve()),
            )
            self.assertEqual(
                data["workDirPath"],
                str((repo_path / ".specwright" / "audit-work" / "runtime-proof").resolve()),
            )

    def test_git_admin_bare_primary_checkout_falls_back_to_local_project_root(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "bare-primary-git-admin"
            _init_git_repo(repo_path)
            _write_config(repo_path, runtime_mode="git-admin")
            _write_shared_state(repo_path, runtime_mode="git-admin")
            _run(["git", "config", "core.bare", "true"], cwd=repo_path)

            roots = _resolve_roots(repo_path)

            self.assertTrue(roots["ok"], roots)
            self.assertEqual(roots["projectRoot"], str(repo_path.resolve()))
            self.assertEqual(roots["projectArtifactsRoot"], str((repo_path / ".specwright").resolve()))
            self.assertEqual(roots["repoStateRoot"], str((repo_path / ".git" / "specwright").resolve()))
            self.assertEqual(roots["worktreeStateRoot"], str((repo_path / ".git" / "specwright").resolve()))

    def test_project_visible_bare_primary_checkout_keeps_runtime_out_of_git(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "bare-primary-project-visible"
            _init_git_repo(repo_path)
            _write_config(repo_path, runtime_mode="project-visible")
            _write_shared_state(repo_path, runtime_mode="project-visible")
            _run(["git", "config", "core.bare", "true"], cwd=repo_path)

            data = _inspect_runtime_state(repo_path)
            visible_root = (repo_path / ".specwright-local").resolve()

            self.assertEqual(data["layout"], "shared")
            self.assertEqual(data["roots"]["projectRoot"], str(repo_path.resolve()))
            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str(visible_root / "repo"),
            )
            self.assertEqual(
                data["roots"]["worktreeStateRoot"],
                str(visible_root / "worktrees" / "main-worktree"),
            )
            self.assertEqual(
                data["roots"]["workArtifactsRoot"],
                str(visible_root / "repo" / "work"),
            )


class TestFixtureGitEnvIsolation(unittest.TestCase):
    """Fixture helpers ignore outer hook git context across subprocess types."""

    def test_nested_git_fixture_init_ignores_outer_hook_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            outer_repo_path = Path(tmp) / "outer-repo"
            inner_repo_path = Path(tmp) / "inner-repo"
            _init_git_repo(outer_repo_path)
            _run(["git", "checkout", "-b", "outer-scope"], cwd=outer_repo_path)

            _init_git_repo(inner_repo_path, env=outer_git_env(outer_repo_path))

            self.assertEqual(
                _run(["git", "branch", "--show-current"], cwd=outer_repo_path).stdout.strip(),
                "outer-scope",
            )
            self.assertEqual(
                _run(["git", "branch", "--show-current"], cwd=inner_repo_path).stdout.strip(),
                "main",
            )

    def test_runtime_state_node_helpers_ignore_outer_hook_context(self):
        with tempfile.TemporaryDirectory() as tmp:
            outer_repo_path = Path(tmp) / "outer-repo"
            inner_repo_path = Path(tmp) / "inner-repo"
            _init_git_repo(outer_repo_path)
            _run(["git", "checkout", "-b", "outer-scope"], cwd=outer_repo_path)

            outer_env = outer_git_env(outer_repo_path)
            _init_git_repo(inner_repo_path, env=outer_env)
            _write_config(inner_repo_path, runtime_mode="git-admin")
            _write_shared_state(inner_repo_path, runtime_mode="git-admin", env=outer_env)

            roots = _resolve_roots(inner_repo_path, env=outer_env)
            data = _inspect_runtime_state(inner_repo_path, env=outer_env)

            self.assertTrue(roots["ok"])
            self.assertEqual(roots["gitDir"], str((inner_repo_path / ".git").resolve()))
            self.assertEqual(roots["repoStateRoot"], str((inner_repo_path / ".git" / "specwright").resolve()))
            self.assertEqual(data["roots"]["gitDir"], str((inner_repo_path / ".git").resolve()))
            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str((inner_repo_path / ".git" / "specwright").resolve()),
            )
            self.assertEqual(
                data["workflowPath"],
                str((inner_repo_path / ".git" / "specwright" / "work" / "runtime-proof" / "workflow.json").resolve()),
            )
            self.assertEqual(
                _run(["git", "branch", "--show-current"], cwd=outer_repo_path).stdout.strip(),
                "outer-scope",
            )


class TestRuntimeModeSafetyProof(unittest.TestCase):
    """AC-4/AC-5: unsafe project-visible roots fail closed and git-admin remains compatible."""

    def test_gitignore_excludes_project_visible_runtime_root_by_default(self):
        self.assertIn("/.specwright-local/", load_text(_GITIGNORE_PATH))

    def test_project_visible_root_inside_git_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "inside-git-repo"
            _init_git_repo(repo_path)
            _write_config(
                repo_path,
                runtime_mode="project-visible",
                project_visible_root=".git/specwright-local",
            )

            roots = _resolve_roots(repo_path)

            self.assertFalse(roots["ok"])
            self.assertEqual(roots["code"], "INVALID_RUNTIME_ROOT")

    def test_project_visible_root_inside_project_artifacts_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "inside-artifacts-repo"
            _init_git_repo(repo_path)
            _write_config(
                repo_path,
                runtime_mode="project-visible",
                project_visible_root=".specwright/local-runtime",
            )

            roots = _resolve_roots(repo_path)

            self.assertFalse(roots["ok"])
            self.assertEqual(roots["code"], "INVALID_RUNTIME_ROOT")

    def test_project_visible_root_matching_primary_checkout_project_artifacts_is_rejected_for_linked_worktree(self):
        with tempfile.TemporaryDirectory() as tmp:
            main_repo_path = Path(tmp) / "main-repo"
            linked_repo_path = Path(tmp) / "linked-repo"
            _init_git_repo(main_repo_path)
            _run(
                ["git", "worktree", "add", "-b", "runtime-linked", str(linked_repo_path), "HEAD"],
                cwd=main_repo_path,
            )
            _write_config(
                linked_repo_path,
                runtime_mode="project-visible",
                project_visible_root=".specwright",
            )

            roots = _resolve_roots(linked_repo_path)

            self.assertFalse(roots["ok"])
            self.assertEqual(roots["code"], "INVALID_RUNTIME_ROOT")

    def test_project_visible_root_symlinked_into_git_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "symlink-git-repo"
            _init_git_repo(repo_path)
            (repo_path / "runtime-link").symlink_to(repo_path / ".git", target_is_directory=True)
            _write_config(
                repo_path,
                runtime_mode="project-visible",
                project_visible_root="runtime-link",
            )

            roots = _resolve_roots(repo_path)

            self.assertFalse(roots["ok"])
            self.assertEqual(roots["code"], "INVALID_RUNTIME_ROOT")

    def test_project_visible_root_with_parent_traversal_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "traversal-repo"
            _init_git_repo(repo_path)
            _write_config(
                repo_path,
                runtime_mode="project-visible",
                project_visible_root="../outside-runtime",
            )

            roots = _resolve_roots(repo_path)

            self.assertFalse(roots["ok"])
            self.assertEqual(roots["code"], "INVALID_RUNTIME_ROOT")

    def test_project_visible_root_absolute_path_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "absolute-root-repo"
            _init_git_repo(repo_path)
            _write_config(
                repo_path,
                runtime_mode="project-visible",
                project_visible_root=str((Path(tmp) / "absolute-runtime").resolve()),
            )

            roots = _resolve_roots(repo_path)

            self.assertFalse(roots["ok"])
            self.assertEqual(roots["code"], "INVALID_RUNTIME_ROOT")

    def test_legacy_git_admin_install_still_loads_when_runtime_block_is_absent(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo_path = Path(tmp) / "legacy-git-admin-repo"
            _init_git_repo(repo_path)
            _write_config(repo_path, runtime_mode=None)
            _write_shared_state(repo_path, runtime_mode="git-admin")

            data = _inspect_runtime_state(repo_path)

            self.assertEqual(data["layout"], "shared")
            self.assertEqual(
                data["roots"]["repoStateRoot"],
                str((repo_path / ".git" / "specwright").resolve()),
            )
            self.assertEqual(
                data["workflowPath"],
                str((repo_path / ".git" / "specwright" / "work" / "runtime-proof" / "workflow.json").resolve()),
            )


if __name__ == "__main__":
    unittest.main()
