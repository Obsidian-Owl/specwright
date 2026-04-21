"""Regression coverage for Unit 03 — operator surface visibility."""

from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from evals.framework.git_env import _REPO_LOCAL_GIT_ENV_VARS, sanitized_git_env
from evals.tests._text_helpers import assert_multiline_regex, load_text


ROOT_DIR = Path(__file__).resolve().parents[2]
SESSION_START_HOOK = ROOT_DIR / "adapters" / "claude-code" / "hooks" / "session-start.mjs"
APPROVALS_MODULE = ROOT_DIR / "adapters" / "shared" / "specwright-approvals.mjs"
PLUGIN_PATH = ROOT_DIR / "adapters" / "opencode" / "plugin.ts"
STATUS_SKILL = ROOT_DIR / "core" / "skills" / "sw-status" / "SKILL.md"
INIT_SKILL = ROOT_DIR / "core" / "skills" / "sw-init" / "SKILL.md"
GUARD_SKILL = ROOT_DIR / "core" / "skills" / "sw-guard" / "SKILL.md"
DOCTOR_SKILL = ROOT_DIR / "core" / "skills" / "sw-doctor" / "SKILL.md"


def _run(args: list[str], cwd: Path, *, env: dict | None = None) -> subprocess.CompletedProcess[str]:
    runtime_env = None
    if args and args[0] == "git":
        extra_env = None
        if env is not None:
            extra_env = {
                key: value
                for key, value in env.items()
                if key not in _REPO_LOCAL_GIT_ENV_VARS
            }
        runtime_env = sanitized_git_env(extra_env)
    elif env is not None:
        runtime_env = {**os.environ, **env}

    return subprocess.run(
        args,
        cwd=cwd,
        check=True,
        capture_output=True,
        text=True,
        env=runtime_env,
    )


def _init_git_repo(path: Path, *, env: dict | None = None) -> None:
    path.mkdir(parents=True, exist_ok=True)
    _run(["git", "init"], cwd=path, env=env)
    _run(["git", "config", "user.name", "Specwright Tests"], cwd=path, env=env)
    _run(["git", "config", "user.email", "specwright-tests@example.com"], cwd=path, env=env)
    _run(["git", "branch", "-M", "main"], cwd=path, env=env)
    (path / "README.md").write_text("fixture\n", encoding="utf-8")
    _run(["git", "add", "README.md"], cwd=path, env=env)
    _run(["git", "commit", "-m", "chore: init fixture"], cwd=path, env=env)


def _git_path(repo_path: Path, *args: str, env: dict | None = None) -> Path:
    output = _run(["git", *args], cwd=repo_path, env=env).stdout.strip()
    candidate = Path(output)
    if candidate.is_absolute():
        return candidate.resolve()
    return (repo_path / candidate).resolve()


def _outer_git_env(repo_path: Path) -> dict[str, str]:
    git_dir = _git_path(repo_path, "rev-parse", "--path-format=absolute", "--git-dir")
    git_common_dir = _git_path(repo_path, "rev-parse", "--path-format=absolute", "--git-common-dir")
    return {
        "GIT_DIR": str(git_dir),
        "GIT_WORK_TREE": str(repo_path.resolve()),
        "GIT_COMMON_DIR": str(git_common_dir),
        "GIT_PREFIX": "",
    }


def _derive_worktree_id(git_dir: Path, git_common_dir: Path) -> str:
    if git_dir == git_common_dir:
        return "main-worktree"

    if git_dir.parent == git_common_dir / "worktrees" and git_dir.name and git_dir.name != "main-worktree":
        return git_dir.name

    if git_dir.name and git_dir.name not in {".git", "main-worktree"}:
        return git_dir.name

    raise AssertionError("unable to derive worktree id for test fixture")


def _runtime_roots(repo_path: Path, *, env: dict | None = None) -> dict[str, Path | str]:
    git_dir = _git_path(repo_path, "rev-parse", "--git-dir", env=env)
    git_common_dir = _git_path(repo_path, "rev-parse", "--git-common-dir", env=env)
    worktree_id = _derive_worktree_id(git_dir, git_common_dir)
    repo_state_root = git_common_dir / "specwright"
    worktree_state_root = git_dir / "specwright"

    return {
        "gitDir": git_dir,
        "gitCommonDir": git_common_dir,
        "worktreeId": worktree_id,
        "repoStateRoot": repo_state_root,
        "worktreeStateRoot": worktree_state_root,
        "workArtifactsRoot": repo_state_root / "work",
    }


