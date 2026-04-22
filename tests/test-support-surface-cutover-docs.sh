#!/usr/bin/env bash
#
# Regression checks for Unit 04 — support-surface cutover.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

AGENTS_DOC="$ROOT_DIR/AGENTS.md"
CLAUDE_DOC="$ROOT_DIR/CLAUDE.md"
ADAPTER_CLAUDE_DOC="$ROOT_DIR/adapters/claude-code/CLAUDE.md"
CODEX_STATUS_CMD="$ROOT_DIR/adapters/codex/commands/sw-status.md"
CODEX_DOCTOR_CMD="$ROOT_DIR/adapters/codex/commands/sw-doctor.md"
CODEX_INIT_CMD="$ROOT_DIR/adapters/codex/commands/sw-init.md"
CODEX_GUARD_CMD="$ROOT_DIR/adapters/codex/commands/sw-guard.md"
OPENCODE_STATUS_CMD="$ROOT_DIR/adapters/opencode/commands/sw-status.md"
OPENCODE_DOCTOR_CMD="$ROOT_DIR/adapters/opencode/commands/sw-doctor.md"
OPENCODE_INIT_CMD="$ROOT_DIR/adapters/opencode/commands/sw-init.md"
OPENCODE_GUARD_CMD="$ROOT_DIR/adapters/opencode/commands/sw-guard.md"
REVIEW_PACKET_PROTOCOL="$ROOT_DIR/core/protocols/review-packet.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
REVIEW_SKILL="$ROOT_DIR/core/skills/sw-review/SKILL.md"
STATUS_SKILL="$ROOT_DIR/core/skills/sw-status/SKILL.md"
DOCTOR_SKILL="$ROOT_DIR/core/skills/sw-doctor/SKILL.md"
INIT_SKILL="$ROOT_DIR/core/skills/sw-init/SKILL.md"
GUARD_SKILL="$ROOT_DIR/core/skills/sw-guard/SKILL.md"
PIVOT_SKILL="$ROOT_DIR/core/skills/sw-pivot/SKILL.md"
LEARN_SKILL="$ROOT_DIR/core/skills/sw-learn/SKILL.md"

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
  local file="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_not_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$label (unexpectedly found: '$needle')"
  else
    pass "$label"
  fi
}

echo "=== support surface cutover docs ==="
echo ""

for file in \
  "$AGENTS_DOC" \
  "$CLAUDE_DOC" \
  "$ADAPTER_CLAUDE_DOC" \
  "$CODEX_STATUS_CMD" \
  "$CODEX_DOCTOR_CMD" \
  "$CODEX_INIT_CMD" \
  "$CODEX_GUARD_CMD" \
  "$OPENCODE_STATUS_CMD" \
  "$OPENCODE_DOCTOR_CMD" \
  "$OPENCODE_INIT_CMD" \
  "$OPENCODE_GUARD_CMD" \
  "$REVIEW_PACKET_PROTOCOL" \
  "$SHIP_SKILL" \
  "$REVIEW_SKILL" \
  "$STATUS_SKILL" \
  "$DOCTOR_SKILL" \
  "$INIT_SKILL" \
  "$GUARD_SKILL" \
  "$PIVOT_SKILL" \
  "$LEARN_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Task 1: ship and review consume the audit packet ---"
assert_contains "$REVIEW_PACKET_PROTOCOL" "reviewer-facing PR body" "review-packet protocol assigns ship as a live consumer"
assert_contains "$REVIEW_PACKET_PROTOCOL" "packet, approvals, and evidence" "review-packet protocol assigns review as a live consumer"
assert_contains "$SHIP_SKILL" "{workDir}/review-packet.md" "sw-ship reads the review packet"
assert_contains "$SHIP_SKILL" "inline reviewer-usable approval lineage" "sw-ship inlines reviewer summary in clone-local mode"
assert_contains "$SHIP_SKILL" "tracked work-artifact mode" "sw-ship distinguishes tracked reviewer surfaces"
assert_contains "$REVIEW_SKILL" "Resolve the associated work from PR context" "sw-review resolves work from PR metadata"
assert_contains "$REVIEW_SKILL" "review-packet.md" "sw-review reads the review packet when work is available"
assert_contains "$REVIEW_SKILL" "approvals.md" "sw-review reads approval lineage when work is available"
assert_contains "$REVIEW_SKILL" "diff-only fallback" "sw-review documents fallback when no work match is available"
assert_contains "$REVIEW_SKILL" "never writes Specwright project or runtime state" "sw-review keeps Specwright state read-only"
assert_not_contains "$REVIEW_SKILL" "No writes to \`.specwright/\`." "sw-review no longer references legacy single-root writes"

