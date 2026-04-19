#!/usr/bin/env bash
#
# Regression checks for WU-03 Task 3 — verify mutation proof surfaces.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE_VERIFY="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
ADAPTER_CLAUDE="$ROOT_DIR/adapters/claude-code/CLAUDE.md"
DIST_VERIFY="$ROOT_DIR/dist/claude-code/skills/sw-verify/SKILL.md"
DIST_CLAUDE="$ROOT_DIR/dist/claude-code/CLAUDE.md"
DIST_GATE_TESTS="$ROOT_DIR/dist/claude-code/skills/gate-tests/SKILL.md"
DIST_TESTER="$ROOT_DIR/dist/claude-code/agents/specwright-tester.md"

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

emit_coverage_marker() {
  printf 'COVERAGE: %s\n' "$1"
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local label="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

echo "=== verify mutation proof surfaces ==="
echo ""

for file in \
  "$SOURCE_VERIFY" \
  "$ADAPTER_CLAUDE" \
  "$DIST_VERIFY" \
  "$DIST_CLAUDE" \
  "$DIST_GATE_TESTS" \
  "$DIST_TESTER"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Source verify surface ---"
assert_contains "$SOURCE_VERIFY" "--accept-mutant {id}" "source sw-verify documents accepted-mutant CLI"
assert_contains "$SOURCE_VERIFY" "T1" "source sw-verify names T1"
assert_contains "$SOURCE_VERIFY" "T2" "source sw-verify names T2"
assert_contains "$SOURCE_VERIFY" "T3" "source sw-verify names T3"
assert_contains "$SOURCE_VERIFY" "silent skip" "source sw-verify rejects silent skip behavior"

echo ""
echo "--- Packaged Claude Code docs ---"
assert_contains "$ADAPTER_CLAUDE" "Tiered mutation analysis stays inside gate-tests and uses specwright-tester as the companion surface. It is not a separate mutation gate." "adapter CLAUDE keeps gate-tests mutation wording"
assert_contains "$DIST_CLAUDE" "Tiered mutation analysis stays inside gate-tests and uses specwright-tester as the companion surface. It is not a separate mutation gate." "dist CLAUDE keeps gate-tests mutation wording"

echo ""
echo "--- Built mutation surfaces ---"
assert_contains "$DIST_VERIFY" "--accept-mutant {id}" "dist sw-verify preserves accepted-mutant CLI"
assert_contains "$DIST_VERIFY" "T1" "dist sw-verify preserves T1"
assert_contains "$DIST_VERIFY" "T2" "dist sw-verify preserves T2"
assert_contains "$DIST_VERIFY" "T3" "dist sw-verify preserves T3"
assert_contains "$DIST_VERIFY" "silent skip" "dist sw-verify preserves no-silent-skip wording"
assert_contains "$DIST_GATE_TESTS" "accepted-mutant lineage" "dist gate-tests preserves accepted-mutant lineage wording"
assert_contains "$DIST_GATE_TESTS" "silent skip" "dist gate-tests preserves no-silent-skip wording"
assert_contains "$DIST_TESTER" "silently skipping mutation review" "dist tester preserves T3 fallback wording"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "verify-mutation.proof-surfaces"