def _write_shared_state(
    repo_path: Path,
    *,
    work_id: str = "operator-surface-proof",
    unit_id: str = "03-operator-surface-cutover",
    env: dict | None = None,
) -> dict[str, Path | str]:
    roots = _runtime_roots(repo_path, env=env)
    repo_state_root = roots["repoStateRoot"]
    worktree_state_root = roots["worktreeStateRoot"]
    work_artifacts_root = roots["workArtifactsRoot"]
    branch = _run(["git", "branch", "--show-current"], cwd=repo_path, env=env).stdout.strip()

    (repo_state_root / "config.json").parent.mkdir(parents=True, exist_ok=True)
    (repo_state_root / "config.json").write_text(
        json.dumps({"version": "2.0"}, indent=2) + "\n",
        encoding="utf-8",
    )

    work_dir = work_artifacts_root / work_id
    workflow_path = work_dir / "workflow.json"
    session_path = worktree_state_root / "session.json"
    work_dir.mkdir(parents=True, exist_ok=True)
    session_path.parent.mkdir(parents=True, exist_ok=True)

    for artifact_name in ("spec.md", "plan.md", "context.md"):
        (work_dir / artifact_name).write_text(f"# {artifact_name}\n", encoding="utf-8")

    workflow_path.write_text(
        json.dumps(
            {
                "version": "3.0",
                "id": work_id,
                "status": "building",
                "workDir": f"work/{work_id}",
                "unitId": unit_id,
                "tasksCompleted": ["task-1"],
                "tasksTotal": 3,
                "currentTask": "task-2",
                "branch": branch,
                "gates": {
                    "build": {"verdict": "PASS"},
                    "tests": {"verdict": "PASS"},
                },
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

    return {
        **roots,
        "workId": work_id,
        "unitId": unit_id,
        "workDir": work_dir,
    }


def _write_stage_report(work_dir: Path, repo_state_root: Path, work_id: str, unit_id: str) -> None:
    stage_report = repo_state_root / "work" / work_id / "units" / unit_id / "stage-report.md"
    stage_report.parent.mkdir(parents=True, exist_ok=True)
    stage_report.write_text(
        "\n".join(
            [
                "Attention required: Operator surface summary is available.",
                "",
                "## What I did",
                "- Surfaced the latest closeout digest.",
                "- Carried approval freshness into the recovery output.",
                "",
                "## Decisions digest",
                "- Kept the warning footer compact.",
                "",
            ]
        ),
        encoding="utf-8",
    )


def _write_approvals(work_dir: Path, unit_id: str) -> None:
    approvals_path = work_dir / "approvals.md"
    script = f"""
const {{ createApprovalEntry, defaultApprovalsDocument, writeApprovalsFile }} = await import({json.dumps(str(APPROVALS_MODULE))});

const entry = createApprovalEntry({{
  baseDir: {json.dumps(str(work_dir))},
  scope: 'unit-spec',
  unitId: {json.dumps(unit_id)},
  sourceClassification: 'command',
  sourceRef: '/sw-build',
  artifacts: ['spec.md', 'plan.md', 'context.md'],
  approvedAt: '2026-04-20T00:00:00Z'
}});

const document = defaultApprovalsDocument();
document.entries.push(entry);
writeApprovalsFile({json.dumps(str(approvals_path))}, document);
"""
    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        cwd=ROOT_DIR,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "approval fixture creation failed")


def _run_session_start(repo_path: Path) -> str:
    result = subprocess.run(
        ["node", str(SESSION_START_HOOK)],
        cwd=repo_path,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "session-start hook failed")
    return result.stdout


def _run_opencode_event(repo_path: Path, event: str) -> str:
    script = f"""
import plugin from {json.dumps(str(PLUGIN_PATH))};

const handlers = new Map();
const ctx = {{
  directory: {json.dumps(str(repo_path))},
  on(name, handler) {{
    handlers.set(name, handler);
  }}
}};

console.log = () => {{}};
console.warn = () => {{}};

await plugin(ctx);

const handler = handlers.get({json.dumps(event)});
if (!handler) {{
  throw new Error(`missing Opencode handler: {event}`);
}}

const result = await handler();
if (typeof result === 'string') {{
  process.stdout.write(result);
}}
"""
    result = subprocess.run(
        ["bun", "-e", script],
        cwd=ROOT_DIR,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or f"opencode {event} handler failed")
    return result.stdout


def _fresh_timestamp() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


class TestSessionStartSurface(unittest.TestCase):
    def test_shared_state_writes_ignore_outer_hook_context(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            outer_repo_path = Path(tmpdir) / "outer-repo"
            inner_repo_path = Path(tmpdir) / "inner-repo"
            _init_git_repo(outer_repo_path)
            _run(["git", "checkout", "-b", "outer-scope"], cwd=outer_repo_path)

            outer_env = _outer_git_env(outer_repo_path)
            _init_git_repo(inner_repo_path, env=outer_env)
            state = _write_shared_state(inner_repo_path, env=outer_env)

            self.assertEqual(
                _run(["git", "branch", "--show-current"], cwd=outer_repo_path).stdout.strip(),
                "outer-scope",
            )
            self.assertEqual(
                Path(state["repoStateRoot"]),
                (inner_repo_path / ".git" / "specwright").resolve(),
            )
            self.assertEqual(
                Path(state["worktreeStateRoot"]),
                (inner_repo_path / ".git" / "specwright").resolve(),
            )
            self.assertTrue((Path(state["repoStateRoot"]) / "config.json").exists())
            self.assertTrue((Path(state["worktreeStateRoot"]) / "session.json").exists())
            self.assertFalse((outer_repo_path / ".git" / "specwright" / "session.json").exists())

    def test_session_start_names_missing_closeout_and_approval(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            _write_shared_state(repo_path)

            output = _run_session_start(repo_path)

            self.assertIn("Closeout: none yet", output)
            self.assertIn("Approval: unit-spec MISSING (missing-entry)", output)

    def test_session_start_replays_shared_digest_and_approval_summary(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            _write_stage_report(
                state["workDir"],
                state["repoStateRoot"],
                state["workId"],
                state["unitId"],
            )
            _write_approvals(state["workDir"], state["unitId"])

            output = _run_session_start(repo_path)

            self.assertIn("Closeout: stage-report", output)
            self.assertIn("Attention required: Operator surface summary is available.", output)
            self.assertIn("Approval: unit-spec APPROVED (approved)", output)


@unittest.skipUnless(shutil.which("bun"), "bun is required for Opencode plugin runtime tests")
class TestOpencodeSessionCreatedSurface(unittest.TestCase):
    def test_source_tree_plugin_loads_and_deploys_core_assets(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            _write_shared_state(repo_path)

            output = _run_opencode_event(repo_path, "session.created")

            self.assertIn("Specwright: Work in progress", output)
            self.assertTrue((repo_path / ".opencode" / "commands" / "sw-build.md").exists())
            self.assertTrue((repo_path / ".specwright" / "skills" / "sw-build" / "SKILL.md").exists())
            self.assertTrue((repo_path / ".specwright" / "protocols" / "git.md").exists())
            self.assertTrue((repo_path / ".specwright" / "agents" / "specwright-architect.md").exists())

    def test_session_created_replays_quality_corrections_when_present(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            continuation_path = Path(state["worktreeStateRoot"]) / "continuation.md"
            continuation_path.parent.mkdir(parents=True, exist_ok=True)
            continuation_path.write_text(
                "\n".join(
                    [
                        f"Snapshot: {_fresh_timestamp()}",
                        "",
                        "## Progress",
                        "Shared continuation notes.",
                        "",
                        "## Correction Summary",
                        "- unchecked-error: Always handle errors explicitly",
                        "",
                        "## Next Steps",
                        "Continue with task 3.",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

            output = _run_opencode_event(repo_path, "session.created")

            self.assertIn("Continuation Snapshot", output)
            self.assertIn("Quality Corrections", output)
            self.assertIn("unchecked-error", output)
            self.assertFalse(continuation_path.exists())

    def test_session_created_omits_quality_corrections_when_absent(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            continuation_path = Path(state["worktreeStateRoot"]) / "continuation.md"
            continuation_path.parent.mkdir(parents=True, exist_ok=True)
            continuation_path.write_text(
                "\n".join(
                    [
                        f"Snapshot: {_fresh_timestamp()}",
                        "",
                        "## Progress",
                        "Shared continuation notes.",
                        "",
                        "## Next Steps",
                        "Continue with task 3.",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

            output = _run_opencode_event(repo_path, "session.created")

            self.assertIn("Continuation Snapshot", output)
            self.assertNotIn("Quality Corrections", output)
            self.assertFalse(continuation_path.exists())


class TestOperatorSurfaceContracts(unittest.TestCase):
    def test_opencode_plugin_uses_shared_surface_and_not_legacy_state(self):
        plugin_text = load_text(PLUGIN_PATH)
        self.assertIn("loadSpecwrightState", plugin_text)
        self.assertIn("loadOperatorSurfaceSummary", plugin_text)
        self.assertNotIn(".specwright/state", plugin_text)

    def test_status_skill_keeps_approval_reason_and_closeout_visibility_together(self):
        status_text = load_text(STATUS_SKILL)
        self.assertIn("approval freshness reason", status_text)
        self.assertIn("latest closeout or review-packet availability", status_text)

    def test_runtime_guidance_uses_runtime_keys_without_collapsing_into_work_artifacts(self):
        init_text = load_text(INIT_SKILL)
        guard_text = load_text(GUARD_SKILL)
        doctor_text = load_text(DOCTOR_SKILL)

        for label, text in (
            ("sw-init", init_text),
            ("sw-guard", guard_text),
        ):
            with self.subTest(skill=label):
                self.assertIn("git.runtime.mode", text)
                self.assertIn("git.runtime.projectVisibleRoot", text)
                self.assertIn("tracked work-artifact publication", text)

        self.assertIn("config.git.runtime.projectVisibleRoot", doctor_text)
        self.assertIn("authoritative runtime roots", doctor_text)
        assert_multiline_regex(
            self,
            doctor_text,
            r"tracked project artifacts[\s\S]*`?\.git`?-mirrored paths",
        )


if __name__ == "__main__":
    unittest.main()
