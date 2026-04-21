import { execFileSync } from 'child_process';
import { resolve } from 'path';

import { assessGitFreshness, resolveGitFreshnessContext } from './specwright-git-freshness.mjs';
import { loadSpecwrightState } from './specwright-state-paths.mjs';

const FALLBACK_REPO_LOCAL_GIT_ENV_VARS = new Set([
  'GIT_ALTERNATE_OBJECT_DIRECTORIES',
  'GIT_COMMON_DIR',
  'GIT_CONFIG',
  'GIT_CONFIG_COUNT',
  'GIT_CONFIG_PARAMETERS',
  'GIT_DIR',
  'GIT_GRAFT_FILE',
  'GIT_IMPLICIT_WORK_TREE',
  'GIT_INDEX_FILE',
  'GIT_NAMESPACE',
  'GIT_NO_REPLACE_OBJECTS',
  'GIT_OBJECT_DIRECTORY',
  'GIT_PREFIX',
  'GIT_REPLACE_REF_BASE',
  'GIT_SHALLOW_FILE',
  'GIT_WORK_TREE'
]);

function sanitizedGitEnv(extra = {}, keys = REPO_LOCAL_GIT_ENV_VARS) {
  const env = { ...process.env };
  for (const key of keys) {
    delete env[key];
  }

  return {
    ...env,
    ...extra
  };
}

function loadRepoLocalGitEnvVars() {
  const keys = new Set(FALLBACK_REPO_LOCAL_GIT_ENV_VARS);

  try {
    const output = execFileSync('git', ['rev-parse', '--local-env-vars'], {
      env: sanitizedGitEnv({}, FALLBACK_REPO_LOCAL_GIT_ENV_VARS),
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    });

    for (const key of output.split(/\r?\n/u)) {
      if (key) {
        keys.add(key);
      }
    }
  } catch {
    // Fall back to the static list when Git cannot provide the dynamic one.
  }

  return keys;
}

const REPO_LOCAL_GIT_ENV_VARS = loadRepoLocalGitEnvVars();

function runGit(args, cwd) {
  return execFileSync('git', args, {
    cwd,
    env: sanitizedGitEnv(),
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'pipe']
  }).trim();
}

function tryGit(args, cwd) {
  try {
    return {
      ok: true,
      value: runGit(args, cwd)
    };
  } catch (error) {
    const stderr = error?.stderr?.toString?.().trim();
    const stdout = error?.stdout?.toString?.().trim();
    return {
      ok: false,
      command: ['git', ...args],
      message: stderr || stdout || (error instanceof Error ? error.message : String(error))
    };
  }
}

