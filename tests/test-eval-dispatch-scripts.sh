#!/usr/bin/env bash
#
# Tests for Unit 02b-2 dispatch scripts:
#   scripts/post-eval-comment.sh
#   scripts/eval-weekly-dispatch.sh
#
# Strategy: prepend a temp dir to PATH containing a stub `gh` binary
# that records its arguments to a file and exits 0. The real dispatch
# scripts are then invoked with controlled inputs and we assert that
# the recorded gh invocations match the expected branch.
#
# Usage: ./tests/test-eval-dispatch-scripts.sh
#   Exit 0 = all pass, exit 1 = any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cd "$ROOT_DIR" || exit 1

# ---------- Test harness ----------

# Create a fresh temp dir per test, install a stub gh, run, capture, clean up.
setup_stub_gh() {
  TMPDIR=$(mktemp -d)
  GH_LOG="$TMPDIR/gh-calls.log"
  cat > "$TMPDIR/gh" <<STUB_EOF
#!/usr/bin/env bash
# stub gh — records args, returns canned output if RESPONSE_FILE is set
echo "\$@" >> "$GH_LOG"
if [ -n "\${RESPONSE_FILE:-}" ] && [ -f "\$RESPONSE_FILE" ]; then
  cat "\$RESPONSE_FILE"
fi
exit 0
STUB_EOF
  chmod +x "$TMPDIR/gh"
  export PATH="$TMPDIR:$PATH"
  export ORIG_PATH="$PATH"
}

teardown_stub_gh() {
  rm -rf "$TMPDIR"
  unset RESPONSE_FILE
  unset GH_LOG
}

# ---------- post-eval-comment.sh ----------

echo ""
echo "=== Test: post-eval-comment.sh ==="

if [ ! -f scripts/post-eval-comment.sh ]; then
  fail "scripts/post-eval-comment.sh does not exist"
else
  pass "scripts/post-eval-comment.sh exists and is reachable"
fi

if [ -f scripts/post-eval-comment.sh ]; then

  # T1: stable marker present in script body
  setup_stub_gh
  if grep -q '<!-- eval-smoke-comment -->' scripts/post-eval-comment.sh; then
    pass "post-eval-comment.sh contains stable marker '<!-- eval-smoke-comment -->'"
  else
    fail "post-eval-comment.sh missing stable marker"
  fi
  teardown_stub_gh

  # T2: posts a new comment when no prior sticky comment exists
  setup_stub_gh
  RUN_DIR=$(mktemp -d)
  cat > "$RUN_DIR/comparison.json" <<'JSON'
{
  "regressions": [],
  "improvements": [],
  "missing_from_baseline": [],
  "missing_from_run": [],
  "exit_code": 0,
  "table_markdown": "| Eval | Pass Rate |\n|---|---|\n| eval-01 | 1.00 (=) |\n"
}
JSON
  # gh stub returns empty list for "comments" query
  echo '{"comments": []}' > "$TMPDIR/response.json"
  RESPONSE_FILE="$TMPDIR/response.json" \
    EVAL_RUN_DIR="$RUN_DIR" \
    PR_NUMBER="999" \
    bash scripts/post-eval-comment.sh > /dev/null 2>&1 || true
  if grep -q "pr comment" "$GH_LOG" 2>/dev/null || grep -q "issues/comments" "$GH_LOG" 2>/dev/null; then
    pass "post-eval-comment.sh issues a comment-creation gh call when no prior sticky exists"
  else
    fail "post-eval-comment.sh did not issue a gh call (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -rf "$RUN_DIR"
  teardown_stub_gh

  # T3: edits an existing sticky comment when one exists
  setup_stub_gh
  RUN_DIR=$(mktemp -d)
  cat > "$RUN_DIR/comparison.json" <<'JSON'
{
  "regressions": [],
  "improvements": [],
  "missing_from_baseline": [],
  "missing_from_run": [],
  "exit_code": 0,
  "table_markdown": "| Eval | Pass Rate |\n"
}
JSON
  # gh stub returns one matching sticky comment
  cat > "$TMPDIR/response.json" <<'JSON'
{"comments": [{"id": 12345, "body": "<!-- eval-smoke-comment -->\nold body"}]}
JSON
  RESPONSE_FILE="$TMPDIR/response.json" \
    EVAL_RUN_DIR="$RUN_DIR" \
    PR_NUMBER="999" \
    bash scripts/post-eval-comment.sh > /dev/null 2>&1 || true
  if grep -qE "(PATCH.*issues/comments|api.*issues/comments/12345)" "$GH_LOG" 2>/dev/null; then
    pass "post-eval-comment.sh patches the existing sticky comment by id"
  else
    fail "post-eval-comment.sh did not patch existing comment (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -rf "$RUN_DIR"
  teardown_stub_gh
fi

# ---------- eval-weekly-dispatch.sh ----------

echo ""
echo "=== Test: eval-weekly-dispatch.sh ==="

if [ ! -f scripts/eval-weekly-dispatch.sh ]; then
  fail "scripts/eval-weekly-dispatch.sh does not exist"
else
  pass "scripts/eval-weekly-dispatch.sh exists and is reachable"
fi

