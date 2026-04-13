import { execFileSync } from 'child_process';
import { createHash } from 'crypto';
import { basename, dirname, join, resolve } from 'path';

const FAILURE_CODE = 'GIT_RESOLUTION_FAILED';
const PRIMARY_WORKTREE_ID = 'main-worktree';
const LEGACY_STATE_SEGMENTS = ['.specwright', 'state'];

function runGit(args, cwd) {
  return execFileSync('git', args, {
    cwd,
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