function normalizePhase(value) {
  return ['build', 'verify', 'ship'].includes(value) ? value : 'build';
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function guidanceFor(status, details) {
  const targetLabel = details?.targetRef
    ? `${details.targetRef.remote}/${details.targetRef.branch}`
    : 'the recorded target branch';
  const branchLabel = details?.currentBranch ?? 'the current branch';

  if (status === 'queue-managed') {
    return `${targetLabel} freshness is queue-managed; do not rewrite ${branchLabel} locally.`;
  }

  if (status === 'noop') {
    return `${branchLabel} already contains ${targetLabel}; no reconcile is needed.`;
  }

  if (status === 'reconciled') {
    return `Successfully ${details.action === 'merge' ? 'merged' : 'rebased'} ${branchLabel} against ${targetLabel}.`;
  }

  switch (details?.reasonCode) {
    case 'manual-policy':
      return `Lifecycle-owned reconcile is disabled; reconcile ${branchLabel} against ${targetLabel} manually in the owning worktree.`;
    case 'dirty-worktree':
      return `${branchLabel} has uncommitted changes; clean the worktree before attempting reconcile.`;
    case 'ownership-mismatch':
      return `The selected work is not owned by this worktree; adopt or switch to the owning worktree before reconciling ${branchLabel}.`;
    case 'branch-mismatch':
      return `${branchLabel} does not match the selected work's recorded branch; stop and resolve the branch mismatch first.`;
    case 'conflict':
      return `${details.action === 'merge' ? 'Merge' : 'Rebase'} hit conflicts and was aborted; resolve the conflict manually in the owning worktree.`;
    case 'assessment-blocked':
      return 'Freshness could not be assessed before reconcile; stop and fix the underlying Git or state issue.';
    case 'subordinate-session':
      return 'Only the top-level owning worktree may perform lifecycle-owned reconcile.';
    default:
      return 'Freshness reconcile could not continue safely from the available state.';
  }
}

function buildResult(context, overrides = {}) {
  const status = overrides.status ?? 'blocked';
  const action = overrides.action ?? null;
  const performed = overrides.performed === true;
  const reasonCode = overrides.reasonCode ?? null;

  return {
    phase: overrides.phase ?? context.phase ?? 'build',
    targetRef: overrides.targetRef ?? context.targetRef ?? null,
    validation: overrides.validation ?? context.validation ?? 'branch-head',
    reconcile: overrides.reconcile ?? context.reconcile ?? 'manual',
    status,
    action,
    performed,
    currentBranch: overrides.currentBranch ?? context.currentBranch ?? null,
    currentHeadBefore: overrides.currentHeadBefore ?? null,
    currentHeadAfter: overrides.currentHeadAfter ?? null,
    targetHead: overrides.targetHead ?? null,
    freshnessBefore: overrides.freshnessBefore ?? null,
    freshnessAfter: overrides.freshnessAfter ?? null,
    recommendedAction: overrides.recommendedAction ??
      (status === 'queue-managed' ? 'delegate-to-queue' : (status === 'blocked' ? 'stop' : 'continue')),
    reasonCode,
    guidance: overrides.guidance ?? guidanceFor(status, {
      action,
      currentBranch: overrides.currentBranch ?? context.currentBranch ?? null,
      reasonCode,
      targetRef: overrides.targetRef ?? context.targetRef ?? null
    }),
    ...('fetched' in overrides ? { fetched: overrides.fetched } : {})
  };
}

function resolveOwnershipResult(stateInfo, context) {
  const session = stateInfo?.session ?? null;
  const workflow = stateInfo?.workflow ?? null;
  const attachment = workflow?.attachment ?? null;
  const sessionWorktreeId = normalizeString(session?.worktreeId);
  const workflowWorkId = normalizeString(workflow?.id);
  const sessionWorkId = normalizeString(session?.attachedWorkId);
  const sessionMode = normalizeString(session?.mode);
  const recordedBranch = normalizeString(workflow?.branch);
  const currentBranch = normalizeString(context.currentBranch);

  if (sessionMode && sessionMode !== 'top-level') {
    return { ok: false, reasonCode: 'subordinate-session' };
  }

  if (workflowWorkId && sessionWorkId && workflowWorkId !== sessionWorkId) {
    return { ok: false, reasonCode: 'ownership-mismatch' };
  }

  if (recordedBranch && currentBranch && recordedBranch !== currentBranch) {
    return { ok: false, reasonCode: 'branch-mismatch' };
  }

  if (attachment) {
    const attachmentWorktreeId = normalizeString(attachment.worktreeId);
    const attachmentWorktreePath = normalizeString(attachment.worktreePath);
    const sessionWorktreePath = normalizeString(session?.worktreePath);
    const attachmentMode = normalizeString(attachment.mode);

    if (attachmentWorktreeId && sessionWorktreeId && attachmentWorktreeId !== sessionWorktreeId) {
      return { ok: false, reasonCode: 'ownership-mismatch' };
    }

    if (
      attachmentWorktreePath &&
      sessionWorktreePath &&
      resolve(attachmentWorktreePath) !== resolve(sessionWorktreePath)
    ) {
      return { ok: false, reasonCode: 'ownership-mismatch' };
    }

    if (attachmentMode && sessionMode && attachmentMode !== sessionMode) {
      return { ok: false, reasonCode: 'ownership-mismatch' };
    }
  }

  return { ok: true };
}

function worktreeIsDirty(cwd) {
  const status = tryGit(['status', '--porcelain'], cwd);
  if (!status.ok) {
    return {
      ok: false,
      dirty: false,
      reasonCode: 'assessment-blocked',
      reason: status.message
    };
  }

  return {
    ok: true,
    dirty: status.value.length > 0
  };
}

function targetRefName(targetRef) {
  return `refs/remotes/${targetRef.remote}/${targetRef.branch}`;
}

function classifyMutationFailure(action, message) {
  if (/CONFLICT|could not apply|Automatic merge failed|Resolve all conflicts manually/i.test(message ?? '')) {
    return 'conflict';
  }

  return action === 'merge' ? 'merge-failed' : 'rebase-failed';
}

function abortMutation(action, cwd) {
  if (action === 'merge') {
    tryGit(['merge', '--abort'], cwd);
    return;
  }

  tryGit(['rebase', '--abort'], cwd);
}

function runMutation(action, cwd, targetRef) {
  const target = targetRefName(targetRef);

  if (action === 'merge') {
    return tryGit(['merge', '--no-edit', target], cwd);
  }

  return tryGit(['rebase', target], cwd);
}

function mutationActionFor(reconcile) {
  return reconcile === 'merge' ? 'merge' : (reconcile === 'rebase' ? 'rebase' : null);
}

export function reconcileGitFreshness(stateInfo, options = {}) {
  const context = resolveGitFreshnessContext(stateInfo, options);
  if (!context.ok) {
    return buildResult({
      phase: normalizePhase(options.phase),
      targetRef: context.targetRef ?? null,
      validation: context.validation ?? 'branch-head',
      reconcile: context.reconcile ?? 'manual',
      currentBranch: context.currentBranch ?? null
    }, {
      status: 'blocked',
      performed: false,
      reasonCode: 'assessment-blocked',
      guidance: context.reason ?? 'Freshness context could not be resolved.',
      fetched: false
    });
  }

  const ownership = resolveOwnershipResult(context.stateInfo, context);
  if (!ownership.ok) {
    return buildResult(context, {
      status: 'blocked',
      performed: false,
      reasonCode: ownership.reasonCode,
      fetched: false
    });
  }

  const freshness = assessGitFreshness(context.stateInfo, {
    phase: context.phase,
    fetch: options.fetch !== false
  });

  if (freshness.status === 'queue-managed') {
    return buildResult(context, {
      status: 'queue-managed',
      action: null,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: freshness.status,
      recommendedAction: 'delegate-to-queue',
      fetched: freshness.fetched ?? false
    });
  }

  if (freshness.status === 'fresh') {
    return buildResult(context, {
      status: 'noop',
      action: null,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: freshness.status,
      fetched: freshness.fetched ?? false
    });
  }

  if (freshness.status === 'blocked') {
    return buildResult(context, {
      status: 'blocked',
      action: null,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: null,
      reasonCode: 'assessment-blocked',
      guidance: freshness.guidance,
      fetched: freshness.fetched ?? false
    });
  }

  const action = mutationActionFor(context.reconcile);
  if (!action) {
    return buildResult(context, {
      status: 'blocked',
      action: null,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: null,
      reasonCode: 'manual-policy',
      fetched: freshness.fetched ?? false
    });
  }

  const dirty = worktreeIsDirty(context.projectRoot);
  if (!dirty.ok) {
    return buildResult(context, {
      status: 'blocked',
      action,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: null,
      reasonCode: dirty.reasonCode,
      guidance: dirty.reason,
      fetched: freshness.fetched ?? false
    });
  }

  if (dirty.dirty) {
    return buildResult(context, {
      status: 'blocked',
      action,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: null,
      reasonCode: 'dirty-worktree',
      fetched: freshness.fetched ?? false
    });
  }

  const mutation = runMutation(action, context.projectRoot, context.targetRef);
  if (!mutation.ok) {
    abortMutation(action, context.projectRoot);
    return buildResult(context, {
      status: 'blocked',
      action,
      performed: false,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: freshness.currentHead ?? null,
      targetHead: freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: null,
      reasonCode: classifyMutationFailure(action, mutation.message),
      guidance: mutation.message,
      fetched: freshness.fetched ?? false
    });
  }

  const post = assessGitFreshness(context.stateInfo, {
    phase: context.phase,
    fetch: false
  });

  if (post.status !== 'fresh') {
    return buildResult(context, {
      status: 'blocked',
      action,
      performed: true,
      currentHeadBefore: freshness.currentHead ?? null,
      currentHeadAfter: post.currentHead ?? null,
      targetHead: post.targetHead ?? freshness.targetHead ?? null,
      freshnessBefore: freshness.status,
      freshnessAfter: post.status,
      reasonCode: 'assessment-blocked',
      guidance: `Post-${action} freshness did not resolve cleanly: ${post.guidance}`,
      fetched: freshness.fetched ?? false
    });
  }

  return buildResult(context, {
    status: 'reconciled',
    action,
    performed: true,
    currentHeadBefore: freshness.currentHead ?? null,
    currentHeadAfter: post.currentHead ?? null,
    targetHead: post.targetHead ?? freshness.targetHead ?? null,
    freshnessBefore: freshness.status,
    freshnessAfter: post.status,
    fetched: freshness.fetched ?? false
  });
}

export function reconcileGitFreshnessFromCwd(options = {}) {
  return reconcileGitFreshness(loadSpecwrightState({ cwd: options.cwd }), options);
}
