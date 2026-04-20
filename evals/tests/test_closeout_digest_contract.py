"""Regression tests for Unit 01 — closeout digest and approval foundation."""

import json
from pathlib import Path
import re
import subprocess
import tempfile
from textwrap import dedent
import unittest


ROOT_DIR = Path(__file__).resolve().parents[2]
DECISION_PROTOCOL = ROOT_DIR / "core" / "protocols" / "decision.md"
REVIEW_PACKET_PROTOCOL = ROOT_DIR / "core" / "protocols" / "review-packet.md"
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


class TestDecisionProtocolDigestContract(unittest.TestCase):
    """Task 1 RED: the stage handoff contract must describe the human digest."""

    def setUp(self):
        self.decision_text = DECISION_PROTOCOL.read_text(encoding="utf-8")

    def test_gate_handoff_defines_digest_above_exact_footer(self):
        self.assertRegex(
            self.decision_text,
            re.compile(
                r"human(?:-facing)? closeout digest[\s\S]*above the exact three-line footer",
                re.IGNORECASE,
            ),
        )

    def test_gate_handoff_keeps_footer_as_final_three_lines(self):
        self.assertRegex(
            self.decision_text,
            re.compile(
                r"exact footer remains the final three lines",
                re.IGNORECASE,
            ),
        )


class TestReviewPacketDigestReuse(unittest.TestCase):
    """Task 1 RED: review-packet must describe how closeout reuse works."""

    def setUp(self):
        self.review_text = REVIEW_PACKET_PROTOCOL.read_text(encoding="utf-8")

    def test_review_packet_declares_it_can_feed_closeout_digest(self):
        self.assertRegex(
            self.review_text,
            re.compile(
                r"closeout digest[\s\S]*derived from.*review-packet|review-packet[\s\S]*closeout digest",
                re.IGNORECASE,
            ),
        )

    def test_review_packet_forbids_bespoke_duplicate_summary_surface(self):
        self.assertRegex(
            self.review_text,
            re.compile(
                r"must not become a second free-form summary surface",
                re.IGNORECASE,
            ),
        )


class TestApprovalsReasonVocabulary(unittest.TestCase):
    """Task 2 RED: approvals protocol and helper must agree on reason codes."""

    def setUp(self):
        self.approvals_text = APPROVALS_PROTOCOL.read_text(encoding="utf-8")

    def test_approvals_protocol_lists_reason_code_vocabulary(self):
        for reason_code in (
            "missing-entry",
            "artifact-set-changed",
            "missing-lineage",
            "expired",
            "superseded",
        ):
            with self.subTest(reason_code=reason_code):
                self.assertIn(reason_code, self.approvals_text)


