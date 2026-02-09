---
name: gate-build
description: >-
  Build and test verification gate. Runs build and test commands from config,
  captures output as evidence for the validation pipeline.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Specwright Gate: Build and Test

## Step 1: Read Configuration and State
Read `.specwright/config.json` for `commands.build` and `commands.test`.
Read `.specwright/state/workflow.json`. Extract `currentEpic.id` and `currentEpic.specDir`.
If no epic active, STOP: "No active epic. Run /specwright:specify first."

## Step 2: Create Evidence Directory
```bash
mkdir -p {specDir}/evidence/
```

## Step 3: Run Build Command
```bash
{commands.build} 2>&1 | tee {specDir}/evidence/build-output.txt
```
If exit code non-zero: update `gates.build` to `{"status":"FAIL","lastRun":"<ISO>","evidence":"{specDir}/evidence/build-output.txt"}`, update `lastUpdated`, output FAIL result, STOP.

## Step 4: Run Test Command
```bash
{commands.test} 2>&1 | tee {specDir}/evidence/test-output.txt
```

## Step 5: Parse Test Results
Parse the test output to determine: total tests, passed, failed, skipped.
Note: The output format varies by language/framework — use LLM reasoning to parse whatever format the test runner produces.
If ANY tests FAIL or ANY tests SKIPPED without justification: update gate to FAIL, STOP.

## Step 6: Check for Warnings
Scan build output for compilation warnings. Log count if found.

## Step 7: Update Gate Status
On success, update `.specwright/state/workflow.json` `gates.build`:
```json
{"status": "PASS", "lastRun": "<ISO>", "evidence": "{specDir}/evidence/build-output.txt"}
```
Update `lastUpdated`.

## Step 8: Output Result
```
BUILD GATE: PASS
- Build: SUCCESS
- Tests: X passed, 0 failed, 0 skipped
- Warnings: N compilation warnings
- Evidence: {specDir}/evidence/
```
On failure:
```
BUILD GATE: FAIL
- Build/Tests: FAILED (see evidence)
- Evidence: {specDir}/evidence/
```
