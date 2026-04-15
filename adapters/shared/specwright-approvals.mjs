import { createHash } from 'crypto';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'fs';
import { dirname, relative, resolve } from 'path';

export const APPROVAL_STATUS_VALUES = ['APPROVED', 'STALE', 'SUPERSEDED'];
export const APPROVAL_SOURCE_CLASSIFICATIONS = [
  'command',
  'review-comment',
  'external-record',
  'headless-check'
];

const LEDGER_START = '<!-- approvals-ledger:start -->';
const LEDGER_END = '<!-- approvals-ledger:end -->';

function sha256Hex(value) {
  return createHash('sha256').update(value).digest('hex');
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function normalizeStatus(value) {
  return APPROVAL_STATUS_VALUES.includes(value) ? value : 'APPROVED';
}

function normalizeSourceClassification(value) {
  return APPROVAL_SOURCE_CLASSIFICATIONS.includes(value) ? value : 'command';
}

function normalizeArtifactPath(baseDir, artifactPath) {
  const resolvedPath = resolve(baseDir, artifactPath);
  const relativePath = relative(baseDir, resolvedPath).replace(/[\\]/gu, '/');
  return relativePath.replace(/^\.\//u, '');
}

function cloneDocument(document) {
  return JSON.parse(JSON.stringify(document ?? defaultApprovalsDocument()));
}

function validateApprovalSource(status, sourceClassification) {
  if (status === 'APPROVED' && sourceClassification === 'headless-check') {
    throw new Error('Headless checks must not create APPROVED approval entries.');
  }
}

export function defaultApprovalsDocument() {
  return {
    version: '1.0',
    entries: []
  };
}

export function hashApprovalArtifacts(baseDir, artifactPaths = []) {
  const normalizedPaths = [...new Set(
    artifactPaths
      .map((artifactPath) => normalizeArtifactPath(baseDir, artifactPath))
      .filter(Boolean)
  )].sort();

  const artifacts = normalizedPaths.map((artifactPath) => {
    const absolutePath = resolve(baseDir, artifactPath);
    const exists = existsSync(absolutePath);
    const contents = exists ? readFileSync(absolutePath) : Buffer.from('');

    return {
      path: artifactPath,
      exists,
      contentHash: exists ? `sha256:${sha256Hex(contents)}` : null
    };
  });

  const manifest = artifacts
    .map((artifact) => `${artifact.path}\n${artifact.exists ? artifact.contentHash : 'missing'}`)
    .join('\n---\n');

  return {
    artifactSetHash: `sha256:${sha256Hex(manifest)}`,
    artifacts
  };
}

export function createApprovalEntry(options = {}) {
  const baseDir = options.baseDir ?? process.cwd();
  const scope = normalizeString(options.scope) ?? 'design';
  const unitId = normalizeString(options.unitId);
  const status = normalizeStatus(options.status);
  const sourceClassification = normalizeSourceClassification(options.sourceClassification);
  const sourceRef = normalizeString(options.sourceRef);

  validateApprovalSource(status, sourceClassification);

  const hashedArtifacts = hashApprovalArtifacts(baseDir, options.artifacts ?? []);

  return {
    scope,
    unitId,
    status,
    source: {
      classification: sourceClassification,
      ref: sourceRef
    },
    artifactSetHash: hashedArtifacts.artifactSetHash,
    artifacts: hashedArtifacts.artifacts.map((artifact) => artifact.path),
    approvedAt: normalizeString(options.approvedAt),
    notes: normalizeString(options.notes)
  };
}

export function recordApproval(document, options = {}) {
  const nextDocument = cloneDocument(document);
  const entry = createApprovalEntry(options);

  nextDocument.entries = (nextDocument.entries ?? []).map((existingEntry) => {
    if (
      existingEntry?.scope === entry.scope &&
      (existingEntry?.unitId ?? null) === entry.unitId &&
      existingEntry?.status !== 'SUPERSEDED'
    ) {
      return {
        ...existingEntry,
        status: 'SUPERSEDED'
      };
    }

    return existingEntry;
  });

  nextDocument.entries.push(entry);
  return nextDocument;
}

export function assessApprovalEntry(entry, options = {}) {
  const normalizedStatus = normalizeStatus(entry?.status);
  if (normalizedStatus === 'SUPERSEDED') {
    return {
      status: 'SUPERSEDED',
      artifactSetHash: entry?.artifactSetHash ?? null
    };
  }

  const baseDir = options.baseDir ?? process.cwd();
  const artifacts = Array.isArray(options.artifacts)
    ? options.artifacts
    : (Array.isArray(entry?.artifacts) ? entry.artifacts : []);
  const current = hashApprovalArtifacts(baseDir, artifacts);

  if (current.artifactSetHash !== entry?.artifactSetHash) {
    return {
      status: 'STALE',
      artifactSetHash: current.artifactSetHash
    };
  }

  return {
    status: normalizedStatus === 'STALE' ? 'STALE' : 'APPROVED',
    artifactSetHash: current.artifactSetHash
  };
}

export function serializeApprovalsMarkdown(document) {
  const normalized = cloneDocument(document);
  const summary = (normalized.entries ?? []).length === 0
    ? ['- No approvals recorded yet.']
    : normalized.entries.map((entry) => {
      const unitSuffix = entry.unitId ? ` (${entry.unitId})` : '';
      const sourceRef = entry.source?.ref ? ` via ${entry.source.ref}` : '';
      return `- ${entry.scope}${unitSuffix}: ${entry.status}${sourceRef}`;
    });

  return [
    '# Approvals',
    '',
    'Durable human approval checkpoints for this work.',
    '',
    ...summary,
    '',
    LEDGER_START,
    '```json',
    JSON.stringify(normalized, null, 2),
    '```',
    LEDGER_END,
    ''
  ].join('\n');
}

export function parseApprovalsMarkdown(markdown) {
  const match = markdown.match(
    /<!-- approvals-ledger:start -->\s*```json\s*([\s\S]*?)\s*```\s*<!-- approvals-ledger:end -->/u
  );
  if (!match) {
    return defaultApprovalsDocument();
  }

  try {
    const parsed = JSON.parse(match[1]);
    return {
      version: normalizeString(parsed.version) ?? '1.0',
      entries: Array.isArray(parsed.entries) ? parsed.entries : []
    };
  } catch {
    return defaultApprovalsDocument();
  }
}

export function loadApprovalsFile(path) {
  if (!existsSync(path)) {
    return defaultApprovalsDocument();
  }

  return parseApprovalsMarkdown(readFileSync(path, 'utf8'));
}

export function writeApprovalsFile(path, document) {
  mkdirSync(dirname(path), { recursive: true });
  const contents = serializeApprovalsMarkdown(document);
  writeFileSync(path, contents, 'utf8');
  return contents;
}
