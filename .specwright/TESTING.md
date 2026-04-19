# Specwright Testing Strategy

How this project should be tested. Classifies boundaries, documents mock allowances,
and describes available test infrastructure.

Precedence: CONSTITUTION.md rules override this document on any conflict.

## Boundaries

### Internal (test with real components — no mocks)

| Boundary | Description |
|----------|------------|
| Eval framework modules | `runner.py` → `grader.py` → `aggregator.py` → `viewer/`. Import real modules, test real interactions. |
| Build system | `build/build.sh` transforms `core/` → `dist/`. Test against real build output in `dist/`. |
| Core skills/protocols/agents | Markdown files. Validate content via file reads and pattern matching, not mocks. |
| Setup → Capture → Grade pipeline | `setup.py` copies real fixtures, `capture.py` reads real `.specwright/` state, `grader.py` checks real files. |

### External (mock with contracts or recorded responses)

| Boundary | Description | Mock Approach |
|----------|------------|---------------|
| Claude CLI (`claude -p`) | Subprocess invocation for skill execution and model grading. | Mock `subprocess.Popen`/`subprocess.run` with recorded stream-json responses. |
| GitHub API (`gh` CLI) | PR creation, issue management, branch operations. | Mock `subprocess.run` for `gh` commands. |
| Git operations | Clone, checkout, commit, push. | Mock `subprocess.run` for `git` commands in unit tests. Use real git in integration tests (temp repos). |

### Expensive (mock with rationale)

| Boundary | Description | Rationale | Live Testing |
|----------|------------|-----------|-------------|
| Real skill invocations via subagents | Running `/sw-init`, `/sw-build` etc. against fixture repos. | Each invocation consumes significant tokens (50K-200K) on Max subscription. | Run via `/sw-eval` command manually. Not in CI. |
| SWE-PolyBench seed verification | Cloning real repos, installing deps, running tests. | Network + disk + time intensive. | Run `verify_seeds.py --populate --verify` manually before workflow evals. |

## Test Infrastructure

### Python test suite (eval framework)
- **Framework**: pytest
- **Location**: `evals/tests/`
- **Run**: `python -m pytest evals/tests/ -v`
- **Integration tests**: marked with `@pytest.mark.integration`, skipped by default
- **Coverage**: 440+ tests across 10 test modules

### Shell test suite (build output)
- **Framework**: Custom bash assertions (`tests/test-claude-code-build.sh`)
- **Location**: `tests/`
- **Run**: `bash tests/test-claude-code-build.sh`
- **Coverage**: 152+ assertions validating build output structure

### Eval framework (skill testing)
- **Framework**: Custom eval harness (`evals/framework/`)
- **Entry point**: `/sw-eval` command (subagent-based) or `python -m evals` (CLI)
- **Suites**: skill (Layer 1), integration (Layer 2), workflow (Layer 3)
- **Grading**: Code-based (file checks, state validation) + model-based (LLM rubric scoring)

## Mock Allowances

| Dependency | May Mock? | Rationale |
|-----------|----------|-----------|
| `subprocess.Popen` (claude CLI) | Yes | External process. Mock with recorded stream-json responses. |
| `subprocess.run` (git, gh) | Yes | External CLI tools. Mock in unit tests, real in integration tests. |
| `os.path.exists`, `shutil.copytree` | Yes (in setup.py tests) | Filesystem operations at module boundary. |
| Eval framework internal modules | **No** | Internal boundaries. Import real modules, test real interactions. |
| `evals/framework/grader.py` check functions | **No** | Core grading logic. Test with real temp dirs and real file content. |
| `evals/framework/aggregator.py` | **No** | Pure computation. Test with real inputs, no mocking needed. |

## Lessons Learned

- **Shell injection via `shell=True`**: Always use list-form subprocess args. `shell=True` requires documented trust boundary. (PR #82 review)
- **Eval definition type mismatches**: Eval JSON `type` fields must match grader dispatch keys exactly. Recurring (3x). (PR #82, #83 reviews)
- **`CalledProcessError.__str__()` omits stderr**: Wrap `subprocess.run(check=True)` with helper that surfaces stderr in exception messages. (Unit 1 build)
- **Glob patterns in `os.path.exists()`**: File existence checks must detect and expand glob patterns. `os.path.exists("path/*/file")` always returns False. (PR #82 review)
