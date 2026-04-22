"""Tests for evals.framework.prompts — pre-scripted prompt templates.

AC-11: Each template returns string with /sw-{skill} and pre-scripted decisions
AC-12: design() accepts problem_statement, plan() and build() accept no args
"""

from pathlib import Path
import re
import unittest

from evals.framework.prompts import (
    init, design, plan, build, verify, ship,
    doctor, debug, research, learn, pivot, status, sync, guard, audit,
)

ROOT_DIR = Path(__file__).resolve().parents[2]
PRIMARY_DOC_SURFACES = {
    "CLAUDE.md": ROOT_DIR / "CLAUDE.md",
    "adapters/claude-code/CLAUDE.md": ROOT_DIR / "adapters" / "claude-code" / "CLAUDE.md",
    "README.md": ROOT_DIR / "README.md",
    "DESIGN.md": ROOT_DIR / "DESIGN.md",
}
ADAPTER_COMMAND_SURFACES = {
    "codex-build": ROOT_DIR / "adapters" / "codex" / "commands" / "sw-build.md",
    "codex-verify": ROOT_DIR / "adapters" / "codex" / "commands" / "sw-verify.md",
    "codex-ship": ROOT_DIR / "adapters" / "codex" / "commands" / "sw-ship.md",
    "codex-pivot": ROOT_DIR / "adapters" / "codex" / "commands" / "sw-pivot.md",
    "opencode-build": ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-build.md",
    "opencode-verify": ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-verify.md",
    "opencode-ship": ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-ship.md",
    "opencode-pivot": ROOT_DIR / "adapters" / "opencode" / "commands" / "sw-pivot.md",
}


class TestPromptTemplatesReturnStrings(unittest.TestCase):
    """AC-11: All templates return strings."""

    def test_init_returns_string(self):
        self.assertIsInstance(init(), str)

    def test_design_returns_string(self):
        self.assertIsInstance(design("add a feature"), str)

    def test_plan_returns_string(self):
        self.assertIsInstance(plan(), str)

    def test_build_returns_string(self):
        self.assertIsInstance(build(), str)

    def test_verify_returns_string(self):
        self.assertIsInstance(verify(), str)

    def test_ship_returns_string(self):
        self.assertIsInstance(ship(), str)


class TestPromptTemplatesContainSkillInvocation(unittest.TestCase):
    """AC-11: Each template includes /sw-{skill} invocation."""

    def test_init_contains_sw_init(self):
        self.assertIn("/sw-init", init())

    def test_design_contains_sw_design(self):
        self.assertIn("/sw-design", design("test"))

    def test_plan_contains_sw_plan(self):
        self.assertIn("/sw-plan", plan())

    def test_build_contains_sw_build(self):
        self.assertIn("/sw-build", build())

    def test_verify_contains_sw_verify(self):
        self.assertIn("/sw-verify", verify())

    def test_ship_contains_sw_ship(self):
        self.assertIn("/sw-ship", ship())

    def test_doctor_contains_sw_doctor(self):
        self.assertIn("/sw-doctor", doctor())


class TestDesignTemplateEmbedsArgs(unittest.TestCase):
    """AC-12: design() accepts problem_statement and embeds it."""

    def test_problem_statement_appears_in_output(self):
        result = design("Add a GET /health endpoint")
        self.assertIn("Add a GET /health endpoint", result)

    def test_different_statements_produce_different_prompts(self):
        r1 = design("Add feature X")
        r2 = design("Fix bug Y")
        self.assertNotEqual(r1, r2)
        self.assertIn("Add feature X", r1)
        self.assertIn("Fix bug Y", r2)


class TestPlanAndBuildTakeNoArgs(unittest.TestCase):
    """AC-12: plan() and build() take zero parameters."""

    def test_plan_callable_with_no_args(self):
        # Should not raise TypeError
        plan()

    def test_build_callable_with_no_args(self):
        build()


