#!/usr/bin/env bash
#
# Tests for Unit 02b-2 GitHub Actions workflows.
#
# Validates:
#   .github/workflows/eval-smoke.yml — PR smoke check
#   .github/workflows/eval-full.yml  — weekly full runs
#
# Strategy: parse each YAML with Python's yaml module and assert
# structural properties. No actual workflow execution — that happens
# in CI when the PR runs.
#
# Usage: ./tests/test-eval-workflows-yaml.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

cd "$ROOT_DIR" || exit 1

assert_yaml_valid() {
  local path="$1"
  if python3 -c "import yaml; yaml.safe_load(open('$path'))" 2>/dev/null; then
    pass "$path is valid YAML"
  else
    fail "$path is not valid YAML"
  fi
}

assert_yaml_path_equals() {
  local path="$1"
  local jq_like="$2"
  local expected="$3"
  local message="$4"
  local actual
  actual=$(python3 -c "
import yaml, sys
with open('$path') as f:
    doc = yaml.safe_load(f)
expr = '$jq_like'
parts = [p for p in expr.split('.') if p]
v = doc
for p in parts:
    if isinstance(v, dict):
        v = v.get(p)
    else:
        v = None
        break
print(v if v is not None else 'MISSING')
" 2>&1)
  if [ "$actual" = "$expected" ]; then
    pass "$message"
  else
    fail "$message — expected '$expected', got '$actual'"
  fi
}

assert_yaml_has_key() {
  local path="$1"
  local jq_like="$2"
  local message="$3"
  local result
  # Note: PyYAML safe_load uses YAML 1.1, which interprets `on:` as
  # boolean True. We accept either the string key OR True as a match
  # for "on" specifically — GitHub Actions YAML has this idiom for
  # the trigger key.
  result=$(python3 -c "
import yaml
with open('$path') as f:
    doc = yaml.safe_load(f)
expr = '$jq_like'
parts = [p for p in expr.split('.') if p]
v = doc
for p in parts:
    if isinstance(v, dict):
        if p in v:
            v = v[p]
        elif p == 'on' and True in v:
            v = v[True]
        else:
            print('MISSING')
            raise SystemExit(0)
    else:
        print('MISSING')
        raise SystemExit(0)
print('OK')
" 2>&1)
  if [ "$result" = "OK" ]; then
    pass "$message"
  else
    fail "$message — key path '$jq_like' missing"
  fi
}

# ----- eval-smoke.yml -----

echo ""
echo "=== Test: .github/workflows/eval-smoke.yml ==="

SMOKE=".github/workflows/eval-smoke.yml"

if [ ! -f "$SMOKE" ]; then
  fail "$SMOKE does not exist"
else
  assert_yaml_valid "$SMOKE"
  assert_yaml_has_key "$SMOKE" "name" "eval-smoke.yml has top-level 'name'"
  assert_yaml_has_key "$SMOKE" "on" "eval-smoke.yml has 'on' trigger"
  assert_yaml_has_key "$SMOKE" "jobs" "eval-smoke.yml has 'jobs'"
  assert_yaml_has_key "$SMOKE" "permissions" "eval-smoke.yml has top-level 'permissions'"
  assert_yaml_path_equals "$SMOKE" "permissions.contents" "read" "eval-smoke.yml permissions.contents=read"
  assert_yaml_path_equals "$SMOKE" "permissions.pull-requests" "write" "eval-smoke.yml permissions.pull-requests=write"
  assert_yaml_has_key "$SMOKE" "jobs.smoke" "eval-smoke.yml has 'smoke' job"
  assert_yaml_path_equals "$SMOKE" "jobs.smoke.timeout-minutes" "20" "eval-smoke.yml smoke job timeout-minutes=20"
  assert_yaml_has_key "$SMOKE" "jobs.fork-skip" "eval-smoke.yml has 'fork-skip' job (architect BLOCK absorbed)"
fi

# ----- eval-full.yml -----

echo ""
echo "=== Test: .github/workflows/eval-full.yml ==="

FULL=".github/workflows/eval-full.yml"

if [ ! -f "$FULL" ]; then
  fail "$FULL does not exist"
else
  assert_yaml_valid "$FULL"
  assert_yaml_has_key "$FULL" "name" "eval-full.yml has top-level 'name'"
  assert_yaml_has_key "$FULL" "on" "eval-full.yml has 'on' trigger"
  assert_yaml_has_key "$FULL" "jobs" "eval-full.yml has 'jobs'"
  assert_yaml_has_key "$FULL" "jobs.runner" "eval-full.yml has 'runner' job"
  assert_yaml_has_key "$FULL" "jobs.dispatcher" "eval-full.yml has 'dispatcher' job (permission separation)"
  assert_yaml_path_equals "$FULL" "jobs.runner.timeout-minutes" "180" "eval-full.yml runner job timeout-minutes=180"
  # Runner permissions: read-only
  assert_yaml_path_equals "$FULL" "jobs.runner.permissions.contents" "read" "eval-full.yml runner has contents:read"
  # Dispatcher permissions: write to PRs/issues only
  assert_yaml_path_equals "$FULL" "jobs.dispatcher.permissions.contents" "write" "eval-full.yml dispatcher has contents:write"
  assert_yaml_path_equals "$FULL" "jobs.dispatcher.permissions.pull-requests" "write" "eval-full.yml dispatcher has pull-requests:write"
  assert_yaml_path_equals "$FULL" "jobs.dispatcher.permissions.issues" "write" "eval-full.yml dispatcher has issues:write"
fi

# ----- Optional: actionlint if available -----

echo ""
if command -v actionlint >/dev/null 2>&1; then
  if actionlint .github/workflows/eval-smoke.yml .github/workflows/eval-full.yml > /tmp/actionlint.out 2>&1; then
    pass "actionlint clean for both workflows"
  else
    fail "actionlint reported issues: $(cat /tmp/actionlint.out)"
  fi
else
  echo "  INFO: actionlint not on PATH; skipped extended workflow validation"
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
