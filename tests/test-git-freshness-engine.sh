#!/usr/bin/env bash
#
# Regression checks for the shared git-freshness contract introduced by
# branch-freshness-policy Unit 02.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROTOCOL_FILE="$ROOT_DIR/core/protocols/git-freshness.md"

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

assert_file_exists() {
  local path="$1" label="$2"
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label"
  fi
}

assert_contains() {
  local path="$1" needle="$2" label="$3"
  if grep -Fq "$needle" "$path"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

echo "=== git freshness engine ==="
echo ""

echo "--- Protocol contract ---"
assert_file_exists "$PROTOCOL_FILE" "core/protocols/git-freshness.md exists"
assert_contains "$PROTOCOL_FILE" "clone-local runtime state" "protocol names clone-local runtime state explicitly"
assert_contains "$PROTOCOL_FILE" "project-level artifacts" "protocol names project-level artifacts explicitly"
assert_contains "$PROTOCOL_FILE" "optional auditable work artifacts" "protocol names optional auditable work artifacts explicitly"
assert_contains "$PROTOCOL_FILE" "must not depend on symlinked mirrors" "protocol rejects symlink-based artifact assumptions"
assert_contains "$PROTOCOL_FILE" "session.json" "protocol keeps session.json in the local-only runtime set"
assert_contains "$PROTOCOL_FILE" "CONSTITUTION.md" "protocol keeps anchor docs in the project artifact set"
assert_contains "$PROTOCOL_FILE" "recorded work state and resolved roots" "protocol roots helper behavior in resolved state instead of one hardcoded path"

echo ""
TOTAL=$((PASS + FAIL))
echo "RESULT: $PASS passed, $FAIL failed (of $TOTAL tests)"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