class TestPromptTemplatesContainPreScriptedDecisions(unittest.TestCase):
    """AC-11: Templates include pre-scripted decisions to avoid AskUserQuestion."""

    def test_design_mentions_intensity(self):
        result = design("test problem")
        # Should mention Full intensity or similar decision
        lower = result.lower()
        self.assertTrue(
            "full" in lower or "intensity" in lower or "approve" in lower,
            "Design template should include pre-scripted decisions"
        )

    def test_plan_mentions_approval(self):
        result = plan()
        lower = result.lower()
        self.assertTrue(
            "approve" in lower or "accept" in lower or "spec" in lower,
            "Plan template should include pre-scripted approval"
        )

    def test_build_mentions_tdd(self):
        result = build()
        lower = result.lower()
        self.assertTrue(
            "tdd" in lower or "test" in lower or "implement" in lower or "spec" in lower,
            "Build template should reference implementation approach"
        )

    def test_build_handoff_matches_recovery_contract(self):
        result = build()
        self.assertIn("Attention required:", result)
        self.assertIn("Done. <one-line outcome>.", result)
        self.assertIn("Artifacts: <path to stage-report.md>", result)
        self.assertIn("Next: /sw-verify", result)

    def test_verify_handoff_points_to_stage_report_file(self):
        result = verify()
        self.assertIn("Attention required:", result)
        self.assertIn("Done. <one-line outcome>.", result)
        self.assertIn("Artifacts: <path to stage-report.md>", result)
        self.assertIn("Next: /sw-build or /sw-ship", result)


class TestPrimaryDocPivotSurfaces(unittest.TestCase):
    """Unit 03 Task 1 RED: primary docs must document the broadened pivot contract."""

    def test_primary_docs_frame_pivot_as_research_backed_rebaselining(self):
        for label, path in PRIMARY_DOC_SURFACES.items():
            with self.subTest(label=label):
                content = path.read_text(encoding="utf-8")
                self.assertRegex(
                    content,
                    re.compile(
                        r"sw-pivot[\s\S]{0,160}(research-backed|rebaselin)|"
                        r"(research-backed|rebaselin)[\s\S]{0,160}sw-pivot",
                        re.IGNORECASE,
                    ),
                )

    def test_primary_docs_explain_entry_states_and_preserved_scope(self):
        for label, path in PRIMARY_DOC_SURFACES.items():
            with self.subTest(label=label):
                content = path.read_text(encoding="utf-8")
                self.assertRegex(
                    content,
                    re.compile(
                        r"planning[\s\S]{0,80}building[\s\S]{0,80}verifying|"
                        r"verifying[\s\S]{0,80}building[\s\S]{0,80}planning",
                        re.IGNORECASE,
                    ),
                )
                self.assertRegex(
                    content,
                    re.compile(
                        r"(preserv|keep)[\s\S]{0,120}(completed|shipped) scope|"
                        r"(completed|shipped) scope[\s\S]{0,120}(preserv|keep)",
                        re.IGNORECASE,
                    ),
                )

    def test_primary_docs_route_history_rewrites_to_design_and_freshness_to_stage_reruns(self):
        for label, path in PRIMARY_DOC_SURFACES.items():
            with self.subTest(label=label):
                content = path.read_text(encoding="utf-8")
                self.assertRegex(
                    content,
                    re.compile(
                        r"/sw-design[\s\S]{0,160}(rewrite|history|shipped)|"
                        r"(rewrite|history|shipped)[\s\S]{0,160}/sw-design",
                        re.IGNORECASE,
                    ),
                )
                self.assertRegex(
                    content,
                    re.compile(
                        r"rebase[\s\S]{0,20}merge[\s\S]{0,160}same[\s\S]{0,20}(stage|run)|"
                        r"same[\s\S]{0,20}(stage|run)[\s\S]{0,160}rebase[\s\S]{0,20}merge",
                        re.IGNORECASE,
                    ),
                )
                self.assertRegex(
                    content,
                    re.compile(
                        r"manual[\s\S]{0,120}(explicit )?fallback|"
                        r"(explicit )?fallback[\s\S]{0,120}manual",
                        re.IGNORECASE,
                    ),
                )
                self.assertRegex(
                    content,
                    re.compile(
                        r"/sw-verify[\s\S]{0,80}/sw-ship|"
                        r"/sw-ship[\s\S]{0,80}/sw-verify",
                        re.IGNORECASE,
                    ),
                )


