#!/usr/bin/env bash
#
# Regression checks for the config/visibility surfaces introduced by
# branch-freshness-policy Unit 04.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"
INIT_SKILL="$ROOT_DIR/core/skills/sw-init/SKILL.md"
GUARD_SKILL="$ROOT_DIR/core/skills/sw-guard/SKILL.md"
DOCTOR_SKILL="$ROOT_DIR/core/skills/sw-doctor/SKILL.md"
STATUS_SKILL="$ROOT_DIR/core/skills/sw-status/SKILL.md"
SYNC_SKILL="$ROOT_DIR/core/skills/sw-sync/SKILL.md"

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq "$needle" "$file"; then
    pass "$label"
  else
    fail "$label"
  fi
}

echo "=== config validation and visibility docs ==="
echo ""

for file in "$INIT_SKILL" "$GUARD_SKILL" "$DOCTOR_SKILL" "$STATUS_SKILL" "$SYNC_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
# These literal-match sentinels intentionally guard the published support
# surface, but use short phrases so punctuation-only rewrites do not cause
# false failures.
echo "--- Task 1: init and guard configuration surfaces ---"
assert_contains "$INIT_SKILL" "target-role defaults and freshness checkpoints" "sw-init confirms target defaults and checkpoint policy together"
assert_contains "$INIT_SKILL" "optional auditable work artifacts" "sw-init asks for optional work-artifact publication mode"
assert_contains "$INIT_SKILL" "runtime session state stays local-only" "sw-init preserves the storage boundary split"
assert_contains "$GUARD_SKILL" "target-role defaults, freshness checkpoints" "sw-guard keeps the Git policy surface explicit"
assert_contains "$GUARD_SKILL" "separately from clone-local runtime state" "sw-guard distinguishes publication policy from runtime-local state"

echo ""
echo "--- Task 2: doctor and status visibility surfaces ---"
assert_contains "$DOCTOR_SKILL" "provider-aware configuration surface" "sw-doctor rejects queue mode without provider-aware config"
assert_contains "$DOCTOR_SKILL" "work-artifact publication mode" "sw-doctor validates artifact publication mode safely"
assert_contains "$DOCTOR_SKILL" "CONFIG_MISMATCH findings must name the offending config key" "sw-doctor makes config remediation explicit"
assert_contains "$STATUS_SKILL" "target branch and latest freshness state" "sw-status surfaces target branch plus freshness state"
assert_contains "$STATUS_SKILL" "work-artifact publication mode when present" "sw-status surfaces publication mode when present"
assert_contains "$STATUS_SKILL" "approval freshness reason" "sw-status surfaces the approval freshness reason explicitly"
assert_contains "$STATUS_SKILL" "latest closeout or review-packet availability" "sw-status surfaces the latest closeout or review-packet availability explicitly"

echo ""
echo "--- Task 3: protocol anchor and sync boundaries ---"
assert_contains "$GIT_PROTOCOL" '"workArtifacts": {' "git protocol adds a canonical workArtifacts config surface"
assert_contains "$GIT_PROTOCOL" '"mode": "clone-local"' "git protocol names clone-local publication mode"
assert_contains "$GIT_PROTOCOL" '"trackedRoot": null' "git protocol names the tracked artifact root field"
assert_contains "$SYNC_SKILL" "report stale active works against" "sw-sync can report stale active works"
assert_contains "$SYNC_SKILL" "reconcile-or-ship decisions away from the lifecycle skills" "sw-sync stays advisory on reconcile and ship decisions"
assert_contains "$SYNC_SKILL" "protocols/git-freshness.md" "sw-sync references the shared freshness protocol"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
