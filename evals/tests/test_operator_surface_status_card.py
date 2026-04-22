"""Regression coverage for Unit 03 — shared status-card contract."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

from evals.framework.git_env import sanitized_git_env
from evals.tests._text_helpers import assert_multiline_regex, load_text


ROOT_DIR = Path(__file__).resolve().parents[2]
STATE_PATHS_MODULE = ROOT_DIR / "adapters" / "shared" / "specwright-state-paths.mjs"
STATUS_CARD_MODULE = ROOT_DIR / "adapters" / "shared" / "specwright-status-card.mjs"
OPERATOR_SURFACE_MODULE = ROOT_DIR / "adapters" / "shared" / "specwright-operator-surface.mjs"
APPROVALS_MODULE = ROOT_DIR / "adapters" / "shared" / "specwright-approvals.mjs"
APPROVALS_PROTOCOL = ROOT_DIR / "core" / "protocols" / "approvals.md"


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
    git_dir = _git_path(repo_path, "rev-parse", "--git-dir")
    git_common_dir = _git_path(repo_path, "rev-parse", "--git-common-dir")
    worktree_id = _derive_worktree_id(git_dir, git_common_dir)

    return {
        "gitDir": git_dir,
        "gitCommonDir": git_common_dir,
        "worktreeId": worktree_id,
        "repoStateRoot": git_common_dir / "specwright",
        "worktreeStateRoot": git_dir / "specwright",
        "workArtifactsRoot": (git_common_dir / "specwright" / "work"),
    }


def _write_shared_state(
    repo_path: Path,
    *,
    work_id: str = "status-card-proof",
    unit_id: str = "03-status-card-proof",
    workflow_branch: str = "work/03-status-card-proof",
    session_branch: str | None = None,
) -> dict[str, Path | str]:
    roots = _runtime_roots(repo_path)
    repo_state_root = Path(roots["repoStateRoot"])
    worktree_state_root = Path(roots["worktreeStateRoot"])
    unit_dir = Path(roots["workArtifactsRoot"]) / work_id / "units" / unit_id
    workflow_path = repo_state_root / "work" / work_id / "workflow.json"
    session_path = worktree_state_root / "session.json"

    config_path = repo_state_root / "config.json"
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(
        json.dumps(
            {
                "version": "2.0",
                "git": {
                    "targets": {
                        "defaultRole": "integration",
                        "roles": {
                            "integration": {"branch": "main"},
                        },
                    },
                    "freshness": {
                        "validation": "branch-head",
                        "reconcile": "manual",
                        "checkpoints": {
                            "build": "require",
                            "verify": "require",
                            "ship": "require",
                        },
                    },
                },
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    unit_dir.mkdir(parents=True, exist_ok=True)
    session_path.parent.mkdir(parents=True, exist_ok=True)

    (unit_dir / "spec.md").write_text("# Spec\n", encoding="utf-8")
    (unit_dir / "plan.md").write_text("# Plan\n", encoding="utf-8")
    (unit_dir / "context.md").write_text("# Context\n", encoding="utf-8")

    workflow_path.parent.mkdir(parents=True, exist_ok=True)
    workflow_path.write_text(
        json.dumps(
            {
                "version": "3.0",
                "id": work_id,
                "description": "Structured operator status-card proof.",
                "status": "building",
                "workDir": f"{work_id}/units/{unit_id}",
                "unitId": unit_id,
                "tasksCompleted": ["task-1"],
                "tasksTotal": 3,
                "currentTask": "task-2",
                "baselineCommit": "2648d5fbb35a440e6bfd6c685f459f13a03104c1",
                "targetRef": {
                    "remote": "origin",
                    "branch": "main",
                    "role": "integration",
                    "resolvedBy": "config.git.targets.roles.integration.branch",
                    "resolvedAt": "2026-04-21T03:09:41Z",
                },
                "freshness": {
                    "validation": "branch-head",
                    "reconcile": "manual",
                    "checkpoints": {
                        "build": "require",
                        "verify": "require",
                        "ship": "require",
                    },
                    "status": "fresh",
                    "lastCheckedAt": "2026-04-21T03:10:00Z",
                },
                "branch": workflow_branch,
                "gates": {
                    "build": {"verdict": "PASS"},
                    "tests": {"verdict": "PASS"},
                },
                "attachment": {
                    "worktreeId": roots["worktreeId"],
                    "worktreePath": str(repo_path.resolve()),
                    "mode": "top-level",
                    "attachedAt": "2026-04-21T03:18:49Z",
                    "lastSeenAt": "2026-04-21T03:18:49Z",
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
                "branch": session_branch or workflow_branch,
                "attachedWorkId": work_id,
                "mode": "top-level",
                "lastSeenAt": "2026-04-21T03:18:49Z",
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
        "unitDir": unit_dir,
        "workflowPath": workflow_path,
        "sessionPath": session_path,
    }


def _write_stage_report(repo_state_root: Path, work_id: str, unit_id: str) -> Path:
    stage_report_path = repo_state_root / "work" / work_id / "units" / unit_id / "stage-report.md"
    stage_report_path.parent.mkdir(parents=True, exist_ok=True)
    stage_report_path.write_text(
        "\n".join(
            [
                "Attention required: Shared operator summary is available.",
                "",
                "## What I did",
                "- Built a structured operator card.",
                "- Kept closeout digests readable during migration.",
                "",
            ]
        )
        + "\n",
        encoding="utf-8",
    )
    return stage_report_path


def _write_approvals(unit_dir: Path, unit_id: str) -> None:
    approvals_path = unit_dir.parents[1] / "approvals.md"
    script = f"""