class TestAdapterCommandSurfaces(unittest.TestCase):
    """Unit 03 Task 2 RED: adapter command docs must align with pivot and reconcile semantics."""

    def test_adapter_pivot_commands_describe_research_backed_rebaselining(self):
        for label in ("codex-pivot", "opencode-pivot"):
            content = ADAPTER_COMMAND_SURFACES[label].read_text(encoding="utf-8")
            with self.subTest(label=label):
                self.assertRegex(
                    content,
                    re.compile(
                        r"(research-backed|rebaselin)[\s\S]{0,120}(planning|building|verifying)|"
                        r"(planning|building|verifying)[\s\S]{0,120}(research-backed|rebaselin)",
                        re.IGNORECASE,
                    ),
                )
                self.assertRegex(
                    content,
                    re.compile(
                        r"(preserv|keep)[\s\S]{0,120}(completed|shipped) scope|"
                        r"(completed|shipped) scope[\s\S]{0,120}(preserv|keep)",
                        re.IGNORECASE,
                    ),
                )

    def test_adapter_build_verify_ship_commands_describe_lifecycle_recovery_and_manual_fallback(self):
        expectations = {
            "codex-build": r"rebase[\s\S]{0,20}merge[\s\S]{0,120}recover in-stage[\s\S]{0,120}manual[\s\S]{0,40}fallback",
            "opencode-build": r"rebase[\s\S]{0,20}merge[\s\S]{0,120}recover in-stage[\s\S]{0,120}manual[\s\S]{0,40}fallback",
            "codex-verify": r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same run[\s\S]{0,120}manual[\s\S]{0,60}fallback[\s\S]{0,80}/sw-verify",
            "opencode-verify": r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same run[\s\S]{0,120}manual[\s\S]{0,60}fallback[\s\S]{0,80}/sw-verify",
            "codex-ship": r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same run[\s\S]{0,120}manual[\s\S]{0,60}fallback[\s\S]{0,140}/sw-verify[\s\S]{0,80}/sw-ship",
            "opencode-ship": r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same run[\s\S]{0,120}manual[\s\S]{0,60}fallback[\s\S]{0,140}/sw-verify[\s\S]{0,80}/sw-ship",
        }
        for label, pattern in expectations.items():
            content = ADAPTER_COMMAND_SURFACES[label].read_text(encoding="utf-8")
            with self.subTest(label=label):
                self.assertRegex(content, re.compile(pattern, re.IGNORECASE))


