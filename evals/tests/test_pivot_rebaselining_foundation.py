"""Regression tests for Unit 01 — pivot rebaselining foundation."""

import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT_DIR = Path(__file__).resolve().parents[2]
PIVOT_SKILL = ROOT_DIR / "core" / "skills" / "sw-pivot" / "SKILL.md"
STATE_PROTOCOL = ROOT_DIR / "core" / "protocols" / "state.md"
APPROVALS_PROTOCOL = ROOT_DIR / "core" / "protocols" / "approvals.md"


def _run_node_json(script: str) -> dict:
    result = subprocess.run(
        ["node", "--input-type=module", "-"],
        input=script,
        text=True,
        capture_output=True,
        cwd=ROOT_DIR,
        check=False,
    )
    if result.returncode != 0:
        raise AssertionError(result.stderr or result.stdout or "node execution failed")
    return json.loads(result.stdout)


class TestPivotRebaseliningContract(unittest.TestCase):
    """Task 1 RED: sw-pivot must stop describing the narrow build-only contract."""

    def setUp(self):
        self.pivot_text = PIVOT_SKILL.read_text(encoding="utf-8")
        self.state_text = STATE_PROTOCOL.read_text(encoding="utf-8")

    def test_goal_reframes_pivot_as_research_backed_rebaselining(self):
        self.assertRegex(
            self.pivot_text,
            re.compile(
                r"research[- ]backed[\s\S]*rebaselin|rebaselin[\s\S]*research[- ]backed",
                re.IGNORECASE,
            ),
        )

    def test_skill_declares_task_unit_and_work_pivot_classes(self):
        for pivot_class in ("task-pivot", "unit-pivot", "work-pivot"):
            with self.subTest(pivot_class=pivot_class):
                self.assertIn(pivot_class, self.pivot_text)

    def test_precondition_accepts_planning_building_and_verifying(self):
        self.assertRegex(
            self.pivot_text,
            re.compile(
                r"planning[\s\S]*building[\s\S]*verifying|verifying[\s\S]*planning[\s\S]*building",
                re.IGNORECASE,
            ),
        )

    def test_failure_modes_no_longer_claim_building_only(self):
        self.assertNotRegex(
            self.pivot_text,
            re.compile(r"Status not `?building`?|only valid during active sw-build", re.IGNORECASE),
        )

    def test_state_protocol_mentions_pivot_return_to_building_without_new_status(self):
        self.assertRegex(
            self.state_text,
            re.compile(
                r"sw-pivot[\s\S]*returns?.*building|building[\s\S]*sw-pivot[\s\S]*without.*new.*status",
                re.IGNORECASE,
            ),
        )

    def test_skill_requires_closeout_summary_for_preserved_scope_and_stale_reasons(self):
        self.assertRegex(
            self.pivot_text,
            re.compile(
                r"preserved(?: completed)? scope[\s\S]*delta scope[\s\S]*affected units[\s\S]*"
                r"(missing-entry|artifact-set-changed|missing-lineage|expired|superseded)",
                re.IGNORECASE,
            ),
        )


class TestPivotApprovalLineage(unittest.TestCase):
    """Task 2 RED: approvals must describe and prove pivot stale-lineage handling."""

    def setUp(self):
        self.approvals_text = APPROVALS_PROTOCOL.read_text(encoding="utf-8")

    def test_approvals_protocol_assigns_sw_pivot_lineage_reassessment(self):
        self.assertRegex(
            self.approvals_text,
            re.compile(
                r"sw-pivot[\s\S]*(design|unit-spec)[\s\S]*(stale|freshness)|"
                r"(design|unit-spec)[\s\S]*sw-pivot[\s\S]*(stale|freshness)",
                re.IGNORECASE,
            ),
        )

    def test_helper_marks_design_and_unit_entries_stale_after_pivot_artifact_change(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            output = _run_node_json(
                f"""
                import {{
                  defaultApprovalsDocument,
                  recordApproval,
                  assessApprovalEntry
                }} from './adapters/shared/specwright-approvals.mjs';
                import {{ mkdirSync, writeFileSync }} from 'fs';
                import {{ join }} from 'path';

                const workRoot = {json.dumps(tmpdir)};
                const unitRoot = join(workRoot, 'units', '01-pivot');
                mkdirSync(unitRoot, {{ recursive: true }});

                writeFileSync(join(workRoot, 'design.md'), 'design v1\\n');
                writeFileSync(join(workRoot, 'context.md'), 'context v1\\n');
                writeFileSync(join(workRoot, 'decisions.md'), 'decisions v1\\n');
                writeFileSync(join(workRoot, 'assumptions.md'), 'assumptions v1\\n');
                writeFileSync(join(unitRoot, 'spec.md'), 'spec v1\\n');
                writeFileSync(join(unitRoot, 'plan.md'), 'plan v1\\n');
                writeFileSync(join(unitRoot, 'context.md'), 'unit context v1\\n');

                let doc = defaultApprovalsDocument();
                doc = recordApproval(doc, {{
                  baseDir: workRoot,
                  scope: 'design',
                  sourceClassification: 'command',
                  sourceRef: '/sw-plan',
                  artifacts: ['assumptions.md', 'context.md', 'decisions.md', 'design.md'],
                  approvedAt: '2026-04-20T00:00:00Z'
                }});
                doc = recordApproval(doc, {{
                  baseDir: unitRoot,
                  scope: 'unit-spec',
                  unitId: '01-pivot',
                  sourceClassification: 'command',
                  sourceRef: '/sw-build',
                  artifacts: ['context.md', 'plan.md', 'spec.md'],
                  approvedAt: '2026-04-20T00:05:00Z'
                }});

                writeFileSync(join(workRoot, 'design.md'), 'design v2\\n');
                writeFileSync(join(unitRoot, 'spec.md'), 'spec v2\\n');

                const designAssessment = assessApprovalEntry(doc.entries[0], {{
                  baseDir: workRoot,
                  artifacts: ['assumptions.md', 'context.md', 'decisions.md', 'design.md']
                }});
                const unitAssessment = assessApprovalEntry(doc.entries[1], {{
                  baseDir: unitRoot,
                  artifacts: ['context.md', 'plan.md', 'spec.md']
                }});

                console.log(JSON.stringify({{
                  designStatus: designAssessment.status,
                  designReason: designAssessment.reasonCode,
                  unitStatus: unitAssessment.status,
                  unitReason: unitAssessment.reasonCode
                }}));
                """
            )

            self.assertEqual(output["designStatus"], "STALE")
            self.assertEqual(output["designReason"], "artifact-set-changed")
            self.assertEqual(output["unitStatus"], "STALE")
            self.assertEqual(output["unitReason"], "artifact-set-changed")


if __name__ == "__main__":
    unittest.main()
