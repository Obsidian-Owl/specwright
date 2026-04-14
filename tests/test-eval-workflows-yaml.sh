#!/usr/bin/env bash
#
# Tests for GitHub Actions workflow contracts.
#
# Validates:
#   .github/workflows/eval-smoke.yml — PR smoke check
#   .github/workflows/eval-full.yml  — weekly full runs
#   .github/workflows/release-finalize.yml — release publish contract
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

assert_step_uses() {
  local path="$1"
  local job="$2"
  local step_name="$3"
  local expected="$4"
  local message="$5"
  local actual
  actual=$(python3 -c "
import yaml
with open('$path') as f:
    doc = yaml.safe_load(f)
steps = doc.get('jobs', {}).get('$job', {}).get('steps', [])
for step in steps:
    if step.get('name') == '$step_name':
        print(step.get('uses', 'MISSING'))
        raise SystemExit(0)
print('MISSING')
" 2>&1)
  if [ "$actual" = "$expected" ]; then
    pass "$message"
  else
    fail "$message — expected '$expected', got '$actual'"
  fi
}

assert_step_with_value() {
  local path="$1"
  local job="$2"
  local step_name="$3"
  local key="$4"
  local expected="$5"
  local message="$6"
  local actual
  actual=$(python3 -c "
import yaml
with open('$path') as f:
    doc = yaml.safe_load(f)
steps = doc.get('jobs', {}).get('$job', {}).get('steps', [])
for step in steps:
    if step.get('name') == '$step_name':
        value = step
        for part in '$key'.split('.'):
            if isinstance(value, dict):
                value = value.get(part)
            else:
                value = None
                break
        print(value if value is not None else 'MISSING')
        raise SystemExit(0)
print('MISSING')
" 2>&1)
  if [ "$actual" = "$expected" ]; then
    pass "$message"
  else
    fail "$message — expected '$expected', got '$actual'"
  fi
}

assert_step_run_contains() {
  local path="$1"
  local job="$2"
  local step_name="$3"
  local needle="$4"
  local message="$5"
  local result
  result=$(python3 -c "
import yaml
with open('$path') as f:
    doc = yaml.safe_load(f)
steps = doc.get('jobs', {}).get('$job', {}).get('steps', [])
for step in steps:
    if step.get('name') == '$step_name':
        run = step.get('run', '')
        print('OK' if '$needle' in run else 'MISSING')
        raise SystemExit(0)
print('MISSING')
" 2>&1)
  if [ "$result" = "OK" ]; then
    pass "$message"
  else
    fail "$message — '$needle' not found"
  fi
}

assert_step_run_not_contains() {
  local path="$1"
  local job="$2"
  local step_name="$3"
  local needle="$4"
  local message="$5"
  local result
  result=$(python3 -c "
import yaml
with open('$path') as f:
    doc = yaml.safe_load(f)
steps = doc.get('jobs', {}).get('$job', {}).get('steps', [])
for step in steps:
    if step.get('name') == '$step_name':
        run = step.get('run', '')
        print('OK' if '$needle' not in run else 'FOUND')
        raise SystemExit(0)
print('MISSING')
" 2>&1)
  if [ "$result" = "OK" ]; then
    pass "$message"
  else
    fail "$message — unexpected '$needle' found"
  fi
}

assert_no_step_named() {
  local path="$1"
  local job="$2"
  local step_name="$3"
  local message="$4"
  local result
  result=$(python3 -c "
import yaml
with open('$path') as f:
    doc = yaml.safe_load(f)
steps = doc.get('jobs', {}).get('$job', {}).get('steps', [])
print('FOUND' if any(step.get('name') == '$step_name' for step in steps) else 'OK')
" 2>&1)
  if [ "$result" = "OK" ]; then
    pass "$message"
  else
    fail "$message — step '$step_name' is present"
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

# ----- release-finalize.yml -----

echo ""
echo "=== Test: .github/workflows/release-finalize.yml ==="

RELEASE_FINALIZE=".github/workflows/release-finalize.yml"

if [ ! -f "$RELEASE_FINALIZE" ]; then
  fail "$RELEASE_FINALIZE does not exist"
else
  assert_yaml_valid "$RELEASE_FINALIZE"
  assert_yaml_has_key "$RELEASE_FINALIZE" "jobs.publish-npm" "release-finalize.yml has 'publish-npm' job"
  assert_yaml_path_equals "$RELEASE_FINALIZE" "jobs.publish-npm.permissions.contents" "read" "release-finalize.yml publish-npm has contents:read"
  assert_yaml_path_equals "$RELEASE_FINALIZE" "jobs.publish-npm.permissions.id-token" "write" "release-finalize.yml publish-npm has id-token:write"
  assert_step_uses "$RELEASE_FINALIZE" "publish-npm" "Setup Node.js" "actions/setup-node@v6" "release-finalize.yml uses setup-node@v6 for publish-npm"
  assert_step_with_value "$RELEASE_FINALIZE" "publish-npm" "Setup Node.js" "with.node-version" "24" "release-finalize.yml publish-npm uses Node 24"
  assert_no_step_named "$RELEASE_FINALIZE" "publish-npm" "Update npm for OIDC support" "release-finalize.yml does not self-upgrade npm in publish-npm"
  assert_step_run_contains "$RELEASE_FINALIZE" "publish-npm" "Publish to npm" "npm publish --access public" "release-finalize.yml publish-npm uses plain npm publish"
  assert_step_run_not_contains "$RELEASE_FINALIZE" "publish-npm" "Publish to npm" "--provenance" "release-finalize.yml publish-npm does not force --provenance"
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
