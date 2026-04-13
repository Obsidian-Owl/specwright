#!/usr/bin/env bash
# shellcheck disable=SC2016
#
# Tests for Unit 04 — multi-worktree pipeline skill cutover.
#
# This suite is extended task-by-task during the build. The opening assertions
# cover Task 1: sw-design and sw-plan must describe session-selected work and
# worktree-local attachment semantics instead of repo-global singleton state.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

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
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -qE "$pattern" "$path" 2>/dev/null; then
    pass "$message"
  else
    fail "$message — pattern not found: $pattern"
  fi
}

cd "$ROOT_DIR" || exit 1

echo "=== Unit 04: multi-worktree pipeline skill docs ==="
echo ""

echo "--- Task 1: sw-design and sw-plan session-selected semantics ---"
assert_contains "core/skills/sw-design/SKILL.md" \
  'session\.json|attachedWorkId|current worktree session' \
  "sw-design references current worktree session attachment"

assert_contains "core/skills/sw-design/SKILL.md" \
  'without clearing unrelated active works|other top-level worktrees|other active works remain' \
  "sw-design preserves unrelated active works in other top-level worktrees"

assert_contains "core/skills/sw-plan/SKILL.md" \
  'session-selected work|selected work|attached work' \
  "sw-plan targets the session-selected work"

assert_contains "core/skills/sw-plan/SKILL.md" \
  'repoStateRoot|worktreeStateRoot|session\.json' \
  "sw-plan describes logical roots or session-local work selection"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
