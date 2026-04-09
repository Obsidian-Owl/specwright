#!/usr/bin/env bash
#
# Tests for Unit 06 — flatten sw-build.
#
# Verifies the skill body is compressed, the per-task loop is back to
# RED -> GREEN -> REFACTOR, and the end-of-unit after-build phase carries
# the optional integration/regression work.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_FILE="$ROOT_DIR/core/skills/sw-build/SKILL.md"

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

extract_body() {
  local file="$1"
  local closing_line
  closing_line=$(tail -n +2 "$file" | grep -n '^---$' | head -n 1 | cut -d: -f1)
  if [ -z "$closing_line" ] || [ "$closing_line" -lt 1 ]; then
    return 1
  fi
  tail -n +"$((closing_line + 2))" "$file"
}

extract_block() {
  local body="$1"
  local pattern="$2"
  echo "$body" | awk -v pat="$pattern" '
    BEGIN { found=0 }
    $0 ~ "\\*\\*" pat && !found { found=1; print; next }
    found && /^\*\*[A-Z]/ { exit }
    found { print }
  '
}

echo "=== Unit 06: sw-build flattening ==="
echo ""

if [ ! -f "$SKILL_FILE" ]; then
  fail "core/skills/sw-build/SKILL.md exists"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
fi

BODY=$(extract_body "$SKILL_FILE") || {
  fail "SKILL.md has body content after frontmatter"
  echo ""
  echo "RESULT: $PASS passed, $FAIL failed"
  exit 1
}

BODY_LINES=$(printf "%s" "$BODY" | wc -l | tr -d ' ')

echo "=== AC-1: skill body line count ==="
if [ "$BODY_LINES" -le 80 ]; then
  pass "sw-build body is <= 80 lines ($BODY_LINES)"
else
  fail "sw-build body is <= 80 lines ($BODY_LINES)"
fi

echo ""
echo "=== AC-2: four core concerns remain ==="
for heading in "Stage boundary" "Branch setup" "TDD cycle" "Commits"; do
  if printf "%s" "$BODY" | grep -q "$heading"; then
    pass "body contains '$heading'"
  else
    fail "body contains '$heading'"
  fi
done

echo ""
echo "=== AC-3: relocations removed from sw-build body ==="
for removed in "Repo map generation" "Context envelope" "Per-task micro-check" "Inner-loop validation"; do
  if printf "%s" "$BODY" | grep -q "$removed"; then
    fail "body omits '$removed'"
  else
    pass "body omits '$removed'"
  fi
done

echo ""
echo "=== AC-4: TDD loop is RED -> GREEN -> REFACTOR ==="
TDD_BLOCK=$(extract_block "$BODY" "TDD cycle")
if printf "%s" "$TDD_BLOCK" | grep -q "RED" && \
   printf "%s" "$TDD_BLOCK" | grep -q "GREEN" && \
   printf "%s" "$TDD_BLOCK" | grep -q "REFACTOR"; then
  pass "TDD block contains RED, GREEN, and REFACTOR"
else
  fail "TDD block contains RED, GREEN, and REFACTOR"
fi

if printf "%s" "$TDD_BLOCK" | grep -q "specwright-tester" && \
   printf "%s" "$TDD_BLOCK" | grep -q "specwright-executor"; then
  pass "TDD block delegates to tester and executor"
else
  fail "TDD block delegates to tester and executor"
fi

if printf "%s" "$TDD_BLOCK" | grep -q "INTEGRATION\|REGRESSION CHECK"; then
  fail "TDD block omits per-task integration and regression phases"
else
  pass "TDD block omits per-task integration and regression phases"
fi

echo ""
echo "=== AC-7: after-build phase carries end-of-unit validation ==="
AFTER_BLOCK=$(extract_block "$BODY" "After-build")
if [ -n "$AFTER_BLOCK" ]; then
  pass "After-build block exists"
else
  fail "After-build block exists"
fi

for term in "post-build review" "commands.test" "commands.test:integration" "build-fixer"; do
  if printf "%s" "$AFTER_BLOCK" | grep -q "$term"; then
    pass "After-build mentions '$term'"
  else
    fail "After-build mentions '$term'"
  fi
done

if printf "%s" "$AFTER_BLOCK" | grep -qi "once per unit\|end-of-unit"; then
  pass "After-build states that integration runs once per unit"
else
  fail "After-build states that integration runs once per unit"
fi

if printf "%s" "$AFTER_BLOCK" | grep -qi "max 2\|2 attempts"; then
  pass "After-build preserves the max-2 build-fixer rule"
else
  fail "After-build preserves the max-2 build-fixer rule"
fi

if printf "%s" "$AFTER_BLOCK" | grep -qi "interactive" && \
   printf "%s" "$AFTER_BLOCK" | grep -qi "headless"; then
  pass "After-build distinguishes interactive and headless handling"
else
  fail "After-build distinguishes interactive and headless handling"
fi

echo ""
echo "=== Supporting constraints preserved ==="
for heading in "Mid-build checks" "Task tracking" "Parallel execution"; do
  if printf "%s" "$BODY" | grep -q "$heading"; then
    pass "body contains '$heading'"
  else
    fail "body contains '$heading'"
  fi
done

if grep -q "stage-report.md" "$SKILL_FILE" && grep -q "/sw-verify" "$SKILL_FILE"; then
  pass "handoff still points at stage-report.md and /sw-verify"
else
  fail "handoff still points at stage-report.md and /sw-verify"
fi

echo ""
echo "==========================================="
echo "RESULT: $PASS passed, $FAIL failed"
echo "==========================================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
