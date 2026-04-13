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
echo "--- Task 2: sw-build and sw-pivot per-work ownership semantics ---"
assert_contains "core/skills/sw-build/SKILL.md" \
  'session-selected work|selected work|attached work' \
  "sw-build resolves the selected work from the current worktree session"

assert_contains "core/skills/sw-build/SKILL.md" \
  'per-work lock|selected work.?s `?workflow\.json`|mutate only the selected work' \
  "sw-build describes per-work workflow and lock semantics"

assert_contains "core/skills/sw-build/SKILL.md" \
  'adopt/takeover|already-owned active work|other live top-level worktree' \
  "sw-build stops with adopt/takeover guidance for already-owned work"

assert_contains "core/skills/sw-pivot/SKILL.md" \
  'selected work|attached work|session\.json' \
  "sw-pivot operates on the selected work for this worktree"

assert_contains "core/skills/sw-pivot/SKILL.md" \
  'remaining tasks on the selected work|selected work.?s `?workflow\.json`|per-work' \
  "sw-pivot describes remaining-task updates on the selected work"

assert_contains "core/skills/sw-pivot/SKILL.md" \
  'adopt/takeover|other live top-level worktree|already-owned active work' \
  "sw-pivot documents adopt/takeover guidance for ownership conflicts"

echo ""
echo "--- Task 3: verify, ship, learn, and gate docs use selected work roots ---"
assert_contains "core/skills/sw-verify/SKILL.md" \
  'selected work|session\.json|current worktree session' \
  "sw-verify references the selected work for this worktree"

assert_contains "core/skills/sw-verify/SKILL.md" \
  'selected work.?s `?workflow\.json`|selected work.?s evidence directory|workDir' \
  "sw-verify records evidence and gate updates on the selected work"

assert_contains "core/skills/sw-ship/SKILL.md" \
  'selected work|session\.json|attached work' \
  "sw-ship operates on the selected work"

assert_contains "core/skills/sw-ship/SKILL.md" \
  'adopt/takeover|other live top-level worktree|owned elsewhere' \
  "sw-ship stops with adopt/takeover guidance for ownership conflicts"

assert_contains "core/skills/sw-learn/SKILL.md" \
  'selected work|session\.json|attached work' \
  "sw-learn reads the selected work and current session"

assert_contains "core/skills/sw-learn/SKILL.md" \
  'clear the current worktree session attachment|attachedWorkId|preserve the work record' \
  "sw-learn cleanup clears the worktree attachment instead of deleting repo-wide history"

for gate_file in \
  "core/skills/gate-build/SKILL.md" \
  "core/skills/gate-tests/SKILL.md" \
  "core/skills/gate-security/SKILL.md" \
  "core/skills/gate-wiring/SKILL.md" \
  "core/skills/gate-semantic/SKILL.md" \
  "core/skills/gate-spec/SKILL.md"; do
  assert_contains "$gate_file" \
    'selected work.?s `?workflow\.json`|{repoStateRoot}/work/{selectedWork\.id}/workflow\.json' \
    "$gate_file writes gate status to the selected work workflow"

  assert_contains "$gate_file" \
    '{workDir}/evidence/|selected work.?s evidence' \
    "$gate_file uses the selected work evidence root"
done

echo ""
echo "RESULT: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi

exit 0
