"""Regression tests for Unit 01 — closeout digest and approval foundation."""

from pathlib import Path
import re
import unittest


ROOT_DIR = Path(__file__).resolve().parents[2]
DECISION_PROTOCOL = ROOT_DIR / "core" / "protocols" / "decision.md"
REVIEW_PACKET_PROTOCOL = ROOT_DIR / "core" / "protocols" / "review-packet.md"


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


if __name__ == "__main__":
    unittest.main()
