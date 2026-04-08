#!/usr/bin/env bash
#
# scripts/eval-weekly-dispatch.sh
#
# Dispatcher for the weekly eval-full workflow. Reads exit codes and
# comparison.json files for each suite, then either:
#   - Opens a regression issue (any suite regressed)
#   - Opens a baseline-refresh PR (strict improvement: no regressions
#     AND at least one improvement somewhere)
#   - Exits silently (flat run)
#
# NEVER pushes directly to main, NEVER force-pushes, NEVER auto-merges.
# PR and issue are the only outputs.
#
# Inputs (env vars):
#   SKILL_EXIT, WORKFLOW_EXIT, INTEGRATION_EXIT — exit codes from each
#     `python -m evals --suite X --compare-to-baseline` invocation
#   EVAL_RESULTS_DIR — root containing per-suite run dirs (each with
#     comparison.json). Defaults to evals/results.
#   GH_TOKEN — required for gh CLI
#
# Strict-improvement rule (AC-12 simplified): zero regressions across
# all suites AND at least one improvement across all suites. The
# original spec called for "previously failing now passing" as an
# additional improvement signal, but ComparisonResult does not track
# that — adding it would require touching baseline.py. Documented in
# the unit's plan.md.
#
# Unit 02b-2 of the legibility recovery.

set -uo pipefail

EVAL_RESULTS_DIR="${EVAL_RESULTS_DIR:-evals/results}"
SKILL_EXIT="${SKILL_EXIT:-0}"
WORKFLOW_EXIT="${WORKFLOW_EXIT:-0}"
INTEGRATION_EXIT="${INTEGRATION_EXIT:-0}"

# GITHUB_REPOSITORY is consumed implicitly by `gh` when running inside
# CI, so we do not need to pass it as a flag. Set a default for local
# test runs (gh stub does not care).
: "${GITHUB_REPOSITORY:=Obsidian-Owl/specwright}"
export GITHUB_REPOSITORY

TODAY=$(date -u +%Y-%m-%d)

# ----- Aggregate per-suite signals -----
#
# Discovery: the eval framework (evals/framework/orchestrator.py) creates
# results dirs named run-{timestamp} (one per invocation). eval-full.yml
# runs three suites in sequence, producing three run-* dirs. Each run dir
# contains a config.json that records the suite name and a comparison.json
# from the compare-to-baseline step.
#
# We walk all run-* dirs, read config.json to identify the suite, and
# pick the newest run per suite (in case multiple runs exist for the
# same suite). This replaces the original glob `*-run`, which
# incorrectly assumed per-suite directory naming.

ANY_REGRESSION=0
ANY_IMPROVEMENT=0
ALL_TABLES=""

declare -A suite_latest_dir
declare -A suite_latest_mtime

for run_dir in "$EVAL_RESULTS_DIR"/run-*; do
  if [ ! -d "$run_dir" ]; then
    continue
  fi
  config="$run_dir/config.json"
  if [ ! -f "$config" ]; then
    continue
  fi
  if ! command -v jq >/dev/null 2>&1; then
    continue
  fi

  suite_name=$(jq -r '.suite // empty' "$config")
  if [ -z "$suite_name" ]; then
    continue
  fi

  mtime=$(stat -c '%Y' "$run_dir" 2>/dev/null || stat -f '%m' "$run_dir" 2>/dev/null || echo 0)
  if [ "${suite_latest_mtime[$suite_name]:-0}" -lt "$mtime" ]; then
    suite_latest_mtime[$suite_name]=$mtime
    suite_latest_dir[$suite_name]=$run_dir
  fi
done

for suite_name in "${!suite_latest_dir[@]}"; do
  run_dir="${suite_latest_dir[$suite_name]}"
  comp="$run_dir/comparison.json"
  if [ ! -f "$comp" ]; then
    continue
  fi

  regs=$(jq -r '.regressions | length' "$comp")
  imps=$(jq -r '.improvements | length' "$comp")
  table=$(jq -r '.table_markdown' "$comp")

  if [ "${regs:-0}" -gt 0 ]; then
    ANY_REGRESSION=1
  fi
  if [ "${imps:-0}" -gt 0 ]; then
    ANY_IMPROVEMENT=1
  fi

  ALL_TABLES="${ALL_TABLES}

### ${suite_name}

${table}
"
done

# Also fold in the explicit exit codes — these are the suite-level
# verdicts from `--compare-to-baseline` and may indicate failure even
# when no comparison.json was written (for example if the suite errored
# before the comparator ran).
if [ "${SKILL_EXIT}" != "0" ] || [ "${WORKFLOW_EXIT}" != "0" ] || [ "${INTEGRATION_EXIT}" != "0" ]; then
  ANY_REGRESSION=1
fi

# ----- Dispatch -----

if [ "$ANY_REGRESSION" = "1" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI not found on PATH" >&2
    exit 1
  fi

  ISSUE_BODY=$(cat <<EOF
The weekly eval-full run detected a regression on $TODAY.

Per-suite exit codes:
- skill: \`$SKILL_EXIT\`
- workflow: \`$WORKFLOW_EXIT\`
- integration: \`$INTEGRATION_EXIT\`

## Regressions
$ALL_TABLES

---
Posted by \`scripts/eval-weekly-dispatch.sh\` (Specwright eval-full workflow).
EOF
)

  gh issue create \
    --title "Eval regression detected — $TODAY" \
    --label "eval-regression,needs-triage" \
    --body "$ISSUE_BODY" || {
      gh issue create \
        --title "Eval regression detected — $TODAY" \
        --body "$ISSUE_BODY"
    }
  exit 0
fi

if [ "$ANY_IMPROVEMENT" = "1" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "error: gh CLI not found on PATH" >&2
    exit 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    echo "error: git not found on PATH" >&2
    exit 1
  fi

  BRANCH="auto/eval-baseline-refresh-$TODAY"

  # Rebuild baselines from the downloaded run artifacts rather than
  # re-running live evals in the dispatcher job.
  if ! command -v python3 >/dev/null 2>&1; then
    echo "error: python3 not found on PATH" >&2
    exit 1
  fi

  python3 scripts/eval-write-baselines-from-results.py \
    --results-dir "$EVAL_RESULTS_DIR" \
    --baselines-dir "evals/baselines"

  if git diff --quiet -- evals/baselines/; then
    echo "::notice::Baseline files unchanged after refresh; no PR opened."
    exit 0
  fi

  git config user.email "github-actions[bot]@users.noreply.github.com"
  git config user.name "github-actions[bot]"
  git checkout -b "$BRANCH"
  git add evals/baselines/
  git commit -m "chore(evals): refresh baselines for week of $TODAY"
  git push origin "$BRANCH"

  PR_BODY=$(cat <<EOF
The weekly eval-full run detected strict improvement on $TODAY.

Per-suite exit codes:
- skill: \`$SKILL_EXIT\`
- workflow: \`$WORKFLOW_EXIT\`
- integration: \`$INTEGRATION_EXIT\`

## Improvements
$ALL_TABLES

This PR refreshes the baseline files to lock in the improvement.
Review the delta and merge to update tolerances.

---
Posted by \`scripts/eval-weekly-dispatch.sh\` (Specwright eval-full workflow).
EOF
)

  gh pr create \
    --title "chore(evals): refresh baselines for week of $TODAY" \
    --label "eval-baseline" \
    --base main \
    --head "$BRANCH" \
    --body "$PR_BODY" || {
      gh pr create \
        --title "chore(evals): refresh baselines for week of $TODAY" \
        --base main \
        --head "$BRANCH" \
        --body "$PR_BODY"
    }
  exit 0
fi

exit 0