class TestCloseoutHelperContract(unittest.TestCase):
    """Task 2 RED: a shared helper must derive digests from durable artifacts."""

    def test_helper_prefers_stage_report_when_present(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            stage_report = Path(tmpdir) / "stage-report.md"
            review_packet = Path(tmpdir) / "review-packet.md"
            stage_report.write_text(
                dedent(
                    """
                    Attention required: Stage report summary

                    ## What I did
                    - Added the digest contract

                    ## Decisions digest
                    - Kept the footer exact

                    ## Recommendation
                    - Continue to the next task
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )
            review_packet.write_text(
                dedent(
                    """
                    # Review Packet

                    ## Approval Lineage
                    - design: APPROVED

                    ## What Changed
                    - Protocol wording changed

                    ## Remaining Attention
                    - none
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )

            output = _run_node_json(
                f"""
                import {{ loadCloseoutDigest }} from './adapters/shared/specwright-closeout.mjs';
                const digest = loadCloseoutDigest({{
                  stageReportPath: {json.dumps(str(stage_report))},
                  reviewPacketPath: {json.dumps(str(review_packet))}
                }});
                console.log(JSON.stringify(digest));
                """
            )

            self.assertEqual(output["source"], "stage-report")
            self.assertEqual(output["headline"], "Attention required: Stage report summary")
            self.assertIn("Added the digest contract", output["bullets"])

    def test_helper_falls_back_to_review_packet(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            review_packet = Path(tmpdir) / "review-packet.md"
            review_packet.write_text(
                dedent(
                    """
                    # Review Packet

                    ## Approval Lineage
                    - design: APPROVED via /sw-plan

                    ## What Changed
                    - Protocol wording changed

                    ## Gate Summary
                    - build: PASS

                    ## Remaining Attention
                    - reviewer should confirm the wording
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )

            output = _run_node_json(
                f"""
                import {{ loadCloseoutDigest }} from './adapters/shared/specwright-closeout.mjs';
                const digest = loadCloseoutDigest({{
                  reviewPacketPath: {json.dumps(str(review_packet))}
                }});
                console.log(JSON.stringify(digest));
                """
            )

            self.assertEqual(output["source"], "review-packet")
            self.assertTrue(output["headline"].startswith("Attention required:"))
            self.assertTrue(any("design: APPROVED" in bullet for bullet in output["bullets"]))


class TestApprovalAssessmentReasons(unittest.TestCase):
    """Task 2 RED: assessment must explain why approval is not current."""

    def test_assessment_returns_reason_codes_and_hashes(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            artifact_root = Path(tmpdir)
            (artifact_root / "design.md").write_text("design v1\n", encoding="utf-8")
            (artifact_root / "context.md").write_text("context v1\n", encoding="utf-8")

            output = _run_node_json(
                f"""
                import {{
                  assessApprovalEntry,
                  createApprovalEntry
                }} from './adapters/shared/specwright-approvals.mjs';
                import fs from 'fs';

                const baseDir = {json.dumps(str(artifact_root))};
                const approved = createApprovalEntry({{
                  baseDir,
                  scope: 'design',
                  artifacts: ['design.md', 'context.md'],
                  sourceClassification: 'command',
                  sourceRef: '/sw-plan',
                  approvedAt: '2026-04-20T00:00:00Z'
                }});

                const missing = assessApprovalEntry(null, {{
                  baseDir,
                  artifacts: ['design.md', 'context.md']
                }});

                fs.writeFileSync(`${{baseDir}}/design.md`, 'design v2\\n', 'utf8');
                const changed = assessApprovalEntry(approved, {{ baseDir }});

                const expired = assessApprovalEntry({{
                  ...createApprovalEntry({{
                    baseDir,
                    scope: 'accepted-mutant',
                    unitId: 'u1',
                    mutantId: 'mut-1',
                    reason: 'equivalent',
                    configPath: 'gates.tests.mutation.acceptedMutants',
                    artifacts: ['design.md', 'context.md'],
                    sourceClassification: 'command',
                    sourceRef: '/sw-verify --accept-mutant mut-1 --reason \"equivalent\"',
                    approvedAt: '2026-04-20T00:00:00Z',
                    expiresAt: '2020-01-01T00:00:00Z'
                  }})
                }}, {{ baseDir }});

                const missingLineage = assessApprovalEntry({{
                  ...createApprovalEntry({{
                    baseDir,
                    scope: 'accepted-mutant',
                    unitId: 'u1',
                    mutantId: 'mut-2',
                    reason: 'log-only branch',
                    configPath: 'gates.tests.mutation.acceptedMutants',
                    artifacts: ['design.md', 'context.md'],
                    sourceClassification: 'command',
                    sourceRef: '/sw-verify --accept-mutant mut-2 --reason \"log-only branch\"',
                    approvedAt: '2026-04-20T00:00:00Z',
                    expiresAt: '2026-07-01T00:00:00Z'
                  }}),
                  reason: null
                }}, {{ baseDir }});

                const superseded = assessApprovalEntry({{
                  ...approved,
                  status: 'SUPERSEDED'
                }}, {{ baseDir }});

                console.log(JSON.stringify({{
                  missing,
                  changed,
                  expired,
                  missingLineage,
                  superseded
                }}));
                """
            )

            self.assertEqual(output["missing"]["reasonCode"], "missing-entry")
            self.assertEqual(output["changed"]["reasonCode"], "artifact-set-changed")
            self.assertEqual(output["expired"]["reasonCode"], "expired")
            self.assertEqual(output["missingLineage"]["reasonCode"], "missing-lineage")
            self.assertEqual(output["superseded"]["reasonCode"], "superseded")
            self.assertIn("approvedArtifactSetHash", output["changed"])
            self.assertIn("currentArtifactSetHash", output["changed"])


if __name__ == "__main__":
    unittest.main()
