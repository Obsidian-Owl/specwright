#!/usr/bin/env bash
#
# Regression checks for the config/visibility surfaces introduced by
# branch-freshness-policy Unit 04.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

INIT_SKILL="$ROOT_DIR/core/skills/sw-init/SKILL.md"
GUARD_SKILL="$ROOT_DIR/core/skills/sw-guard/SKILL.md"

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

for file in "$INIT_SKILL" "$GUARD_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Task 1: init and guard configuration surfaces ---"
assert_contains "$INIT_SKILL" "target-role defaults and freshness checkpoints" "sw-init confirms target defaults and checkpoint policy together"
assert_contains "$INIT_SKILL" "optional auditable work artifacts stay clone-local or are published under a tracked work-artifact root" "sw-init asks for optional work-artifact publication mode"
assert_contains "$INIT_SKILL" "Project-level anchor docs remain project artifacts and runtime session state stays local-only" "sw-init preserves the storage boundary split"
assert_contains "$GUARD_SKILL" "target-role defaults, freshness checkpoints, and any optional work-artifact publication mode" "sw-guard keeps the Git policy surface explicit"
assert_contains "$GUARD_SKILL" "separately from clone-local runtime state" "sw-guard distinguishes publication policy from runtime-local state"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
