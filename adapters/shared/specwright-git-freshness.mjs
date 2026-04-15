import { execFileSync } from 'child_process';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

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

function parseJsonFile(path) {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return null;
  }
}

function normalizeString(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();
  return trimmed ? trimmed : null;
}

function normalizePhase(value) {
  return ['build', 'verify', 'ship'].includes(value) ? value : 'build';
}

function normalizeValidation(value) {
  return value === 'queue' ? 'queue' : 'branch-head';
}

function normalizeReconcile(value) {
  return ['manual', 'rebase', 'merge'].includes(value) ? value : 'manual';
}

function normalizeCheckpoint(value) {
  return ['ignore', 'warn', 'require'].includes(value) ? value : 'ignore';
}

function loadConfig(stateInfo) {
  const candidates = [
    stateInfo?.sharedConfigPath ?? null,
    stateInfo?.projectRoot ? join(stateInfo.projectRoot, '.specwright', 'config.json') : null
  ];

  for (const candidate of candidates) {
    if (!candidate || !existsSync(candidate)) {
      continue;
    }

    const raw = parseJsonFile(candidate);
    return raw ?? {};
  }

  return {};
}

function resolveCurrentBranch(stateInfo, cwd) {
  const detected = tryGit(['branch', '--show-current'], cwd);
  if (detected.ok && detected.value) {
    return detected.value;
  }

  return normalizeString(stateInfo?.session?.branch) ?? normalizeString(stateInfo?.workflow?.branch);
}

function listPatternMatches(cwd, remote, pattern) {
  const refs = tryGit(
    ['for-each-ref', `refs/remotes/${remote}/${pattern}`, '--format=%(refname:strip=3)'],
    cwd
  );

  if (!refs.ok) {
    return {
      ok: false,
      reason: refs.message
    };
  }

  return {
    ok: true,
    matches: refs.value
      ? refs.value.split(/\r?\n/u).map((entry) => entry.trim()).filter(Boolean)
      : []
  };
}

function resolveTargetRef(stateInfo, config, cwd, options = {}) {
  const workflowTarget = stateInfo?.workflow?.targetRef;
  const workflowBranch = normalizeString(workflowTarget?.branch);
  const workflowRemote = normalizeString(workflowTarget?.remote) ?? normalizeString(options.remote) ?? 'origin';

  if (workflowBranch) {
    return {
      ok: true,
      targetRef: {
        remote: workflowRemote,
        branch: workflowBranch,
        role: normalizeString(workflowTarget?.role),
        resolvedBy: normalizeString(workflowTarget?.resolvedBy) ?? 'workflow.targetRef',
        resolvedAt: normalizeString(workflowTarget?.resolvedAt)
      }
    };
  }

  const gitConfig = config?.git ?? {};
  const targets = gitConfig.targets ?? {};
  const role = normalizeString(options.role) ?? normalizeString(targets.defaultRole) ?? 'integration';
  const remote = normalizeString(options.remote) ?? 'origin';
  const roleConfig = targets.roles?.[role];
  const branch = normalizeString(roleConfig?.branch);
  if (branch) {
    return {
      ok: true,
      targetRef: {
        remote,
        branch,
        role,
        resolvedBy: `config.git.targets.roles.${role}.branch`,
        resolvedAt: null
      }
    };
  }

  const pattern = normalizeString(roleConfig?.pattern);
  if (pattern) {
    const matches = listPatternMatches(cwd, remote, pattern);
    if (!matches.ok) {
      return {
        ok: false,
        reason: `Unable to resolve target pattern ${pattern} on ${remote}: ${matches.reason}`
      };
    }

    if (matches.matches.length === 1) {
      return {
        ok: true,
        targetRef: {
          remote,
          branch: matches.matches[0],
          role,
          resolvedBy: `config.git.targets.roles.${role}.pattern`,
          resolvedAt: null
        }
      };
    }

    if (matches.matches.length === 0) {
      return {
        ok: false,
        reason: `No remote branches matched ${remote}/${pattern}.`
      };
    }

    return {
      ok: false,
      reason: `Multiple remote branches matched ${remote}/${pattern}; resolve a concrete targetRef before assessing freshness.`
    };
  }

  const baseBranch = normalizeString(gitConfig.baseBranch);
  if (baseBranch) {
    return {
      ok: true,
      targetRef: {
        remote,
        branch: baseBranch,
        role,
        resolvedBy: 'config.git.baseBranch',
        resolvedAt: null
      }
    };
  }

  return {
    ok: false,
    reason: 'No recorded targetRef or compatible git target defaults were available.'
  };
}