echo ""
echo "--- Task 2: audit visibility surfaces ---"
assert_contains "$AGENTS_DOC" "13 checks, repair hints." "AGENTS advertises the current sw-doctor check count"
assert_contains "$AGENTS_DOC" "tracked project artifacts (\`projectArtifactsRoot\`)" "AGENTS documents tracked project artifacts explicitly"
assert_contains "$CLAUDE_DOC" "{projectArtifactsRoot}/CONSTITUTION.md" "CLAUDE uses projectArtifactsRoot for anchor docs"
assert_contains "$CLAUDE_DOC" "workArtifactsRoot" "CLAUDE documents configurable auditable work artifacts"
assert_contains "$ADAPTER_CLAUDE_DOC" "{projectArtifactsRoot}/CONSTITUTION.md" "adapter CLAUDE uses projectArtifactsRoot for anchor docs"
assert_contains "$ADAPTER_CLAUDE_DOC" "workArtifactsRoot" "adapter CLAUDE documents configurable auditable work artifacts"
assert_contains "$CLAUDE_DOC" "\`/sw-pivot\` is research-backed rebaselining for work in \`planning\`, \`building\`, or \`verifying\`." "CLAUDE documents the broadened pivot entry states"
assert_contains "$CLAUDE_DOC" "use \`/sw-design <changes>\` instead of forcing \`/sw-pivot\`." "CLAUDE routes shipped-scope rewrites back to sw-design"
assert_contains "$ADAPTER_CLAUDE_DOC" "\`/sw-pivot\` is research-backed rebaselining for work in \`planning\`, \`building\`, or \`verifying\`." "adapter CLAUDE documents the broadened pivot entry states"
assert_contains "$ADAPTER_CLAUDE_DOC" "use \`/sw-design <changes>\` instead of forcing \`/sw-pivot\`." "adapter CLAUDE routes shipped-scope rewrites back to sw-design"
assert_contains "$STATUS_SKILL" "\`projectArtifactsRoot\`, \`repoStateRoot\`" "sw-status prints all logical roots"
assert_contains "$STATUS_SKILL" "approval freshness" "sw-status surfaces approval freshness"
assert_contains "$STATUS_SKILL" "review-packet presence" "sw-status surfaces review-packet presence"
assert_contains "$DOCTOR_SKILL" "{projectArtifactsRoot}/config.json" "sw-doctor reads tracked project config"
assert_contains "$DOCTOR_SKILL" "approval freshness for the selected unit" "sw-doctor validates approval freshness explicitly"
assert_contains "$DOCTOR_SKILL" "review-packet presence for the selected unit" "sw-doctor validates review-packet presence explicitly"
assert_contains "$INIT_SKILL" "{projectArtifactsRoot}/config.json" "sw-init writes tracked project config under projectArtifactsRoot"
assert_contains "$INIT_SKILL" "shared across developers and agent sessions via" "sw-init explains the shared project-artifact experience"
assert_contains "$INIT_SKILL" "runtime session state stays local to each clone or worktree" "sw-init preserves local runtime state"
assert_contains "$INIT_SKILL" "{projectArtifactsRoot}/LANDSCAPE.md" "sw-init writes LANDSCAPE under projectArtifactsRoot"
assert_contains "$INIT_SKILL" "{projectArtifactsRoot}/TESTING.md" "sw-init writes TESTING under projectArtifactsRoot"
assert_contains "$INIT_SKILL" "{projectArtifactsRoot}/BACKLOG.md" "sw-init writes markdown backlog under projectArtifactsRoot"
assert_contains "$GUARD_SKILL" "shared project-level" "sw-guard treats config as a shared project policy surface"
assert_contains "$GUARD_SKILL" "Git-admin session state remains local-only" "sw-guard preserves runtime-local session state"
assert_contains "$AGENTS_DOC" ".specwright-local/" "AGENTS names project-visible runtime roots"
assert_contains "$AGENTS_DOC" "git-admin" "AGENTS keeps git-admin as compatibility mode"
assert_contains "$AGENTS_DOC" "/sw-adopt" "AGENTS points same-work adoption to /sw-adopt"
assert_contains "$AGENTS_DOC" "/sw-status" "AGENTS points runtime inspection to /sw-status"
assert_contains "$CLAUDE_DOC" ".specwright-local/" "CLAUDE names project-visible runtime roots"
assert_contains "$CLAUDE_DOC" "git-admin" "CLAUDE keeps git-admin as compatibility mode"
assert_contains "$CLAUDE_DOC" "/sw-adopt" "CLAUDE points same-work adoption to /sw-adopt"
assert_contains "$CLAUDE_DOC" "/sw-status" "CLAUDE points runtime inspection to /sw-status"
assert_contains "$ADAPTER_CLAUDE_DOC" ".specwright-local/" "adapter CLAUDE names project-visible runtime roots"
assert_contains "$ADAPTER_CLAUDE_DOC" "git-admin" "adapter CLAUDE keeps git-admin as compatibility mode"
assert_contains "$ADAPTER_CLAUDE_DOC" "/sw-adopt" "adapter CLAUDE points same-work adoption to /sw-adopt"
assert_contains "$ADAPTER_CLAUDE_DOC" "/sw-status" "adapter CLAUDE points runtime inspection to /sw-status"
assert_contains "$STATUS_SKILL" ".specwright-local/" "sw-status names project-visible runtime roots"
assert_contains "$STATUS_SKILL" "git-admin" "sw-status keeps git-admin as compatibility mode"
assert_contains "$STATUS_SKILL" "/sw-adopt" "sw-status keeps same-work adoption explicit"
assert_contains "$DOCTOR_SKILL" ".specwright-local/" "sw-doctor names project-visible runtime roots"
assert_contains "$DOCTOR_SKILL" "git-admin" "sw-doctor keeps git-admin as compatibility mode"
assert_contains "$DOCTOR_SKILL" "/sw-adopt" "sw-doctor routes live ownership conflicts to /sw-adopt"
assert_contains "$INIT_SKILL" ".specwright-local/" "sw-init recommends project-visible runtime roots"
assert_contains "$INIT_SKILL" "git-admin" "sw-init keeps git-admin as compatibility mode"
assert_contains "$INIT_SKILL" "/sw-status" "sw-init points the operator to /sw-status next"
assert_contains "$GUARD_SKILL" ".specwright-local/" "sw-guard names project-visible runtime roots"
assert_contains "$GUARD_SKILL" "git-admin" "sw-guard keeps git-admin as compatibility mode"
assert_contains "$GUARD_SKILL" "/sw-adopt" "sw-guard keeps same-work adoption explicit"
assert_contains "$CODEX_STATUS_CMD" ".specwright-local/" "codex sw-status command names project-visible runtime roots"
assert_contains "$CODEX_STATUS_CMD" "git-admin" "codex sw-status command keeps git-admin as compatibility mode"
assert_contains "$CODEX_STATUS_CMD" "/sw-adopt" "codex sw-status command points same-work takeover to /sw-adopt"
assert_contains "$CODEX_DOCTOR_CMD" ".specwright-local/" "codex sw-doctor command names project-visible runtime roots"
assert_contains "$CODEX_DOCTOR_CMD" "git-admin" "codex sw-doctor command keeps git-admin as compatibility mode"
assert_contains "$CODEX_DOCTOR_CMD" "/sw-status --repair" "codex sw-doctor command points repair to /sw-status --repair"
assert_contains "$CODEX_INIT_CMD" ".specwright-local/" "codex sw-init command names project-visible runtime roots"
assert_contains "$CODEX_INIT_CMD" "git-admin" "codex sw-init command keeps git-admin as compatibility mode"
assert_contains "$CODEX_INIT_CMD" "/sw-status" "codex sw-init command points the operator to /sw-status"
assert_contains "$CODEX_GUARD_CMD" ".specwright-local/" "codex sw-guard command names project-visible runtime roots"
assert_contains "$CODEX_GUARD_CMD" "git-admin" "codex sw-guard command keeps git-admin as compatibility mode"
assert_contains "$CODEX_GUARD_CMD" "/sw-adopt" "codex sw-guard command keeps same-work adoption explicit"
assert_contains "$OPENCODE_STATUS_CMD" ".specwright-local/" "opencode sw-status command names project-visible runtime roots"
assert_contains "$OPENCODE_STATUS_CMD" "git-admin" "opencode sw-status command keeps git-admin as compatibility mode"
assert_contains "$OPENCODE_STATUS_CMD" "/sw-adopt" "opencode sw-status command points same-work takeover to /sw-adopt"
assert_contains "$OPENCODE_DOCTOR_CMD" ".specwright-local/" "opencode sw-doctor command names project-visible runtime roots"
assert_contains "$OPENCODE_DOCTOR_CMD" "git-admin" "opencode sw-doctor command keeps git-admin as compatibility mode"
assert_contains "$OPENCODE_DOCTOR_CMD" "/sw-status --repair" "opencode sw-doctor command points repair to /sw-status --repair"
assert_contains "$OPENCODE_INIT_CMD" ".specwright-local/" "opencode sw-init command names project-visible runtime roots"
assert_contains "$OPENCODE_INIT_CMD" "git-admin" "opencode sw-init command keeps git-admin as compatibility mode"
assert_contains "$OPENCODE_INIT_CMD" "/sw-status" "opencode sw-init command points the operator to /sw-status"
assert_contains "$OPENCODE_GUARD_CMD" ".specwright-local/" "opencode sw-guard command names project-visible runtime roots"
assert_contains "$OPENCODE_GUARD_CMD" "git-admin" "opencode sw-guard command keeps git-admin as compatibility mode"
assert_contains "$OPENCODE_GUARD_CMD" "/sw-adopt" "opencode sw-guard command keeps same-work adoption explicit"
assert_not_contains "$CLAUDE_DOC" "{repoStateRoot}/CONSTITUTION.md" "CLAUDE no longer points anchor docs at repoStateRoot"
assert_not_contains "$ADAPTER_CLAUDE_DOC" "{repoStateRoot}/CONSTITUTION.md" "adapter CLAUDE no longer points anchor docs at repoStateRoot"
assert_not_contains "$INIT_SKILL" ".specwright/LANDSCAPE.md" "sw-init removes legacy LANDSCAPE path"
assert_not_contains "$INIT_SKILL" ".specwright/TESTING.md" "sw-init removes legacy TESTING path"
assert_not_contains "$INIT_SKILL" ".specwright/BACKLOG.md" "sw-init removes legacy BACKLOG path"
assert_not_contains "$INIT_SKILL" ".specwright/ already exists" "sw-init failure modes no longer hardcode the legacy root"

