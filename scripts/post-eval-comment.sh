#!/usr/bin/env bash
#
# scripts/post-eval-comment.sh
#
# Post a sticky eval-smoke comment to the active PR. The comment uses
# a stable marker so subsequent pushes edit rather than duplicate.
#
# Inputs (env vars):
#   EVAL_RUN_DIR   — directory containing comparison.json (required)
#   PR_NUMBER      — PR number to comment on (required, except in CI
#                    where it is derived from $GITHUB_REF)
#   GH_TOKEN       — GitHub token (required for gh CLI)
#
# Marker: <!-- eval-smoke-comment -->
#
# Unit 02b-2 of the legibility recovery.

set -uo pipefail

MARKER="<!-- eval-smoke-comment -->"

# ----- Input validation -----

if [ -z "${EVAL_RUN_DIR:-}" ]; then
  echo "error: EVAL_RUN_DIR env var is required" >&2
  exit 1
fi

if [ ! -d "$EVAL_RUN_DIR" ]; then
  echo "error: EVAL_RUN_DIR does not exist: $EVAL_RUN_DIR" >&2
  exit 1
fi

COMPARISON_JSON="$EVAL_RUN_DIR/comparison.json"
if [ ! -f "$COMPARISON_JSON" ]; then
  echo "error: comparison.json not found at $COMPARISON_JSON" >&2
  exit 1
fi

if [ -z "${PR_NUMBER:-}" ] && [ -n "${GITHUB_REF:-}" ]; then
  PR_NUMBER=$(echo "$GITHUB_REF" | sed -nE 's|^refs/pull/([0-9]+)/.*|\1|p')
fi

if [ -z "${PR_NUMBER:-}" ]; then
  echo "error: PR_NUMBER not set and could not be derived from GITHUB_REF" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "error: gh CLI not found on PATH" >&2
  exit 1
fi

# ----- Build comment body -----

if command -v jq >/dev/null 2>&1; then
  REGRESSIONS=$(jq -r '.regressions | length' "$COMPARISON_JSON")
  IMPROVEMENTS=$(jq -r '.improvements | length' "$COMPARISON_JSON")
  EXIT_CODE=$(jq -r '.exit_code' "$COMPARISON_JSON")
  TABLE=$(jq -r '.table_markdown' "$COMPARISON_JSON")
else
  REGRESSIONS="?"
  IMPROVEMENTS="?"
  EXIT_CODE="?"
  TABLE="(jq not available — see comparison.json artifact)"
fi

if [ "$EXIT_CODE" = "0" ]; then
  STATUS_LINE="✅ Smoke evals clean — $REGRESSIONS regressions, $IMPROVEMENTS improvements"
else
  STATUS_LINE="❌ Smoke evals regressed — $REGRESSIONS regressions, $IMPROVEMENTS improvements"
fi

BODY=$(cat <<EOF
$MARKER
## Eval Smoke Results

$STATUS_LINE

$TABLE

<sub>Posted by Specwright eval-smoke workflow. This comment is updated on each push.</sub>
EOF
)

# ----- Find existing sticky comment -----

REPO="${GITHUB_REPOSITORY:-Obsidian-Owl/specwright}"

# Use the REST issue-comments endpoint so the returned `id` is the
# integer database ID required by the PATCH endpoint below.
EXISTING_ID=""
if command -v jq >/dev/null 2>&1; then
  EXISTING_ID=$(gh api "/repos/$REPO/issues/$PR_NUMBER/comments" 2>/dev/null | jq -r --arg marker "$MARKER" '
      .[] | select(.body | startswith($marker)) | .id
    ' | head -1)
fi

# ----- Post or edit -----

if [ -n "$EXISTING_ID" ] && [ "$EXISTING_ID" != "null" ]; then
  gh api --method PATCH \
    "/repos/$REPO/issues/comments/$EXISTING_ID" \
    -f body="$BODY" >/dev/null
  echo "Edited sticky comment $EXISTING_ID on PR #$PR_NUMBER"
else
  gh pr comment "$PR_NUMBER" --body "$BODY"
  echo "Posted new sticky comment on PR #$PR_NUMBER"
fi