const {{ defaultApprovalsDocument, recordApproval, writeApprovalsFile }} = await import({json.dumps(str(APPROVALS_MODULE))});

const document = recordApproval(defaultApprovalsDocument(), {{
  baseDir: {json.dumps(str(unit_dir))},
  scope: 'unit-spec',
  unitId: {json.dumps(unit_id)},
  sourceClassification: 'command',
  sourceRef: '/sw-build',
  artifacts: ['spec.md', 'plan.md', 'context.md'],
  approvedAt: '2026-04-21T03:20:00Z'
}});

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


def _build_status_card(repo_path: Path, *, force_used_fallback: bool = False, write_status_card: bool = True) -> dict:
    script = """
const { loadSpecwrightState, normalizeActiveWork } = await import(process.env.STATE_PATHS_MODULE);
const {
  buildStatusCard,
  resolveStatusCardPath,
  writeStatusCard
} = await import(process.env.STATUS_CARD_MODULE);

const state = loadSpecwrightState({ cwd: process.cwd() });
if (process.env.FORCE_USED_FALLBACK === '1') {
  state.usedFallback = true;
}
const work = normalizeActiveWork(state);
const card = buildStatusCard(state, work);
const statusCardPath = resolveStatusCardPath(state, work);

if (process.env.WRITE_STATUS_CARD === '1') {
  writeStatusCard(statusCardPath, card);
}

process.stdout.write(JSON.stringify({ card, statusCardPath }, null, 2));
"""
    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        cwd=repo_path,
        check=False,
        env=sanitized_git_env(
            {
                "STATE_PATHS_MODULE": str(STATE_PATHS_MODULE),
                "STATUS_CARD_MODULE": str(STATUS_CARD_MODULE),
                "FORCE_USED_FALLBACK": "1" if force_used_fallback else "0",
                "WRITE_STATUS_CARD": "1" if write_status_card else "0",
            }
        ),
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "status-card helper execution failed")
    return json.loads(result.stdout)


def _load_operator_surface(repo_path: Path, *, force_used_fallback: bool = False) -> dict:
    script = """
const { loadSpecwrightState, normalizeActiveWork } = await import(process.env.STATE_PATHS_MODULE);
const {
  loadOperatorSurfaceSummary,
  renderOperatorSurfaceLines
} = await import(process.env.OPERATOR_SURFACE_MODULE);

const state = loadSpecwrightState({ cwd: process.cwd() });
if (process.env.FORCE_USED_FALLBACK === '1') {
  state.usedFallback = true;
}
const work = normalizeActiveWork(state);
const summary = loadOperatorSurfaceSummary(state, work);
const lines = renderOperatorSurfaceLines(summary);

process.stdout.write(JSON.stringify({ summary, lines }, null, 2));
"""
    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        cwd=repo_path,
        check=False,
        env=sanitized_git_env(
            {
                "STATE_PATHS_MODULE": str(STATE_PATHS_MODULE),
                "STATUS_CARD_MODULE": str(STATUS_CARD_MODULE),
                "OPERATOR_SURFACE_MODULE": str(OPERATOR_SURFACE_MODULE),
                "FORCE_USED_FALLBACK": "1" if force_used_fallback else "0",
            }
        ),
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "operator-surface helper execution failed")
    return json.loads(result.stdout)


