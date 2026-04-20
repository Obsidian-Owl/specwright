import { existsSync, readFileSync } from 'fs';

const STAGE_REPORT_SECTIONS = [
  'What I did',
  'Decisions digest',
  'Quality Checks',
  'Postcondition State',
  'Recommendation'
];
const REVIEW_PACKET_SECTIONS = [
  'Approval Lineage',
  'What Changed',
  'Why The Agent Implemented It This Way',
  'Spec Conformance',
  'Gate Summary',
  'Remaining Attention'
];

function readMarkdownIfPresent(path) {
  if (typeof path !== 'string' || !path.trim() || !existsSync(path)) {
    return null;
  }

  return readFileSync(path, 'utf8');
}

function collectSections(markdown) {
  const sections = new Map();
  let currentSection = null;

  for (const rawLine of markdown.split(/\r?\n/u)) {
    const headingMatch = rawLine.match(/^##\s+(.+?)\s*$/u);
    if (headingMatch) {
      currentSection = headingMatch[1].trim();
      if (!sections.has(currentSection)) {
        sections.set(currentSection, []);
      }
      continue;
    }

    if (!currentSection) {
      continue;
    }

    const line = rawLine.trim();
    if (!line || /^```/u.test(line) || /^#/u.test(line)) {
      continue;
    }

    sections.get(currentSection).push(line);
  }

  return sections;
}

function extractBullets(sections, names) {
  const bullets = [];
  const seen = new Set();

  for (const name of names) {
    for (const line of sections.get(name) ?? []) {
      const bullet = line.replace(/^[-*]\s+/u, '').replace(/^\d+\.\s+/u, '').trim();
      if (!bullet || seen.has(bullet)) {
        continue;
      }
      seen.add(bullet);
      bullets.push(bullet);
    }
  }

  return bullets;
}

export function parseStageReportDigest(markdown) {
  if (typeof markdown !== 'string' || !markdown.trim()) {
    return null;
  }

  const firstLine = markdown
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .find(Boolean);
  if (!firstLine || !firstLine.startsWith('Attention required:')) {
    return null;
  }

  return {
    source: 'stage-report',
    headline: firstLine,
    bullets: extractBullets(collectSections(markdown), STAGE_REPORT_SECTIONS)
  };
}

export function parseReviewPacketDigest(markdown) {
  if (typeof markdown !== 'string' || !markdown.trim()) {
    return null;
  }

  const bullets = extractBullets(collectSections(markdown), REVIEW_PACKET_SECTIONS);
  if (bullets.length === 0) {
    return null;
  }

  return {
    source: 'review-packet',
    headline: `Attention required: ${bullets[0]}`,
    bullets
  };
}

export function loadCloseoutDigest(options = {}) {
  const stageReportDigest = parseStageReportDigest(readMarkdownIfPresent(options.stageReportPath));
  if (stageReportDigest) {
    return stageReportDigest;
  }

  const reviewPacketDigest = parseReviewPacketDigest(readMarkdownIfPresent(options.reviewPacketPath));
  if (reviewPacketDigest) {
    return reviewPacketDigest;
  }

  return {
    source: null,
    headline: null,
    bullets: []
  };
}