function resolveFreshnessSettings(stateInfo, config, phase) {
  const workflowFreshness = stateInfo?.workflow?.freshness ?? {};
  const configFreshness = config?.git?.freshness ?? {};

  return {
    validation: normalizeValidation(
      normalizeString(workflowFreshness.validation) ?? normalizeString(configFreshness.validation)
    ),
    reconcile: normalizeReconcile(
      normalizeString(workflowFreshness.reconcile) ?? normalizeString(configFreshness.reconcile)
    ),
    checkpoint: normalizeCheckpoint(
      normalizeString(workflowFreshness.checkpoints?.[phase]) ??
      normalizeString(configFreshness.checkpoints?.[phase])
    )
  };
}

function recommendedAction(status, checkpoint) {
  if (status === 'fresh') {
    return 'continue';
  }

  if (status === 'queue-managed') {
    return 'delegate-to-queue';
  }

  if (checkpoint === 'ignore') {
    return 'continue';
  }

  if (checkpoint === 'warn') {
    return 'warn';
  }

  return 'stop';
}

function guidanceFor(status, details) {
  const targetLabel = details?.targetRef
    ? `${details.targetRef.remote}/${details.targetRef.branch}`
    : 'the configured target branch';
  const branchLabel = details?.currentBranch ?? 'the current branch';

  switch (status) {
    case 'fresh':
      return `${branchLabel} already contains ${targetLabel}.`;
    case 'stale':
      return `${branchLabel} is behind ${targetLabel} by ${details.behind} commit(s).`;
    case 'diverged':
      return `${branchLabel} and ${targetLabel} both have unique commits (ahead ${details.ahead}, behind ${details.behind}).`;
    case 'queue-managed':
      return `${targetLabel} freshness is managed by queue validation; local branch-head drift is advisory only.`;
    case 'blocked':
    default:
      return details?.reason ?? 'Freshness could not be assessed from the available Git state.';
  }
}

function buildResult(context, overrides = {}) {
  const status = overrides.status ?? 'blocked';
  const checkpoint = overrides.checkpoint ?? context.checkpoint ?? 'ignore';
  const ahead = overrides.ahead ?? 0;
  const behind = overrides.behind ?? 0;

  return {
    phase: context.phase ?? 'build',
    targetRef: overrides.targetRef ?? context.targetRef ?? null,
    validation: overrides.validation ?? context.validation ?? 'branch-head',
    reconcile: overrides.reconcile ?? context.reconcile ?? 'manual',
    checkpoint,
    currentBranch: overrides.currentBranch ?? context.currentBranch ?? null,
    status,
    ahead,
    behind,
    targetHead: overrides.targetHead ?? null,
    currentHead: overrides.currentHead ?? null,
    recommendedAction: overrides.recommendedAction ?? recommendedAction(status, checkpoint),
    guidance: overrides.guidance ?? guidanceFor(status, {
      targetRef: overrides.targetRef ?? context.targetRef ?? null,
      currentBranch: overrides.currentBranch ?? context.currentBranch ?? null,
      ahead,
      behind,
      reason: overrides.reason ?? context.reason ?? null
    }),
    ...('fetched' in overrides ? { fetched: overrides.fetched } : {})
  };
}