def _render_operator_surface_lines(summary: dict) -> list[str]:
    script = """
const { renderOperatorSurfaceLines } = await import(process.env.OPERATOR_SURFACE_MODULE);
const summary = JSON.parse(process.env.OPERATOR_SURFACE_SUMMARY_JSON);
const lines = renderOperatorSurfaceLines(summary);

process.stdout.write(JSON.stringify({ lines }, null, 2));
"""
    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        cwd=ROOT_DIR,
        check=False,
        env=sanitized_git_env(
            {
                "OPERATOR_SURFACE_MODULE": str(OPERATOR_SURFACE_MODULE),
                "OPERATOR_SURFACE_SUMMARY_JSON": json.dumps(summary),
            }
        ),
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "operator-surface render execution failed")
    return json.loads(result.stdout)["lines"]


class TestStatusCardContract(unittest.TestCase):
    def test_build_status_card_returns_minimum_contract_and_writes_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            _write_stage_report(Path(state["repoStateRoot"]), state["workId"], state["unitId"])
            _write_approvals(Path(state["unitDir"]), state["unitId"])

            result = _build_status_card(repo_path)
            card = result["card"]
            status_card_path = Path(result["statusCardPath"])

            self.assertEqual(card["workId"], state["workId"])
            self.assertEqual(card["stage"], "building")
            self.assertEqual(card["currentUnitId"], state["unitId"])
            self.assertEqual(card["targetRef"]["remote"], "origin")
            self.assertEqual(card["targetRef"]["branch"], "main")
            self.assertEqual(card["baselineCommit"], "2648d5fbb35a440e6bfd6c685f459f13a03104c1")
            self.assertEqual(card["branch"]["expected"], "work/03-status-card-proof")
            self.assertEqual(card["branch"]["observed"], "work/03-status-card-proof")
            self.assertEqual(card["branch"]["status"], "match")
            self.assertEqual(card["approvals"]["status"], "APPROVED")
            self.assertEqual(card["approvals"]["reasonCode"], "approved")
            self.assertEqual(card["gates"]["status"], "pass")
            self.assertEqual(card["closeout"]["source"], "stage-report")
            self.assertEqual(card["nextCommand"], "/sw-build")

            self.assertTrue(status_card_path.exists(), "status-card.json should be written")
            written_card = json.loads(status_card_path.read_text(encoding="utf-8"))
            self.assertEqual(written_card, card)

    def test_build_status_card_surfaces_explicit_warning_classes_without_crashing(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(
                repo_path,
                session_branch="work/03-status-card-proof-drifted",
            )
            _write_approvals(Path(state["unitDir"]), state["unitId"])
            (Path(state["unitDir"]) / "context.md").unlink()

            result = _build_status_card(
                repo_path,
                force_used_fallback=True,
                write_status_card=False,
            )
            card = result["card"]
            warning_codes = {warning["code"] for warning in card["warnings"]}

            self.assertEqual(card["approvals"]["status"], "STALE")
            self.assertEqual(card["approvals"]["reasonCode"], "artifact-set-changed")
            self.assertEqual(card["branch"]["status"], "mismatch")
            self.assertEqual(card["nextCommand"], "/sw-build")
            self.assertSetEqual(
                warning_codes,
                {
                    "approval-artifact-set-changed",
                    "missing-closeout",
                    "branch-mismatch",
                    "degraded-root-resolution",
                },
            )

    def test_build_status_card_points_to_verify_when_all_tasks_are_complete(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            workflow_path = Path(state["workflowPath"])
            workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
            workflow["tasksCompleted"] = ["task-1", "task-2", "task-3"]
            workflow["currentTask"] = None
            workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)

            self.assertEqual(result["card"]["nextCommand"], "/sw-verify")

    def test_build_status_card_treats_skipped_gates_as_warn_and_keeps_ship_handoff(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            workflow_path = Path(state["workflowPath"])
            workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
            workflow["status"] = "verifying"
            workflow["gates"] = {
                "build": {"verdict": "SKIP"},
                "tests": {"verdict": "SKIP"},
            }
            workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)
            card = result["card"]

            self.assertEqual(card["gates"]["status"], "warn")
            self.assertEqual(card["gates"]["counts"]["skip"], 2)
            self.assertEqual(card["gates"]["summary"], "2 SKIP")
            self.assertEqual(card["nextCommand"], "/sw-ship")

    def test_build_status_card_points_verifying_failures_back_to_build(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            workflow_path = Path(state["workflowPath"])
            workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
            workflow["status"] = "verifying"
            workflow["gates"] = {
                "build": {"verdict": "PASS"},
                "tests": {"verdict": "FAIL"},
            }
            workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)

            self.assertEqual(result["card"]["nextCommand"], "/sw-build")

    def test_build_status_card_points_freshness_blocked_verify_back_to_verify(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            workflow_path = Path(state["workflowPath"])
            workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
            workflow["status"] = "verifying"
            workflow["gates"] = {}
            workflow["freshness"]["status"] = "blocked"
            workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)

            self.assertEqual(result["card"]["nextCommand"], "/sw-verify")

    def test_build_status_card_requires_live_session_branch_for_match(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            session_path = Path(state["sessionPath"])
            session = json.loads(session_path.read_text(encoding="utf-8"))
            session["branch"] = None
            session_path.write_text(json.dumps(session, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)
            card = result["card"]

            self.assertEqual(card["branch"]["expected"], "work/03-status-card-proof")
            self.assertIsNone(card["branch"]["observed"])
            self.assertEqual(card["branch"]["status"], "unknown")

    def test_build_status_card_points_final_shipped_work_to_learn(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            workflow_path = Path(state["workflowPath"])
            workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
            workflow["status"] = "shipped"
            workflow["gates"] = {
                "build": {"verdict": "PASS"},
                "tests": {"verdict": "PASS"},
            }
            workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)

            self.assertEqual(result["card"]["nextCommand"], "/sw-learn")

    def test_build_status_card_keeps_build_handoff_when_more_units_remain_after_ship(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            workflow_path = Path(state["workflowPath"])
            workflow = json.loads(workflow_path.read_text(encoding="utf-8"))
            workflow["status"] = "shipped"
            workflow["gates"] = {
                "build": {"verdict": "PASS"},
                "tests": {"verdict": "PASS"},
            }
            workflow["workUnits"] = [
                {"id": state["unitId"], "status": "shipped", "order": 1},
                {"id": "04-follow-on-unit", "status": "planned", "order": 2},
            ]
            workflow_path.write_text(json.dumps(workflow, indent=2) + "\n", encoding="utf-8")

            result = _build_status_card(repo_path, write_status_card=False)

            self.assertEqual(result["card"]["nextCommand"], "/sw-build")

    def test_operator_surface_summary_uses_shared_status_card_contract(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            repo_path = Path(tmpdir)
            _init_git_repo(repo_path)
            state = _write_shared_state(repo_path)
            _write_stage_report(Path(state["repoStateRoot"]), state["workId"], state["unitId"])
            _write_approvals(Path(state["unitDir"]), state["unitId"])

            result = _load_operator_surface(repo_path)
            summary = result["summary"]
            lines = result["lines"]
            card = summary["card"]

            self.assertEqual(summary["approval"]["scope"], card["approvals"]["scope"])
            self.assertEqual(summary["approval"]["status"], card["approvals"]["status"])
            self.assertEqual(summary["approval"]["reasonCode"], card["approvals"]["reasonCode"])
            self.assertEqual(summary["closeout"]["source"], card["closeout"]["source"])
            self.assertEqual(summary["nextCommand"], card["nextCommand"])
            self.assertTrue(any("Closeout: stage-report" in line for line in lines))
            self.assertTrue(any("Approval: unit-spec APPROVED (approved)" in line for line in lines))

    def test_operator_surface_warning_lines_use_named_two_warning_cap(self) -> None:
        lines = _render_operator_surface_lines(
            {
                "card": {"branch": None},
                "closeout": None,
                "approval": None,
                "warnings": [
                    {"code": "degraded-root-resolution", "summary": "First warning"},
                    {"code": "runtime-fallback", "summary": "Second warning"},
                    {"code": "advisory-overflow", "summary": "Third warning"},
                ],
                "nextCommand": None,
            }
        )

        self.assertEqual(
            [line for line in lines if line.startswith("  WARNING:")],
            [
                "  WARNING: First warning",
                "  WARNING: Second warning",
            ],
        )

    def test_operator_surface_warning_lines_report_overflow_after_cap(self) -> None:
        lines = _render_operator_surface_lines(
            {
                "card": {"branch": None},
                "closeout": None,
                "approval": None,
                "warnings": [
                    {"code": "degraded-root-resolution", "summary": "First warning"},
                    {"code": "runtime-fallback", "summary": "Second warning"},
                    {"code": "third-signal", "summary": "Third warning"},
                ],
                "nextCommand": None,
            }
        )

        self.assertEqual(
            [line for line in lines if line.startswith("  WARNING:")],
            [
                "  WARNING: First warning",
                "  WARNING: Second warning",
            ],
        )
        self.assertIn(
            "  ... and 1 more warning - run /sw-status for full detail",
            lines,
        )

    def test_work_in_progress_summary_falls_back_when_work_gates_summary_is_blank(self) -> None:
        script = """
const { renderWorkInProgressSummary } = await import(process.env.OPERATOR_SURFACE_MODULE);
const work = JSON.parse(process.env.OPERATOR_SURFACE_WORK_JSON);
const summary = JSON.parse(process.env.OPERATOR_SURFACE_SUMMARY_JSON);

process.stdout.write(renderWorkInProgressSummary({ work, summary }));
"""
        work = {
            "workId": "quality-first-devex-redesign",
            "status": "building",
            "unitId": "04-adapter-and-support-surface-cutover",
            "completedCount": 3,
            "totalCount": 5,
            "gatesSummary": "   ",
            "specPath": ".specwright/specs/example.md",
            "planPath": ".specwright/plans/example.md",
        }
        summary = {
            "card": {
                "gates": {
                    "summary": "2 PASS, 1 WARN"
                }
            },
            "closeout": None,
            "approval": None,
            "warnings": [],
            "nextCommand": None,
        }
        result = subprocess.run(
            ["node", "--input-type=module", "-"],
            input=script,
            text=True,
            capture_output=True,
            cwd=ROOT_DIR,
            check=False,
            env=sanitized_git_env(
                {
                    "OPERATOR_SURFACE_MODULE": str(OPERATOR_SURFACE_MODULE),
                    "OPERATOR_SURFACE_WORK_JSON": json.dumps(work),
                    "OPERATOR_SURFACE_SUMMARY_JSON": json.dumps(summary),
                }
            ),
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr or result.stdout or "work-in-progress render execution failed")

        self.assertIn("  Gates: 2 PASS, 1 WARN", result.stdout)


class TestApprovalsProtocolStatusCardContract(unittest.TestCase):
    def test_find_latest_approval_entry_requires_scope(self) -> None:
        script = """
const { findLatestApprovalEntry } = await import(process.env.APPROVALS_MODULE);

try {
  findLatestApprovalEntry([{ scope: 'design' }]);
  process.stdout.write(JSON.stringify({ ok: true }));
} catch (error) {
  process.stdout.write(JSON.stringify({
    ok: false,
    message: error instanceof Error ? error.message : String(error)
  }));
}
"""
        result = subprocess.run(
            ["node", "--input-type=module", "-"],
            input=script,
            text=True,
            capture_output=True,
            cwd=ROOT_DIR,
            check=False,
            env=sanitized_git_env({"APPROVALS_MODULE": str(APPROVALS_MODULE)}),
        )
        if result.returncode != 0:
            raise AssertionError(result.stderr or result.stdout or "approval helper execution failed")

        payload = json.loads(result.stdout)
        self.assertFalse(payload["ok"])
        self.assertEqual(payload["message"], "Approval scope is required.")

    def test_approvals_protocol_mentions_status_card_reason_code_consumers(self) -> None:
        text = load_text(APPROVALS_PROTOCOL)
        assert_multiline_regex(
            self,
            text,
            r"status-card\.json[\s\S]{0,160}(compact reason[- ]code|reason[- ]code\s+vocabulary)|"
            r"(compact reason[- ]code|reason[- ]code\s+vocabulary)[\s\S]{0,160}status-card\.json",
        )


if __name__ == "__main__":
    unittest.main()
