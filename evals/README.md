# Specwright Eval Framework

Three-layer evaluation framework for testing Specwright skills.

## Prerequisites

- Python 3.10+
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Git
- Node.js (for TypeScript fixture execution)

## Directory Structure

```
evals/
├── framework/          # Python orchestration
│   ├── runner.py       # Invoke skills via claude -p
│   ├── chainer.py      # Sequential skill execution
│   ├── setup.py        # Repo/fixture preparation
│   ├── capture.py      # State snapshots
│   ├── prompts.py      # Pre-scripted prompt templates
│   └── grader.py       # Code-based expectation graders
├── suites/             # Eval definitions
│   ├── skill/          # Layer 1: isolated skill evals
│   ├── integration/    # Layer 2: handoff evals
│   └── workflow/       # Layer 3: end-to-end evals
├── agents/             # Eval-specific grading agents
├── tests/              # Framework self-tests
└── results/            # Run outputs (gitignored)
```

## Running a Single Eval Case

```bash
python -m evals.framework.runner --eval suites/skill/evals.json --case sw-build-simple-function
```

## Running the Full Skill Suite

```bash
python -m evals.framework.runner --suite suites/skill/evals.json --trials 3
```

## Running Framework Tests

```bash
python -m pytest evals/tests/ -v
```

## Eval Layers

- **Layer 1 (Skill)**: Tests individual skills in isolation with controlled inputs
- **Layer 2 (Integration)**: Tests handoffs between skills (state transitions, artifact references)
- **Layer 3 (Workflow)**: Tests full init→design→plan→build→verify pipelines against real repos