export function resolveGitFreshnessContext(stateInfo, options = {}) {
  const info = stateInfo ?? loadSpecwrightState({ cwd: options.cwd });
  const phase = normalizePhase(options.phase);

  if (!info || info.ok === false) {
    return {
      ok: false,
      phase,
      validation: 'branch-head',
      reconcile: 'manual',
      checkpoint: 'ignore',
      targetRef: null,
      currentBranch: null,
      reason: 'Specwright state roots could not be resolved for freshness assessment.'
    };
  }

  const config = loadConfig(info);
  const settings = resolveFreshnessSettings(info, config, phase);
  const projectRoot = info.projectRoot ?? options.cwd ?? process.cwd();

  if (!info.workflow) {
    return {
      ok: false,
      phase,
      projectRoot,
      ...settings,
      targetRef: null,
      currentBranch: null,
      reason: 'No selected work is attached for freshness assessment.'
    };
  }

  const targetResolution = resolveTargetRef(info, config, projectRoot, options);
  if (!targetResolution.ok) {
    return {
      ok: false,
      phase,
      projectRoot,
      ...settings,
      targetRef: null,
      currentBranch: null,
      reason: targetResolution.reason
    };
  }

  const currentBranch = resolveCurrentBranch(info, projectRoot);
  if (!currentBranch) {
    return {
      ok: false,
      phase,
      projectRoot,
      ...settings,
      targetRef: targetResolution.targetRef,
      currentBranch: null,
      reason: 'The current branch could not be resolved.'
    };
  }

  return {
    ok: true,
    stateInfo: info,
    config,
    projectRoot,
    phase,
    ...settings,
    targetRef: targetResolution.targetRef,
    currentBranch,
    fetch: options.fetch === true
  };
}

export function assessGitFreshness(stateInfo, options = {}) {
  const context = resolveGitFreshnessContext(stateInfo, options);
  if (!context.ok) {
    return buildResult(context, { status: 'blocked' });
  }

  const currentHeadResult = tryGit(['rev-parse', 'HEAD'], context.projectRoot);
  const currentHead = currentHeadResult.ok ? currentHeadResult.value : null;

  if (context.validation === 'queue') {
    return buildResult(context, {
      status: 'queue-managed',
      currentHead,
      fetched: false
    });
  }

  if (!currentHeadResult.ok) {
    return buildResult(context, {
      status: 'blocked',
      currentHead: null,
      fetched: false,
      reason: `Unable to resolve HEAD: ${currentHeadResult.message}`
    });
  }

  if (context.fetch) {
    const fetchResult = tryGit(
      ['fetch', '--prune', context.targetRef.remote, context.targetRef.branch],
      context.projectRoot
    );
    if (!fetchResult.ok) {
      return buildResult(context, {
        status: 'blocked',
        currentHead,
        fetched: false,
        reason: `Unable to fetch ${context.targetRef.remote}/${context.targetRef.branch}: ${fetchResult.message}`
      });
    }
  }

  const targetRefName = `refs/remotes/${context.targetRef.remote}/${context.targetRef.branch}`;
  const targetHeadResult = tryGit(['rev-parse', targetRefName], context.projectRoot);
  if (!targetHeadResult.ok) {
    return buildResult(context, {
      status: 'blocked',
      currentHead,
      fetched: context.fetch,
      reason: `Unable to resolve ${context.targetRef.remote}/${context.targetRef.branch}: ${targetHeadResult.message}`
    });
  }

  const countResult = tryGit(['rev-list', '--left-right', '--count', `HEAD...${targetRefName}`], context.projectRoot);
  if (!countResult.ok) {
    return buildResult(context, {
      status: 'blocked',
      currentHead,
      targetHead: targetHeadResult.value,
      fetched: context.fetch,
      reason: `Unable to compare HEAD with ${context.targetRef.remote}/${context.targetRef.branch}: ${countResult.message}`
    });
  }

  const [aheadRaw, behindRaw] = countResult.value.split(/\s+/u);
  const ahead = Number.parseInt(aheadRaw, 10);
  const behind = Number.parseInt(behindRaw, 10);
  if (!Number.isFinite(ahead) || !Number.isFinite(behind)) {
    return buildResult(context, {
      status: 'blocked',
      currentHead,
      targetHead: targetHeadResult.value,
      fetched: context.fetch,
      reason: `Unexpected ancestry counts from git rev-list: ${countResult.value}`
    });
  }

  const status = behind === 0 ? 'fresh' : (ahead === 0 ? 'stale' : 'diverged');

  return buildResult(context, {
    status,
    ahead,
    behind,
    currentHead,
    targetHead: targetHeadResult.value,
    fetched: context.fetch
  });
}

export function assessGitFreshnessFromCwd(options = {}) {
  return assessGitFreshness(loadSpecwrightState({ cwd: options.cwd }), options);
}
