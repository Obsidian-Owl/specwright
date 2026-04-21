"""Contract checks for the recovery closeout full-pipeline eval."""

import json
from pathlib import Path
import unittest


_ROOT = Path(__file__).resolve().parents[2]
_SUITE_PATH = _ROOT / "evals" / "suites" / "integration" / "evals.json"


def _load_case(eval_id: str) -> dict:
    suite = json.loads(_SUITE_PATH.read_text(encoding="utf-8"))
    for case in suite["evals"]:
        if case["id"] == eval_id:
            return case
    raise AssertionError(f"Eval case not found: {eval_id}")


class TestRecoveryCloseoutFullPipelineContract(unittest.TestCase):
    def setUp(self):
        self.case = _load_case("recovery-closeout-full-pipeline")

    def test_case_uses_codex_runner_and_constrained_instructions(self):
        self.assertEqual(self.case.get("runner"), "codex")
        instructions = self.case.get("prompt_args", {}).get("instructions", "")
        self.assertIn("single-unit", instructions)
        self.assertIn("Do not create workUnits", instructions)
        self.assertIn("Do not reopen the matching `core/skills/` SKILL.md", instructions)
        self.assertIn("Read only the files needed for the current stage", instructions)
        self.assertIn(".specwright-local/repo/work/recovery-closeout/", instructions)
        self.assertIn(".specwright-local/worktrees/main-worktree/session.json", instructions)
        self.assertNotIn(".specwright/state/workflow.json", instructions)

    def test_case_targets_single_unit_final_state(self):
        state_expectations = [
            expectation
            for expectation in self.case["expectations"]
            if expectation["type"] == "state"
        ]
        self.assertIn(
            {
                "type": "state",
                "field": "status",
                "expected": "shipped",
                "description": "Full pipeline ends in shipped state",
            },
            state_expectations,
        )
        self.assertFalse(
            any(
                expectation.get("field", "").startswith("workUnits.")
                for expectation in state_expectations
            ),
            "Full-pipeline closeout should not assert multi-unit state",
        )

    def test_case_restores_per_step_stage_report_and_handoff_proof(self):
        expectations = self.case["expectations"]
        for snapshot_index in range(5):
            self.assertIn(
                {
                    "type": "snapshot_file_exists",
                    "path": ".specwright-local/repo/work/recovery-closeout/stage-report.md",
                    "snapshot_index": snapshot_index,
                    "description": f"Step {snapshot_index} writes stage-report before handoff",
                },
                expectations,
            )
            self.assertIn(
                {
                    "type": "snapshot_file_contains",
                    "path": ".specwright-local/repo/work/recovery-closeout/stage-report.md",
                    "pattern": "^Attention required:",
                    "snapshot_index": snapshot_index,
                    "description": f"Step {snapshot_index} stage report starts with attention-required",
                },
                expectations,
            )

        handoff_expectations = [
            expectation
            for expectation in expectations
            if expectation["type"] == "step_transcript_final_block"
        ]
        self.assertEqual(len(handoff_expectations), 5)
        for step_index, expectation in enumerate(handoff_expectations):
            self.assertEqual(expectation["step_index"], step_index)
            self.assertEqual(
                expectation["line_patterns"],
                [
                    r"^Done\.\s+.+\.$",
                    r"^Artifacts:\s+.+stage-report\.md$",
                    r"^Next:\s+/sw-[a-z\-]+$",
                ],
            )
            self.assertEqual(
                expectation["forbidden_substrings"],
                [
                    "Decision Digest",
                    "Quality Checks",
                    "Deficiencies",
                    "### Recommendation",
                ],
            )

    def test_case_requires_passed_verify_gates_before_ship(self):
        self.assertIn(
            {
                "type": "gate_results",
                "expected": {"tests": "PASS", "spec": "PASS"},
                "description": "Full pipeline preserves fail-closed verify gate expectations",
            },
            self.case["expectations"],
        )


if __name__ == "__main__":
    unittest.main()