if [ -f scripts/eval-weekly-dispatch.sh ]; then

  # Helper: build a results dir with comparison.json files for each suite
  make_results_dir() {
    local dir
    dir=$(mktemp -d)
    for suite in skill workflow integration; do
      mkdir -p "$dir/$suite-run"
      cp "$1" "$dir/$suite-run/comparison.json"
    done
    echo "$dir"
  }

  # T1: regression path → opens an issue
  setup_stub_gh
  REGRESSION_JSON=$(mktemp)
  cat > "$REGRESSION_JSON" <<'JSON'
{
  "regressions": [{"eval_id": "eval-01", "metric": "pass_rate", "baseline_value": 1.0, "actual_value": 0.5, "delta": -0.5, "verdict": "regressed"}],
  "improvements": [],
  "missing_from_baseline": [],
  "missing_from_run": [],
  "exit_code": 1,
  "table_markdown": "| Eval | Pass Rate |\n| eval-01 | 0.50 (-0.50) |\n"
}
JSON
  RESULTS=$(make_results_dir "$REGRESSION_JSON")
  SKILL_EXIT=1 WORKFLOW_EXIT=0 INTEGRATION_EXIT=0 \
    EVAL_RESULTS_DIR="$RESULTS" \
    bash scripts/eval-weekly-dispatch.sh > /dev/null 2>&1 || true
  if grep -q "issue create" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh opens an issue when SKILL_EXIT=1 (regression)"
  else
    fail "eval-weekly-dispatch.sh did not open an issue (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -f "$REGRESSION_JSON"
  rm -rf "$RESULTS"
  teardown_stub_gh

  # T2: strict-improvement path → opens a PR
  setup_stub_gh
  IMPROVEMENT_JSON=$(mktemp)
  cat > "$IMPROVEMENT_JSON" <<'JSON'
{
  "regressions": [],
  "improvements": [{"eval_id": "eval-01", "metric": "duration_ms", "baseline_value": 30000, "actual_value": 25000, "delta": -5000}],
  "missing_from_baseline": [],
  "missing_from_run": [],
  "exit_code": 0,
  "table_markdown": "| Eval | Duration |\n| eval-01 | 25000ms (-5000ms) |\n"
}
JSON
  RESULTS=$(make_results_dir "$IMPROVEMENT_JSON")
  SKILL_EXIT=0 WORKFLOW_EXIT=0 INTEGRATION_EXIT=0 \
    EVAL_RESULTS_DIR="$RESULTS" \
    bash scripts/eval-weekly-dispatch.sh > /dev/null 2>&1 || true
  if grep -q "pr create" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh opens a PR on strict improvement"
  else
    fail "eval-weekly-dispatch.sh did not open a PR (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -f "$IMPROVEMENT_JSON"
  rm -rf "$RESULTS"
  teardown_stub_gh

  # T3: flat path (no improvement, no regression) → exits silently
  setup_stub_gh
  FLAT_JSON=$(mktemp)
  cat > "$FLAT_JSON" <<'JSON'
{
  "regressions": [],
  "improvements": [],
  "missing_from_baseline": [],
  "missing_from_run": [],
  "exit_code": 0,
  "table_markdown": "| Eval | Pass Rate |\n| eval-01 | 1.00 (=) |\n"
}
JSON
  RESULTS=$(make_results_dir "$FLAT_JSON")
  SKILL_EXIT=0 WORKFLOW_EXIT=0 INTEGRATION_EXIT=0 \
    EVAL_RESULTS_DIR="$RESULTS" \
    bash scripts/eval-weekly-dispatch.sh > /dev/null 2>&1 || true
  if [ ! -s "$GH_LOG" ]; then
    pass "eval-weekly-dispatch.sh exits silently on flat run (no gh calls)"
  else
    fail "eval-weekly-dispatch.sh issued gh calls on a flat run (log: $(cat "$GH_LOG"))"
  fi
  rm -f "$FLAT_JSON"
  rm -rf "$RESULTS"
  teardown_stub_gh

  # T4: mixed path (one regression + one improvement) → opens issue (regression takes precedence)
  setup_stub_gh
  MIXED_JSON=$(mktemp)
  cat > "$MIXED_JSON" <<'JSON'
{
  "regressions": [{"eval_id": "eval-02", "metric": "duration_ms", "baseline_value": 10000, "actual_value": 20000, "delta": 10000, "verdict": "slowed"}],
  "improvements": [{"eval_id": "eval-01", "metric": "pass_rate", "baseline_value": 0.8, "actual_value": 0.9, "delta": 0.1}],
  "missing_from_baseline": [],
  "missing_from_run": [],
  "exit_code": 1,
  "table_markdown": "| Eval | Pass Rate | Duration |\n"
}
JSON
  RESULTS=$(make_results_dir "$MIXED_JSON")
  SKILL_EXIT=1 WORKFLOW_EXIT=0 INTEGRATION_EXIT=0 \
    EVAL_RESULTS_DIR="$RESULTS" \
    bash scripts/eval-weekly-dispatch.sh > /dev/null 2>&1 || true
  if grep -q "issue create" "$GH_LOG" 2>/dev/null && ! grep -q "pr create" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh opens issue (NOT PR) on mixed regression+improvement"
  else
    fail "eval-weekly-dispatch.sh wrong dispatch on mixed (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -f "$MIXED_JSON"
  rm -rf "$RESULTS"
  teardown_stub_gh
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