class TestPromptTemplatePivotAndFreshnessGuidance(unittest.TestCase):
    """Unit 03 Task 2 RED: prompt templates must encode the broadened pivot contract."""

    def test_pivot_prompt_uses_research_backed_rebaselining(self):
        result = pivot()
        self.assertRegex(
            result,
            re.compile(
                r"(research-backed|rebaselin)[\s\S]{0,160}(planning|building|verifying)|"
                r"(planning|building|verifying)[\s\S]{0,160}(research-backed|rebaselin)",
                re.IGNORECASE,
            ),
        )
        self.assertRegex(
            result,
            re.compile(
                r"(preserv|keep)[\s\S]{0,120}(completed|shipped) scope|"
                r"(completed|shipped) scope[\s\S]{0,120}(preserv|keep)",
                re.IGNORECASE,
            ),
        )
        self.assertRegex(
            result,
            re.compile(
                r"/sw-design[\s\S]{0,160}(rewrite|history|shipped)|"
                r"(rewrite|history|shipped)[\s\S]{0,160}/sw-design",
                re.IGNORECASE,
            ),
        )

    def test_build_prompt_prefers_same_stage_recovery_and_keeps_manual_as_fallback(self):
        result = build()
        self.assertRegex(
            result,
            re.compile(r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same[\s\S]{0,20}stage", re.IGNORECASE),
        )
        self.assertRegex(
            result,
            re.compile(r"manual[\s\S]{0,120}explicit fallback[\s\S]{0,120}/sw-build", re.IGNORECASE),
        )
        self.assertRegex(
            result,
            re.compile(r"do not rewrite[\s\S]{0,60}target metadata", re.IGNORECASE),
        )

    def test_verify_prompt_prefers_same_run_recovery_without_build_loop(self):
        for label, result in (
            ("default", verify()),
            ("gated", verify("security")),
        ):
            with self.subTest(label=label):
                self.assertRegex(
                    result,
                    re.compile(r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same[\s\S]{0,20}verify run", re.IGNORECASE),
                )
                self.assertRegex(
                    result,
                    re.compile(r"manual[\s\S]{0,120}explicit fallback[\s\S]{0,120}/sw-verify", re.IGNORECASE),
                )
                self.assertRegex(result, re.compile(r"do not[\s\S]{0,120}/sw-build", re.IGNORECASE))

    def test_ship_prompt_prefers_same_run_recovery_and_manual_verify_then_ship_fallback(self):
        result = ship()
        self.assertRegex(
            result,
            re.compile(r"rebase[\s\S]{0,20}merge[\s\S]{0,120}same[\s\S]{0,20}run", re.IGNORECASE),
        )
        self.assertRegex(
            result,
            re.compile(r"manual[\s\S]{0,120}explicit fallback[\s\S]{0,180}/sw-verify[\s\S]{0,80}/sw-ship", re.IGNORECASE),
        )
        self.assertIn("STOP and report", result)
        self.assertIn("in a separate", result)


class TestPromptAndDocRegressionCoverage(unittest.TestCase):
    """Unit 03 Task 3 RED: touched surfaces must not drift back to the old loop-prone contract."""

    def test_pivot_surfaces_do_not_reintroduce_mid_build_remaining_task_wording(self):
        surfaces = {
            **{
                label: path.read_text(encoding="utf-8")
                for label, path in PRIMARY_DOC_SURFACES.items()
            },
            **{
                label: path.read_text(encoding="utf-8")
                for label, path in ADAPTER_COMMAND_SURFACES.items()
                if label.endswith("pivot")
            },
            "prompt-pivot-default": pivot(),
            "prompt-pivot-change": pivot("Expand the active work without discarding shipped scope."),
        }
        forbidden_patterns = [
            r"mid-build course correction",
            r"remaining-task-only",
            r"remaining tasks only",
            r"mid-build[\s\S]{0,40}remaining tasks",
        ]
        for label, content in surfaces.items():
            with self.subTest(label=label):
                for pattern in forbidden_patterns:
                    self.assertNotRegex(content, re.compile(pattern, re.IGNORECASE))

    def test_pivot_summary_rows_keep_completed_and_shipped_scope_visible(self):
        patterns = {
            "CLAUDE.md": r"\|\s*`sw-pivot`\s*\|[^\n]*(completed[^\n]*shipped|shipped[^\n]*completed)",
            "adapters/claude-code/CLAUDE.md": r"\|\s*`sw-pivot`\s*\|[^\n]*(completed[^\n]*shipped|shipped[^\n]*completed)",
            "README.md": r"\|\s*`/sw-pivot`\s*\|[^\n]*(completed[^\n]*shipped|shipped[^\n]*completed)",
            "DESIGN.md": r"\|\s*`sw-pivot`\s*\|[^\n]*(completed[^\n]*shipped|shipped[^\n]*completed)",
        }
        for label, path in PRIMARY_DOC_SURFACES.items():
            content = path.read_text(encoding="utf-8")
            with self.subTest(label=label):
                self.assertRegex(content, re.compile(patterns[label], re.IGNORECASE))

    def test_verify_surfaces_do_not_redirect_back_to_build_without_reconcile_context(self):
        surfaces = {
            "codex-verify": ADAPTER_COMMAND_SURFACES["codex-verify"].read_text(encoding="utf-8"),
            "opencode-verify": ADAPTER_COMMAND_SURFACES["opencode-verify"].read_text(encoding="utf-8"),
            "prompt-verify-default": verify(),
            "prompt-verify-gated": verify("security"),
        }
        negative_build_redirect = re.compile(
            r"(do not|instead of)[\s\S]{0,80}/sw-build|/sw-build[\s\S]{0,80}(do not|instead of)",
            re.IGNORECASE,
        )
        for label, content in surfaces.items():
            with self.subTest(label=label):
                self.assertRegex(
                    content,
                    re.compile(r"rebase[\s\S]{0,20}merge[\s\S]{0,140}same[\s\S]{0,20}(verify )?run", re.IGNORECASE),
                )
                self.assertRegex(
                    content,
                    re.compile(r"manual[\s\S]{0,80}fallback|fallback[\s\S]{0,80}manual", re.IGNORECASE),
                )
                self.assertRegex(content, re.compile(r"/sw-verify", re.IGNORECASE))
                if "/sw-build" in content:
                    self.assertRegex(content, negative_build_redirect)

    def test_default_pivot_prompt_rejects_invented_commands(self):
        for label, result in (
            ("default", pivot()),
            ("with-change", pivot("Expand the active work without discarding shipped scope.")),
        ):
            with self.subTest(label=label):
                self.assertRegex(
                    result,
                    re.compile(r"do not invent a new command[\s\S]{0,40}extra confirmation", re.IGNORECASE),
                )


class TestNewPromptTemplates(unittest.TestCase):
    """New templates return non-empty strings with default args."""

    def test_debug_returns_string(self):
        self.assertIsInstance(debug(), str)
        self.assertTrue(len(debug()) > 0)

    def test_debug_with_error_output(self):
        result = debug(error_output="TypeError: undefined is not a function")
        self.assertIn("TypeError", result)

    def test_research_returns_string(self):
        self.assertIsInstance(research(), str)
        self.assertTrue(len(research()) > 0)

    def test_doctor_returns_string(self):
        self.assertIsInstance(doctor(), str)
        self.assertTrue(len(doctor()) > 0)

    def test_research_with_topic(self):
        result = research(topic="GraphQL pagination patterns")
        self.assertIn("GraphQL", result)

    def test_learn_returns_string(self):
        self.assertIsInstance(learn(), str)
        self.assertTrue(len(learn()) > 0)

    def test_pivot_returns_string(self):
        self.assertIsInstance(pivot(), str)
        self.assertTrue(len(pivot()) > 0)

    def test_pivot_with_change(self):
        result = pivot(change_description="Switch from REST to GraphQL")
        self.assertIn("GraphQL", result)

    def test_status_returns_string(self):
        self.assertIsInstance(status(), str)
        self.assertTrue(len(status()) > 0)

    def test_status_repair_embeds_unit_id(self):
        result = status(repair_unit_id="02d-structural-smoke-evals")
        self.assertIn("--repair 02d-structural-smoke-evals", result)

    def test_status_repair_headless_mentions_report_only(self):
        result = status(repair_unit_id="02d-structural-smoke-evals", headless=True)
        self.assertIn("non-interactive", result)
        self.assertIn("report-only", result)

    def test_ship_handoff_matches_recovery_contract(self):
        result = ship()
        self.assertIn("Attention required:", result)
        self.assertIn("Done. <one-line outcome>.", result)
        self.assertIn("Artifacts: <path to stage-report.md>", result)
        self.assertIn("Use the documented `gh` command path directly.", result)
        self.assertIn("Do not reopen `core/skills/sw-ship/SKILL.md`", result)
        self.assertIn("run exactly one", result)

    def test_doctor_prompt_treats_path_shims_as_stock_tools(self):
        result = doctor()
        self.assertIn("Assume PATH-provided CLI shims behave like their stock tools.", result)
        self.assertIn("Never modify `status`", result)
        self.assertIn("Do not reopen `core/skills/sw-doctor/SKILL.md`", result)

    def test_sync_returns_string(self):
        self.assertIsInstance(sync(), str)
        self.assertTrue(len(sync()) > 0)

    def test_guard_returns_string(self):
        self.assertIsInstance(guard(), str)
        self.assertTrue(len(guard()) > 0)

    def test_audit_returns_string(self):
        self.assertIsInstance(audit(), str)
        self.assertTrue(len(audit()) > 0)

    def test_audit_with_scope(self):
        result = audit(scope="src/handlers/")
        self.assertIn("src/handlers/", result)


if __name__ == "__main__":
    unittest.main()
