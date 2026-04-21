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
export const APPROVAL_REASON_CODES = [
  'missing-entry',
  'artifact-set-changed',
  'missing-lineage',
  'expired',
  'superseded'
];
export const APPROVAL_CURRENT_REASON_CODE = 'approved';
export const DEFAULT_ACCEPTED_MUTANT_EXPIRY_DAYS = 90;
export const APPROVAL_ASSESSMENT_STATUS_VALUES = [
  ...APPROVAL_STATUS_VALUES,
  'MISSING'
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

function normalizeEnumValue(value, allowedValues, fieldName) {
  if (value === undefined || value === null) {
    return null;
  }

  if (typeof value !== 'string') {
    throw new Error(`${fieldName} must be a string.`);
  }

  const normalizedValue = value.trim();
  if (!normalizedValue || !allowedValues.includes(normalizedValue)) {
    throw new Error(
      `Unknown ${fieldName}: ${JSON.stringify(value)}. Expected one of: ${allowedValues.join(', ')}`
    );
  }

  return normalizedValue;
}

function normalizeArtifactPath(baseDir, artifactPath) {
  if (typeof artifactPath !== 'string') {
    throw new Error('Artifact paths must be strings.');
  }

  const trimmedPath = artifactPath.trim();
  if (!trimmedPath) {
    throw new Error('Artifact paths must be non-empty strings.');
  }

  const resolvedPath = resolve(baseDir, trimmedPath);
  const relativePath = relative(baseDir, resolvedPath).replace(/[\\]/gu, '/');
  const normalizedPath = relativePath.replace(/^\.\//u, '');

  if (!normalizedPath || normalizedPath === '.' || normalizedPath === '..' || normalizedPath.startsWith('../')) {
    throw new Error(`Artifact path escapes baseDir: ${JSON.stringify(artifactPath)}`);
  }

  return normalizedPath;
}

function cloneDocument(document) {
  return JSON.parse(JSON.stringify(document ?? defaultApprovalsDocument()));
}

function validateApprovalSource(status, sourceClassification) {
  if (status === 'APPROVED' && sourceClassification === 'headless-check') {
    throw new Error('Headless checks must not create APPROVED approval entries.');
  }
}

function defaultAcceptedMutantExpiry(approvedAt) {
  const approvedDate = approvedAt ? new Date(approvedAt) : new Date();
  if (Number.isNaN(approvedDate.getTime())) {
    throw new Error('accepted-mutant approvals require a valid approvedAt timestamp.');
  }

  return new Date(
    approvedDate.getTime() + (DEFAULT_ACCEPTED_MUTANT_EXPIRY_DAYS * 24 * 60 * 60 * 1000)
  ).toISOString();
}

function isAcceptedMutantScope(scope) {
  return scope === 'accepted-mutant';
}

function normalizeAcceptedMutantLineage(entry) {
  return {
    unitId: normalizeString(entry?.unitId),
    mutantId: normalizeString(entry?.mutantId),
    reason: normalizeString(entry?.reason),
    configPath: normalizeString(entry?.configPath),
    approvedAt: normalizeString(entry?.approvedAt),
    expiresAt: normalizeString(entry?.expiresAt)
  };
}

function createAssessmentResult({
  status,
  reasonCode = null,
  artifactSetHash = null,
  approvedArtifactSetHash = null,
  currentArtifactSetHash = null
}) {
  return {
    status,
    reasonCode,
    artifactSetHash,
    approvedArtifactSetHash,
    currentArtifactSetHash
  };
}

export function findLatestApprovalEntry(entries, { scope, unitId } = {}) {
  if (!Array.isArray(entries)) {
    return null;
  }

  for (let index = entries.length - 1; index >= 0; index -= 1) {
    const entry = entries[index];
    if (scope != null && entry?.scope !== scope) {
      continue;
    }

    if (unitId !== undefined && (entry?.unitId ?? null) !== (unitId ?? null)) {
      continue;
    }

    return entry;
  }

  return null;
}

export function summarizeApprovalAssessment(scope, assessment) {
  const normalizedScope = normalizeString(scope) ?? 'approval';
  const normalizedStatus = normalizeString(assessment?.status) ?? 'MISSING';
  const reasonCode = normalizeString(assessment?.reasonCode)
    ?? (normalizedStatus === 'APPROVED' ? APPROVAL_CURRENT_REASON_CODE : 'unknown');

  return {
    scope: normalizedScope,
    status: normalizedStatus,
    reasonCode,
    summary: normalizedStatus === 'APPROVED'
      ? `${normalizedScope} approval is current.`
      : `${normalizedScope} approval needs attention (${reasonCode}).`
  };
}

export function formatApprovalStatusLine(summary, options = {}) {
  if (!summary) {
    return null;
  }

  const indent = options.indent ?? '  ';
  return `${indent}Approval: ${summary.scope} ${summary.status} (${summary.reasonCode})`;
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
  const status = normalizeEnumValue(
    options.status,
    APPROVAL_STATUS_VALUES,
    'approval status'
  ) ?? 'APPROVED';
  const sourceClassification = normalizeEnumValue(
    options.sourceClassification,
    APPROVAL_SOURCE_CLASSIFICATIONS,
    'source classification'
  ) ?? 'command';
  const sourceRef = normalizeString(options.sourceRef);

  validateApprovalSource(status, sourceClassification);

  const hashedArtifacts = hashApprovalArtifacts(baseDir, options.artifacts ?? []);
  const approvedAt = normalizeString(options.approvedAt);
  const mutantId = normalizeString(options.mutantId);
  const reason = normalizeString(options.reason);
  const configPath = normalizeString(options.configPath);
  const expiresAt = normalizeString(options.expiresAt);
  const isAcceptedMutant = isAcceptedMutantScope(scope);

  if (isAcceptedMutant) {
    if (!unitId) {
      throw new Error('accepted-mutant approvals require a unitId.');
    }
    if (!mutantId) {
      throw new Error('accepted-mutant approvals require a mutantId.');
    }
    if (!reason) {
      throw new Error('accepted-mutant approvals require a reason.');
    }
    if (!configPath) {
      throw new Error('accepted-mutant approvals require a configPath.');
    }
  }

  const resolvedApprovedAt = isAcceptedMutant ? (approvedAt ?? new Date().toISOString()) : approvedAt;

  const baseEntry = {
    scope,
    unitId,
    status,
    source: {
      classification: sourceClassification,
      ref: sourceRef
    },
    artifactSetHash: hashedArtifacts.artifactSetHash,
    artifacts: hashedArtifacts.artifacts.map((artifact) => artifact.path),
    approvedAt: resolvedApprovedAt,
    notes: normalizeString(options.notes)
  };

  if (!isAcceptedMutant) {
    return baseEntry;
  }

  return {
    ...baseEntry,
    mutantId,
    reason,
    configPath,
    expiresAt: expiresAt ?? defaultAcceptedMutantExpiry(resolvedApprovedAt)
  };
}

export function recordApproval(document, options = {}) {
  const nextDocument = cloneDocument(document);
  const entry = createApprovalEntry(options);

  nextDocument.entries = (nextDocument.entries ?? []).map((existingEntry) => {
    const sameScope = existingEntry?.scope === entry.scope;
    const sameUnit = (existingEntry?.unitId ?? null) === entry.unitId;
    const sameAcceptedMutant =
      isAcceptedMutantScope(entry.scope) &&
      sameScope &&
      sameUnit &&
      (existingEntry?.mutantId ?? null) === (entry?.mutantId ?? null);
    const sameApprovalSlot =
      isAcceptedMutantScope(entry.scope)
        ? sameAcceptedMutant
        : (sameScope && sameUnit);

    if (sameApprovalSlot && existingEntry?.status !== 'SUPERSEDED') {
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
  const baseDir = options.baseDir ?? process.cwd();
  const artifacts = Array.isArray(options.artifacts)
    ? options.artifacts
    : (Array.isArray(entry?.artifacts) ? entry.artifacts : []);
  const current = hashApprovalArtifacts(baseDir, artifacts);

  if (entry == null) {
    return createAssessmentResult({
      status: 'MISSING',
      reasonCode: 'missing-entry',
      artifactSetHash: null,
      approvedArtifactSetHash: null,
      currentArtifactSetHash: current.artifactSetHash
    });
  }

  const normalizedStatus = normalizeEnumValue(
    entry.status,
    APPROVAL_STATUS_VALUES,
    'approval status'
  );
  if (normalizedStatus == null) {
    throw new Error('Approval entries must record a status.');
  }

  if (normalizedStatus === 'SUPERSEDED') {
    return createAssessmentResult({
      status: 'SUPERSEDED',
      reasonCode: 'superseded',
      artifactSetHash: entry?.artifactSetHash ?? null,
      approvedArtifactSetHash: entry?.artifactSetHash ?? null,
      currentArtifactSetHash: current.artifactSetHash
    });
  }

  if (isAcceptedMutantScope(entry?.scope)) {
    const acceptedMutantLineage = normalizeAcceptedMutantLineage(entry);
    if (
      !acceptedMutantLineage.unitId ||
      !acceptedMutantLineage.mutantId ||
      !acceptedMutantLineage.reason ||
      !acceptedMutantLineage.configPath ||
      !acceptedMutantLineage.approvedAt ||
      !acceptedMutantLineage.expiresAt
    ) {
      return createAssessmentResult({
        status: 'STALE',
        reasonCode: 'missing-lineage',
        artifactSetHash: current.artifactSetHash,
        approvedArtifactSetHash: entry?.artifactSetHash ?? null,
        currentArtifactSetHash: current.artifactSetHash
      });
    }

    const approvedDate = new Date(acceptedMutantLineage.approvedAt);
    const expiryDate = new Date(acceptedMutantLineage.expiresAt);
    if (Number.isNaN(approvedDate.getTime())) {
      return createAssessmentResult({
        status: 'STALE',
        reasonCode: 'missing-lineage',
        artifactSetHash: current.artifactSetHash,
        approvedArtifactSetHash: entry?.artifactSetHash ?? null,
        currentArtifactSetHash: current.artifactSetHash
      });
    }

    if (Number.isNaN(expiryDate.getTime()) || expiryDate.getTime() <= Date.now()) {
      return createAssessmentResult({
        status: 'STALE',
        reasonCode: 'expired',
        artifactSetHash: current.artifactSetHash,
        approvedArtifactSetHash: entry?.artifactSetHash ?? null,
        currentArtifactSetHash: current.artifactSetHash
      });
    }
  }

  if (current.artifactSetHash !== entry?.artifactSetHash) {
    return createAssessmentResult({
      status: 'STALE',
      reasonCode: 'artifact-set-changed',
      artifactSetHash: current.artifactSetHash,
      approvedArtifactSetHash: entry?.artifactSetHash ?? null,
      currentArtifactSetHash: current.artifactSetHash
    });
  }

  return createAssessmentResult({
    status: 'APPROVED',
    artifactSetHash: current.artifactSetHash,
    approvedArtifactSetHash: entry?.artifactSetHash ?? null,
    currentArtifactSetHash: current.artifactSetHash
  });
}

export function serializeApprovalsMarkdown(document) {
  const normalized = cloneDocument(document);
  const summary = (normalized.entries ?? []).length === 0
    ? ['- No approvals recorded yet.']
    : normalized.entries.map((entry) => {
      const unitSuffix = entry.unitId ? ` (${entry.unitId})` : '';
      const mutantSuffix =
        isAcceptedMutantScope(entry.scope) && entry.mutantId ? ` [${entry.mutantId}]` : '';
      const sourceRef = entry.source?.ref ? ` via ${entry.source.ref}` : '';
      return `- ${entry.scope}${unitSuffix}${mutantSuffix}: ${entry.status}${sourceRef}`;
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
    if (parsed == null || typeof parsed !== 'object' || !Array.isArray(parsed.entries)) {
      throw new Error('Malformed approvals ledger JSON.');
    }

    return {
      version: normalizeString(parsed.version) ?? '1.0',
      entries: Array.isArray(parsed.entries) ? parsed.entries : []
    };
  } catch (error) {
    throw new Error(
      `Malformed approvals ledger JSON.${error instanceof Error && error.message ? ` ${error.message}` : ''}`.trim()
    );
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