echo ""
echo "--- Task 3: pivot and learn preserve lineage ---"
assert_contains "$PIVOT_SKILL" "approvals.md" "sw-pivot reads the approval ledger"
assert_contains "$PIVOT_SKILL" "adapters/shared/specwright-approvals.mjs" "sw-pivot names the approval helper implementation"
assert_contains "$PIVOT_SKILL" "approval lineage becomes stale" "sw-pivot marks approval lineage stale after plan changes"
assert_contains "$PIVOT_SKILL" "Never fabricate a replacement" "sw-pivot refuses to invent replacement approval"
assert_contains "$LEARN_SKILL" "{workDir}/implementation-rationale.md" "sw-learn reads implementation rationale"
assert_contains "$LEARN_SKILL" "{workDir}/review-packet.md" "sw-learn reads the review packet"
assert_contains "$LEARN_SKILL" "{workArtifactsRoot}/{selectedWork.id}/approvals.md" "sw-learn reads approval lineage"
assert_contains "$LEARN_SKILL" "{projectArtifactsRoot}/CONSTITUTION.md" "sw-learn uses tracked constitution path"
assert_contains "$LEARN_SKILL" "{projectArtifactsRoot}/learnings/{work-id}.json" "sw-learn writes learnings to tracked project artifacts"
assert_contains "$LEARN_SKILL" "{projectArtifactsRoot}/patterns.md" "sw-learn promotes patterns on the tracked project surface"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
emit_coverage_marker "support-surface.publication-mode-cutover"
emit_coverage_marker "support-surface.runtime-root-adoption-cutover"
