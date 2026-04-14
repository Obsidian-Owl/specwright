import { execFileSync } from 'child_process';
import { createHash } from 'crypto';
import { existsSync, readFileSync, readdirSync } from 'fs';
import { basename, dirname, isAbsolute, join, relative, resolve } from 'path';

const FAILURE_CODE = 'GIT_RESOLUTION_FAILED';
const PRIMARY_WORKTREE_ID = 'main-worktree';
const LEGACY_STATE_SEGMENTS = ['.specwright', 'state'];
const SHARED_CONFIG_FILE = 'config.json';
const FALLBACK_REPO_LOCAL_GIT_ENV_VARS = new Set([
  // Tracks `git rev-parse --local-env-vars` plus config-injection vars that
  // Git does not report but are still unsafe to inherit across repositories.
  // Re-check this fallback when the minimum supported Git version changes.
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
    // Keep the static fallback when Git cannot provide a dynamic env list.
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

function buildFailure(root, cwd, args, error) {
  return {
    ok: false,
    code: FAILURE_CODE,
    root,
    cwd,
    command: ['git', ...args],
    message: error instanceof Error ? error.message : String(error)
  };
}

function resolveGitRoot(cwd, root, args) {
  try {
    const value = runGit(args, cwd);
    if (!value) {
      return buildFailure(root, cwd, args, new Error(`git ${args.join(' ')} returned an empty value`));
    }

    return { ok: true, value };
  } catch (error) {
    return buildFailure(root, cwd, args, error);
  }
}

function deriveWorktreeId(gitDir, gitCommonDir) {
  if (gitDir === gitCommonDir) {
    return PRIMARY_WORKTREE_ID;
  }

  if (dirname(gitDir) === join(gitCommonDir, 'worktrees')) {
    return basename(gitDir);
  }

  const tail = basename(gitDir);
  if (tail && tail !== '.git') {
    return tail;
  }

  return `worktree-${createHash('sha256').update(gitDir).digest('hex').slice(0, 12)}`;
}

export function resolveSpecwrightRoots(options = {}) {
  const cwd = resolve(options.cwd ?? process.cwd());

  const projectRootResult = resolveGitRoot(cwd, 'projectRoot', ['rev-parse', '--show-toplevel']);
  if (!projectRootResult.ok) {
    return projectRootResult;
  }

  const projectRoot = resolve(projectRootResult.value);

  const gitDirResult = resolveGitRoot(projectRoot, 'gitDir', ['rev-parse', '--git-dir']);
  if (!gitDirResult.ok) {
    return gitDirResult;
  }

  const gitCommonDirResult = resolveGitRoot(projectRoot, 'gitCommonDir', ['rev-parse', '--git-common-dir']);
  if (!gitCommonDirResult.ok) {
    return gitCommonDirResult;
  }

  const gitDir = resolve(projectRoot, gitDirResult.value);
  const gitCommonDir = resolve(projectRoot, gitCommonDirResult.value);

  return {
    ok: true,
    projectRoot,
    gitDir,
    gitCommonDir,
    repoStateRoot: join(gitCommonDir, 'specwright'),
    worktreeStateRoot: join(gitDir, 'specwright'),
    worktreeId: deriveWorktreeId(gitDir, gitCommonDir)
  };
}

export function resolveLegacyStatePaths(options = {}) {
  const cwd = resolve(options.cwd ?? process.cwd());
  const roots = resolveSpecwrightRoots({ cwd });
  const lookupRoot = roots.ok ? roots.projectRoot : cwd;
  const legacyStateRoot = join(lookupRoot, ...LEGACY_STATE_SEGMENTS);

  return {
    ...roots,
    lookupRoot,
    legacyStateRoot,
    workflowPath: join(legacyStateRoot, 'workflow.json'),
    continuationPath: join(legacyStateRoot, 'continuation.md'),
    usedFallback: !roots.ok
  };
}

function parseJsonFile(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

function normalizeAttachedWorkId(value) {
  if (typeof value !== 'string') {
    return null;
  }

  const workId = value.trim();
  if (!workId || workId === '.' || workId === '..') {
    return null;
  }

  if (workId.includes('/') || workId.includes('\\')) {
    return null;
  }

  return workId;
}

function resolveSharedWorkflowPath(repoStateRoot, attachedWorkId) {
  const workId = normalizeAttachedWorkId(attachedWorkId);
  if (!workId) {
    return {
      attachedWorkId: null,
      workflowPath: null
    };
  }

  const workRoot = resolve(repoStateRoot, 'work');
  const workflowPath = resolve(workRoot, workId, 'workflow.json');
  const relativePath = relative(workRoot, workflowPath);

  if (!relativePath || relativePath.startsWith('..') || isAbsolute(relativePath)) {
    return {
      attachedWorkId: null,
      workflowPath: null
    };
  }

  return {
    attachedWorkId: workId,
    workflowPath
  };
}

function gateVerdict(gate) {
  if (!gate || typeof gate !== 'object') {
    return 'UNKNOWN';
  }

  return gate.status ?? gate.verdict ?? 'UNKNOWN';
}

function summarizeGates(gates) {
  const entries = Object.entries(gates ?? {});
  if (entries.length === 0) {
    return 'none run';
  }

  return entries
    .map(([name, gate]) => `${name}: ${gateVerdict(gate)}`)
    .join(', ');
}

function buildWorkArtifacts(baseDir, workId, workDir) {
  const relativeWorkDir = workDir || `work/${workId}`;
  const workDirPath = resolve(baseDir, relativeWorkDir);

  return {
    workDir: relativeWorkDir,
    workDirPath,
    specPath: resolve(workDirPath, 'spec.md'),
    planPath: resolve(workDirPath, 'plan.md')
  };
}

function isActiveWorkflowStatus(status) {
  return Boolean(status) && !['shipped', 'abandoned'].includes(status);
}

function parseWorktreeList(text) {
  const entries = [];
  let current = null;

  for (const line of text.split('\n')) {
    if (!line) {
      continue;
    }

    if (line.startsWith('worktree ')) {
      if (current) {
        entries.push(current);
      }

      current = {
        path: resolve(line.slice('worktree '.length).trim()),
        prunable: false
      };
      continue;
    }

    if (!current) {
      continue;
    }

    if (line === 'prunable' || line.startsWith('prunable ')) {
      current.prunable = true;
      continue;
    }

    if (line.startsWith('branch ')) {
      current.branch = line.slice('branch '.length).trim();
      continue;
    }

    if (line.startsWith('HEAD ')) {
      current.head = line.slice('HEAD '.length).trim();
    }
  }

  if (current) {
    entries.push(current);
  }

  return entries;
}

function listSessionFiles(roots) {
  const sessionFiles = [];
  const primarySessionPath = join(roots.gitCommonDir, 'specwright', 'session.json');
  if (existsSync(primarySessionPath)) {
    sessionFiles.push({
      worktreeId: PRIMARY_WORKTREE_ID,
      sessionPath: primarySessionPath
    });
  }

  const linkedWorktreesDir = join(roots.gitCommonDir, 'worktrees');
  if (!existsSync(linkedWorktreesDir)) {
    return sessionFiles;
  }

  for (const entry of readdirSync(linkedWorktreesDir, { withFileTypes: true })) {
    if (!entry.isDirectory()) {
      continue;
    }

    const sessionPath = join(linkedWorktreesDir, entry.name, 'specwright', 'session.json');
    if (!existsSync(sessionPath)) {
      continue;
    }

    sessionFiles.push({
      worktreeId: entry.name,
      sessionPath
    });
  }

  return sessionFiles;
}

export function loadSpecwrightState(options = {}) {
  const legacy = resolveLegacyStatePaths(options);
  const sharedConfigPath = legacy.ok ? join(legacy.repoStateRoot, SHARED_CONFIG_FILE) : null;
  const usingSharedLayout = Boolean(sharedConfigPath && existsSync(sharedConfigPath));

  if (usingSharedLayout) {
    const sessionPath = join(legacy.worktreeStateRoot, 'session.json');
    const continuationPath = join(legacy.worktreeStateRoot, 'continuation.md');
    const session = existsSync(sessionPath) ? parseJsonFile(sessionPath) : null;
    const attachedWork = resolveSharedWorkflowPath(legacy.repoStateRoot, session?.attachedWorkId);
    const attachedWorkId = attachedWork.attachedWorkId;
    const workflowPath = attachedWork.workflowPath;
    const workflow = workflowPath && existsSync(workflowPath)
      ? parseJsonFile(workflowPath)
      : null;

    return {
      ...legacy,
      layout: 'shared',
      sharedConfigPath,
      sessionPath,
      session,
      attachedWorkId,
      workflowPath,
      workflow,
      continuationPath
    };
  }

  const workflowPath = legacy.workflowPath;
  const workflow = existsSync(workflowPath) ? parseJsonFile(workflowPath) : null;

  return {
    ...legacy,
    layout: 'legacy',
    sharedConfigPath: null,
    sessionPath: null,
    session: null,
    attachedWorkId: workflow?.currentWork?.id ?? null,
    workflowPath,
    workflow,
    continuationPath: legacy.continuationPath
  };
}

export function normalizeActiveWork(stateInfo) {
  const workflow = stateInfo?.workflow;
  if (!workflow || typeof workflow !== 'object') {
    return null;
  }

  if (stateInfo?.layout === 'legacy' && workflow.currentWork && typeof workflow.currentWork === 'object') {
    const legacyWork = workflow.currentWork;
    const artifacts = buildWorkArtifacts(
      stateInfo.lookupRoot,
      legacyWork.id,
      legacyWork.workDir
    );

    return {
      layout: 'legacy',
      workId: legacyWork.id,
      status: legacyWork.status ?? null,
      unitId: legacyWork.unitId ?? null,
      tasksCompleted: Array.isArray(legacyWork.tasksCompleted) ? legacyWork.tasksCompleted : [],
      tasksTotal: legacyWork.tasksTotal ?? null,
      completedCount: Array.isArray(legacyWork.tasksCompleted) ? legacyWork.tasksCompleted.length : 0,
      totalCount: legacyWork.tasksTotal ?? '?',
      workDir: artifacts.workDir,
      workDirPath: artifacts.workDirPath,
      specPath: artifacts.specPath,
      planPath: artifacts.planPath,
      artifactsRoot: stateInfo.lookupRoot,
      gates: workflow.gates ?? {},
      gatesSummary: summarizeGates(workflow.gates),
      lock: workflow.lock ?? null,
      branch: legacyWork.branch ?? null
    };
  }

  if (!workflow.id) {
    return null;
  }

  const artifacts = buildWorkArtifacts(
    stateInfo.repoStateRoot,
    workflow.id,
    workflow.workDir
  );
  const tasksCompleted = Array.isArray(workflow.tasksCompleted) ? workflow.tasksCompleted : [];

  return {
    layout: 'shared',
    workId: workflow.id,
    status: workflow.status ?? null,
    unitId: workflow.unitId ?? null,
    tasksCompleted,
    tasksTotal: workflow.tasksTotal ?? null,
    completedCount: tasksCompleted.length,
    totalCount: workflow.tasksTotal ?? '?',
    workDir: artifacts.workDir,
    workDirPath: artifacts.workDirPath,
    specPath: artifacts.specPath,
    planPath: artifacts.planPath,
    artifactsRoot: stateInfo.repoStateRoot,
    gates: workflow.gates ?? {},
    gatesSummary: summarizeGates(workflow.gates),
    lock: workflow.lock ?? null,
    branch: stateInfo.session?.branch ?? workflow.branch ?? null,
    attachment: workflow.attachment ?? null
  };
}

export function inspectWorktreeSessions(options = {}) {
  const roots = resolveSpecwrightRoots(options);
  if (!roots.ok) {
    return roots;
  }

  const listedWorktrees = parseWorktreeList(
    runGit(['worktree', 'list', '--porcelain'], roots.projectRoot)
  );
  const liveWorktreePaths = new Set(
    listedWorktrees
      .filter((entry) => !entry.prunable && existsSync(entry.path))
      .map((entry) => entry.path)
  );

  const sessions = listSessionFiles(roots).map(({ worktreeId, sessionPath }) => {
    let session;
    try {
      session = parseJsonFile(sessionPath);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      return {
        worktreeId,
        sessionPath,
        worktreePath: null,
        attachedWorkId: null,
        branch: null,
        mode: null,
        live: false,
        deadReason: `malformed-session-json: ${message}`
      };
    }

    const worktreePath = session?.worktreePath ? resolve(session.worktreePath) : null;
    const live = Boolean(worktreePath && liveWorktreePaths.has(worktreePath));
    const deadReason = live
      ? null
      : (!worktreePath
          ? 'missing-worktree-path'
          : (!existsSync(worktreePath) ? 'missing-worktree-directory' : 'not-listed-by-git'));

    return {
      worktreeId,
      sessionPath,
      worktreePath,
      attachedWorkId: session?.attachedWorkId ?? null,
      branch: session?.branch ?? null,
      mode: session?.mode ?? null,
      live,
      deadReason
    };
  });

  return {
    ok: true,
    projectRoot: roots.projectRoot,
    gitCommonDir: roots.gitCommonDir,
    listedWorktrees,
    sessions,
    deadSessions: sessions.filter((session) => !session.live)
  };
}

function isTopLevelSession(session) {
  return Boolean(session) && session.mode !== 'subordinate';
}

export function findSelectedWorkOwnerConflict(stateInfo, options = {}) {
  const currentSession = stateInfo?.session;
  const attachedWorkId = stateInfo?.attachedWorkId;

  if (stateInfo?.layout !== 'shared' || !currentSession || !attachedWorkId || !isTopLevelSession(currentSession)) {
    return null;
  }

  const sessionsInfo = inspectWorktreeSessions({
    cwd: options.cwd ?? stateInfo.projectRoot ?? process.cwd()
  });

  if (!sessionsInfo?.ok) {
    return null;
  }

  const owner = sessionsInfo.sessions.find((session) =>
    session.live &&
    isTopLevelSession(session) &&
    session.attachedWorkId === attachedWorkId &&
    session.worktreeId !== stateInfo.worktreeId
  );

  if (!owner) {
    return null;
  }

  return {
    workId: attachedWorkId,
    currentWorktreeId: stateInfo.worktreeId ?? null,
    currentWorktreePath: stateInfo.projectRoot ?? null,
    ownerWorktreeId: owner.worktreeId,
    ownerWorktreePath: owner.worktreePath,
    ownerBranch: owner.branch ?? null,
    ownerSessionPath: owner.sessionPath
  };
}

function summarizeActiveWork(work) {
  if (!work) {
    return null;
  }

  return {
    workId: work.workId,
    status: work.status ?? null,
    unitId: work.unitId ?? null,
    branch: work.branch ?? null
  };
}

function summarizeSession(stateInfo) {
  return {
    worktreeId: stateInfo?.worktreeId ?? null,
    branch: stateInfo?.session?.branch ?? null,
    mode: stateInfo?.session?.mode ?? null,
    attachedWorkId: stateInfo?.attachedWorkId ?? null
  };
}

function resolveWorkflowOwner(workflow, sessionsInfo) {
  const liveOwner = sessionsInfo?.sessions?.find((session) =>
    session.live &&
    isTopLevelSession(session) &&
    session.attachedWorkId === workflow.id
  );

  return {
    ownerWorktreeId: liveOwner?.worktreeId ?? workflow.attachment?.worktreeId ?? null,
    ownerLive: Boolean(liveOwner),
    ownerBranch: liveOwner?.branch ?? workflow.branch ?? null,
    ownerWorktreePath: liveOwner?.worktreePath ?? workflow.attachment?.worktreePath ?? null
  };
}

export function buildStatusView(stateInfo, options = {}) {
  const work = normalizeActiveWork(stateInfo);
  const view = {
    roots: {
      repoStateRoot: stateInfo?.repoStateRoot ?? null,
      worktreeStateRoot: stateInfo?.worktreeStateRoot ?? null
    },
    session: summarizeSession(stateInfo),
    attachedWork: summarizeActiveWork(work),
    otherActiveWorks: [],
    staleAttachments: []
  };

  if (stateInfo?.layout !== 'shared' || !stateInfo?.repoStateRoot) {
    return view;
  }

  const sessionsInfo = inspectWorktreeSessions({
    cwd: options.cwd ?? stateInfo.projectRoot ?? process.cwd()
  });
  if (!sessionsInfo?.ok) {
    return view;
  }

  const workRoot = resolve(stateInfo.repoStateRoot, 'work');
  if (existsSync(workRoot)) {
    const otherActiveWorks = [];

    for (const entry of readdirSync(workRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) {
        continue;
      }

      const workflowPath = join(workRoot, entry.name, 'workflow.json');
      if (!existsSync(workflowPath)) {
        continue;
      }

      let workflow;
      try {
        workflow = parseJsonFile(workflowPath);
      } catch {
        continue;
      }

      if (!workflow?.id || !isActiveWorkflowStatus(workflow.status) || workflow.id === stateInfo.attachedWorkId) {
        continue;
      }

      const owner = resolveWorkflowOwner(workflow, sessionsInfo);
      otherActiveWorks.push({
        workId: workflow.id,
        status: workflow.status ?? null,
        ownerWorktreeId: owner.ownerWorktreeId,
        ownerLive: owner.ownerLive,
        ownerBranch: owner.ownerBranch,
        ownerWorktreePath: owner.ownerWorktreePath,
        unitId: workflow.unitId ?? null
      });
    }

    view.otherActiveWorks = otherActiveWorks.sort((a, b) => a.workId.localeCompare(b.workId));
  }

  view.staleAttachments = sessionsInfo.deadSessions
    .filter((session) => isTopLevelSession(session) && session.attachedWorkId)
    .map((session) => ({
      worktreeId: session.worktreeId,
      attachedWorkId: session.attachedWorkId,
      deadReason: session.deadReason
    }));

  return view;
}
