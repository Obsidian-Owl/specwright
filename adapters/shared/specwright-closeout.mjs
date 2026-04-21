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
export const CLOSEOUT_ABSENCE_LINE = 'Closeout: none yet (no stage-report.md or review-packet.md)';
const FENCED_BLOCK_MARKER_PATTERN = /^```/u;
const MARKDOWN_HEADING_PATTERN = /^#{1,6}\s/u;

function readMarkdownIfPresent(path) {
  if (typeof path !== 'string' || !path.trim() || !existsSync(path)) {
    return null;
  }

  return readFileSync(path, 'utf8');
}

function collectSections(markdown) {
  const sections = new Map();
  let currentSection = null;
  let inFencedBlock = false;

  for (const rawLine of markdown.split(/\r?\n/u)) {
    const line = rawLine.trim();
    if (FENCED_BLOCK_MARKER_PATTERN.test(line)) {
      inFencedBlock = !inFencedBlock;
      continue;
    }

    if (inFencedBlock) {
      continue;
    }

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

    if (!line || MARKDOWN_HEADING_PATTERN.test(line)) {
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

function selectReviewPacketHeadline(sections, bullets) {
  const remainingAttentionBullets = extractBullets(sections, ['Remaining Attention']);
  const prioritizedBullet = remainingAttentionBullets.find(
    (bullet) => bullet.toLowerCase() !== 'none'
  ) ?? bullets[0] ?? null;

  if (!prioritizedBullet) {
    return null;
  }

  return `Attention required: ${prioritizedBullet}`;
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

  const sections = collectSections(markdown);
  const bullets = extractBullets(sections, REVIEW_PACKET_SECTIONS);
  if (bullets.length === 0) {
    return null;
  }

  return {
    source: 'review-packet',
    headline: selectReviewPacketHeadline(sections, bullets),
    bullets
  };
}

export function loadCloseoutDigest(options = {}) {
  const stageReportDigest = parseStageReportDigest(readMarkdownIfPresent(options.stageReportPath));
  if (stageReportDigest) {
    return normalizeCloseoutDigest(stageReportDigest);
  }

  const reviewPacketDigest = parseReviewPacketDigest(readMarkdownIfPresent(options.reviewPacketPath));
  if (reviewPacketDigest) {
    return normalizeCloseoutDigest(reviewPacketDigest);
  }

  return normalizeCloseoutDigest(null);
}

export function normalizeCloseoutDigest(digest) {
  return {
    source: typeof digest?.source === 'string' && digest.source.trim() ? digest.source : null,
    headline: typeof digest?.headline === 'string' && digest.headline.trim() ? digest.headline : null,
    bullets: Array.isArray(digest?.bullets) ? digest.bullets.filter(Boolean) : []
  };
}

export function formatCloseoutLines(digest, options = {}) {
  const normalized = normalizeCloseoutDigest(digest);
  const indent = options.indent ?? '  ';
  const detailIndent = options.detailIndent ?? `${indent}  `;
  const bulletIndent = options.bulletIndent ?? `${detailIndent}- `;

  if (!normalized.source) {
    return [`${indent}${CLOSEOUT_ABSENCE_LINE}`];
  }

  const lines = [`${indent}Closeout: ${normalized.source}`];
  if (normalized.headline) {
    lines.push(`${detailIndent}${normalized.headline}`);
  }

  for (const bullet of normalized.bullets.slice(0, 2)) {
    lines.push(`${bulletIndent}${bullet}`);
  }

  return lines;
}
