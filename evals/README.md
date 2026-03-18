# Specwright Eval Framework

Three-layer evaluation framework for testing Specwright skills.

## Prerequisites

- Python 3.10+
- [Claude CLI](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Git
- Node.js (for TypeScript fixture execution)

## Quick Start

```bash
# Dry run — see what would execute without running skills
python -m evals --suite skill --dry-run

# Run a single eval case (1 trial)
python -m evals --suite skill --case sw-init-fresh-ts

# Run full skill suite with 3 trials
python -m evals --suite skill --trials 3

# Run integration handoff evals
python -m evals --suite integration

# View results in browser
python -m evals --view evals/results/run-YYYYMMDD-HHMMSS
```

## CLI Reference

```
python -m evals [OPTIONS]

Options:
  --suite NAME        Run eval suite (skill, integration, workflow)
  --case ID           Run only the named eval case
  --trials N          Number of trials per case (default: 1)
  --timeout SECS      Per-skill timeout in seconds (default: 300)
  --results-dir PATH  Override results directory
  --view PATH         Launch HTML viewer for results directory
  --dry-run           Print eval cases without running
```

## Directory Structure

```
evals/
├── __main__.py         # CLI entry point
├── framework/          # Python orchestration
│   ├── orchestrator.py # Pipeline: load → setup → run → grade → aggregate
│   ├── runner.py       # Invoke skills via claude -p
│   ├── chainer.py      # Sequential skill execution
│   ├── setup.py        # Repo/fixture preparation
│   ├── capture.py      # State snapshots
│   ├── prompts.py      # Pre-scripted prompt templates
│   ├── grader.py       # Code-based expectation graders
│   ├── model_grader.py # LLM-as-judge rubric grading
│   ├── aggregator.py   # Statistical aggregation (pass@k, flaky detection)
│   └── viewer/         # Self-contained HTML results viewer
├── suites/             # Eval definitions
│   ├── skill/          # Layer 1: isolated skill evals
│   ├── integration/    # Layer 2: handoff evals
│   └── workflow/       # Layer 3: end-to-end evals (seeds required)
├── agents/             # Eval-specific grading agents
├── tests/              # Framework self-tests
└── results/            # Run outputs (gitignored)
```

## Results Layout

Each run produces:
```
results/run-{YYYYMMDD-HHMMSS}/
├── config.json          # Run metadata
├── evals/
│   └── {eval-id}/
│       └── trial-{n}/
│           └── grading.json
├── benchmark.json       # Aggregated statistics
```

## Running Framework Tests

```bash
python -m pytest evals/tests/ -v
```

## Eval Layers

- **Layer 1 (Skill)**: Tests individual skills in isolation with controlled inputs
- **Layer 2 (Integration)**: Tests handoffs between skills (state transitions, artifact references)
- **Layer 3 (Workflow)**: Tests full init→design→plan→build→verify pipelines against real repos

## Workflow Seeds (Layer 3)

Layer 3 evals require seed repos from SWE-PolyBench. To populate:

```bash
pip install datasets
python -m evals.framework.verify_seeds --populate --verify
```
