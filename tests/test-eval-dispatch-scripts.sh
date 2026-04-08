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

setup_stub_gh() {
  ORIG_PATH="$PATH"
  TMPDIR=$(mktemp -d)
  GH_LOG="$TMPDIR/gh-calls.log"
  cat > "$TMPDIR/gh" <<'STUB_EOF'
#!/usr/bin/env bash
echo "$@" >> "$GH_LOG"
if [ -n "${RESPONSE_FILE:-}" ] && [ -f "$RESPONSE_FILE" ]; then
  cat "$RESPONSE_FILE"
fi
exit 0
STUB_EOF
  chmod +x "$TMPDIR/gh"
  export PATH="$TMPDIR:$PATH"
  export GH_LOG
}

teardown_stub_gh() {
  PATH="$ORIG_PATH"
  export PATH
  rm -rf "$TMPDIR"
  unset RESPONSE_FILE
  unset GH_LOG
  unset TMPDIR
  unset ORIG_PATH
}

echo ""
echo "=== Test: post-eval-comment.sh ==="

if [ ! -f scripts/post-eval-comment.sh ]; then
  fail "scripts/post-eval-comment.sh does not exist"
else
  pass "scripts/post-eval-comment.sh exists and is reachable"
fi

if [ -f scripts/post-eval-comment.sh ]; then
  setup_stub_gh
  if grep -q '<!-- eval-smoke-comment -->' scripts/post-eval-comment.sh; then
    pass "post-eval-comment.sh contains stable marker '<!-- eval-smoke-comment -->'"
  else
    fail "post-eval-comment.sh missing stable marker"
  fi
  teardown_stub_gh

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
  echo '[]' > "$TMPDIR/response.json"
  RESPONSE_FILE="$TMPDIR/response.json" \
    EVAL_RUN_DIR="$RUN_DIR" \
    PR_NUMBER="999" \
    bash scripts/post-eval-comment.sh > /dev/null 2>&1 || true
  if grep -q "pr comment" "$GH_LOG" 2>/dev/null; then
    pass "post-eval-comment.sh issues a new-comment gh call when no prior sticky exists"
  else
    fail "post-eval-comment.sh did not issue a new-comment gh call (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -rf "$RUN_DIR"
  teardown_stub_gh

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
  cat > "$TMPDIR/response.json" <<'JSON'
[{"id": 12345, "body": "<!-- eval-smoke-comment -->\nold body"}]
JSON
  RESPONSE_FILE="$TMPDIR/response.json" \
    EVAL_RUN_DIR="$RUN_DIR" \
    PR_NUMBER="999" \
    bash scripts/post-eval-comment.sh > /dev/null 2>&1 || true
  if grep -qE "(PATCH.*issues/comments|api.*issues/comments/12345)" "$GH_LOG" 2>/dev/null; then
    pass "post-eval-comment.sh patches the existing sticky comment by integer id"
  else
    fail "post-eval-comment.sh did not patch existing comment (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -rf "$RUN_DIR"
  teardown_stub_gh

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
  cat > "$TMPDIR/response.json" <<'JSON'
[{"id": 98765432, "body": "<!-- eval-smoke-comment -->\nold body"}]
JSON
  RESPONSE_FILE="$TMPDIR/response.json" \
    EVAL_RUN_DIR="$RUN_DIR" \
    PR_NUMBER="999" \
    bash scripts/post-eval-comment.sh > /dev/null 2>&1 || true
  if grep -qE "issues/comments/98765432" "$GH_LOG" 2>/dev/null; then
    pass "post-eval-comment.sh uses the REST endpoint integer id for PATCH"
  else
    fail "post-eval-comment.sh did not use the REST integer id (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  if grep -q "pr view" "$GH_LOG" 2>/dev/null; then
    fail "post-eval-comment.sh regressed to gh pr view comment lookup (log: $(cat "$GH_LOG" 2>/dev/null))"
  else
    pass "post-eval-comment.sh avoids gh pr view for sticky-comment lookup"
  fi
  rm -rf "$RUN_DIR"
  teardown_stub_gh
fi

echo ""
echo "=== Test: eval-weekly-dispatch.sh ==="

if [ ! -f scripts/eval-weekly-dispatch.sh ]; then
  fail "scripts/eval-weekly-dispatch.sh does not exist"
else
  pass "scripts/eval-weekly-dispatch.sh exists and is reachable"
fi

if [ -f scripts/eval-weekly-dispatch.sh ]; then
  setup_stub_gh_git_python() {
    setup_stub_gh
    cat > "$TMPDIR/git" <<'STUB_EOF'
#!/usr/bin/env bash
echo "git $*" >> "$GH_LOG"
if [ "$1" = "diff" ] && [ "$2" = "--quiet" ]; then
  exit 1
fi
exit 0
STUB_EOF
    chmod +x "$TMPDIR/git"
    cat > "$TMPDIR/python3" <<'STUB_EOF'
#!/usr/bin/env bash
echo "python3 $*" >> "$GH_LOG"
exit 0
STUB_EOF
    chmod +x "$TMPDIR/python3"
  }

  make_results_dir() {
    local comparison_src="$1"
    local dir
    dir=$(mktemp -d)
    local i=1
    for suite in skill workflow integration; do
      local run_dir="$dir/run-20260408T14000${i}"
      mkdir -p "$run_dir"
      cat > "$run_dir/config.json" <<CONFIG_EOF
{
  "timestamp": "2026-04-08T14:00:0${i}Z",
  "suite": "$suite",
  "trials": 1,
  "timeout": 600,
  "python_version": "3.11.11"
}
CONFIG_EOF
      cp "$comparison_src" "$run_dir/comparison.json"
      i=$((i + 1))
    done
    echo "$dir"
  }

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

  setup_stub_gh_git_python
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
  if grep -q "python3 scripts/eval-write-baselines-from-results.py" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh invokes the write-baselines helper"
  else
    fail "eval-weekly-dispatch.sh did not invoke the write-baselines helper (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  if grep -qE "git checkout -b auto/eval-baseline-refresh" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh creates auto-refresh branch"
  else
    fail "eval-weekly-dispatch.sh did not create branch (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  if grep -q "git commit" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh commits the baseline refresh"
  else
    fail "eval-weekly-dispatch.sh did not commit (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  if grep -q "git push origin auto/eval-baseline-refresh" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh pushes the refresh branch"
  else
    fail "eval-weekly-dispatch.sh did not push branch (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  if grep -q "pr create" "$GH_LOG" 2>/dev/null; then
    pass "eval-weekly-dispatch.sh opens a PR on strict improvement"
  else
    fail "eval-weekly-dispatch.sh did not open a PR (log: $(cat "$GH_LOG" 2>/dev/null))"
  fi
  rm -f "$IMPROVEMENT_JSON"
  rm -rf "$RESULTS"
  teardown_stub_gh

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
