---
description: Run Specwright eval suite. Spawns subagents to run skills in fixture workdirs, then grades results.
---

# Specwright Eval Runner

Run eval cases by spawning subagents for skill invocation, then grading the results.

## Usage

```
/sw-eval --suite skill                    # Run all skill evals
/sw-eval --suite skill --case sw-init-fresh-ts  # Run one case
/sw-eval --suite skill --dry-run          # List cases without running
/sw-eval --suite integration              # Run integration evals
```

## Instructions

Parse the arguments from the command input. The arguments follow the patterns above.

### Step 1: Load the eval suite

Run this to load and validate the eval suite:
```bash
python -m evals --suite <SUITE_NAME> --dry-run
```

This prints each eval case ID and its fixture path. If `--dry-run` was requested, stop here and show the output.

If `--case` was specified, filter to only that case.

### Step 2: For each eval case

For each eval case (from the dry-run output), do the following:

#### 2a. Setup fixture

Copy the fixture to a temp working directory:
```bash
python -c "
import shutil, tempfile, os, json
fixture_path = os.path.join('evals', '<FIXTURE_PATH>')
workdir = tempfile.mkdtemp(prefix='eval-')
shutil.copytree(fixture_path, workdir, dirs_exist_ok=True)
print(workdir)
"
```

Save the workdir path for the next steps.

#### 2b. Run the skill via subagent

Spawn a subagent using the Agent tool:

```
Agent(
  prompt="<THE EVAL PROMPT - resolve from evals.json prompt_template + prompt_args>

Work in this directory: <WORKDIR>
Change to this directory first, then perform the task.
Accept all defaults. Do not ask clarifying questions.",
  subagent_type="general-purpose",
  description="Eval: <EVAL_ID>"
)
```

The prompt should describe the task naturally — do NOT use slash command syntax like `/sw-init`. Instead, describe what the skill does:
- For `sw-init`: "Initialize Specwright in this project. Detect the stack, create constitution and charter, configure quality gates."
- For `sw-build`: "Implement the code per the spec and plan in .specwright/work/. Follow TDD — write tests first, then implementation."
- For `sw-design`: "Design a solution for this problem: <problem_statement>. Research the codebase, propose a design, run adversarial critique."

Wait for the subagent to complete.

#### 2c. Grade the results

Run grading via Python:
```bash
python -m evals --grade-workdir <WORKDIR> --eval-id <EVAL_ID> --suite <SUITE_NAME> --output <RESULTS_DIR>/evals/<EVAL_ID>/trial-1/grading.json
```

#### 2d. Report progress

Print to the user:
```
✓ <EVAL_ID> — pass_rate: <RATE>
```

#### 2e. Cleanup

```bash
rm -rf <WORKDIR>
```

### Step 3: Aggregate

After all cases complete:
```bash
python -m evals --aggregate <RESULTS_DIR>
```

### Step 4: Report

Show the final summary table:
```
| Eval Case | Pass Rate | Duration |
|-----------|-----------|----------|
| ... | ... | ... |

Results: <RESULTS_DIR>
```
