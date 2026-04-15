#!/usr/bin/env bash
#
# Regression checks for the audit-chain root model introduced by
# agentic-audit-chain Unit 01.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=tests/test-lib.sh
# shellcheck disable=SC1091
. "$SCRIPT_DIR/test-lib.sh"

CONTEXT_PROTOCOL="$ROOT_DIR/core/protocols/context.md"
STATE_PROTOCOL="$ROOT_DIR/core/protocols/state.md"
DECISION_PROTOCOL="$ROOT_DIR/core/protocols/decision.md"
GIT_PROTOCOL="$ROOT_DIR/core/protocols/git.md"
GIT_FRESHNESS_PROTOCOL="$ROOT_DIR/core/protocols/git-freshness.md"
DESIGN_SKILL="$ROOT_DIR/core/skills/sw-design/SKILL.md"
PLAN_SKILL="$ROOT_DIR/core/skills/sw-plan/SKILL.md"
BUILD_SKILL="$ROOT_DIR/core/skills/sw-build/SKILL.md"
VERIFY_SKILL="$ROOT_DIR/core/skills/sw-verify/SKILL.md"
SHIP_SKILL="$ROOT_DIR/core/skills/sw-ship/SKILL.md"
STATE_PATHS_MODULE="$ROOT_DIR/adapters/shared/specwright-state-paths.mjs"
TEST_TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TEST_TMPDIR"' EXIT

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
  local path="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$path"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

assert_not_contains() {
  local path="$1" needle="$2" label="$3"
  if grep -Fq -- "$needle" "$path"; then
    fail "$label (found unexpected: '$needle')"
  else
    pass "$label"
  fi
}

assert_output_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -Fq -- "$needle"; then
    pass "$label"
  else
    fail "$label (not found: '$needle')"
  fi
}

git_nested_prepare || exit 1

repo_state_root() {
  printf '%s/specwright\n' "$(git_common_dir "$1")"
}

worktree_state_root() {
  printf '%s/specwright\n' "$(git_dir "$1")"
}

fresh_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

write_project_config() {
  local dir="$1"
  local mode="${2:-clone-local}"
  local tracked_root="${3:-}"
  local tracked_root_json="null"

  mkdir -p "$dir/.specwright"
  if [ "$mode" = "tracked" ]; then
    tracked_root_json="\"$tracked_root\""
  fi

  cat > "$dir/.specwright/config.json" <<EOF
{
  "version": "2.0",
  "git": {
    "targets": {
      "defaultRole": "integration",
      "roles": {
        "integration": { "branch": "main" }
      }
    },
    "workArtifacts": {
      "mode": "$mode",
      "trackedRoot": $tracked_root_json
    }
  }
}
EOF
}

write_runtime_work() {
  local dir="$1"
  local work_id="$2"
  local work_dir="${3:-work/$work_id}"
  local branch="${4:-$(git_nested -C "$dir" branch --show-current)}"
  local runtime_root worktree_root

  runtime_root="$(repo_state_root "$dir")"
  worktree_root="$(worktree_state_root "$dir")"
  mkdir -p "$runtime_root/work/$work_id" "$worktree_root"

  cat > "$runtime_root/work/$work_id/workflow.json" <<EOF
{
  "version": "3.0",
  "id": "$work_id",
  "status": "building",
  "workDir": "$work_dir",
  "unitId": "unit-$work_id",
  "tasksCompleted": [],
  "tasksTotal": 3,
  "currentTask": "task-1",
  "branch": "$branch"
}
EOF

  cat > "$worktree_root/session.json" <<EOF
{
  "version": "3.0",
  "worktreeId": "test-worktree",
  "worktreePath": "$(cd "$dir" && pwd -P)",
  "branch": "$branch",
  "attachedWorkId": "$work_id",
  "mode": "top-level",
  "lastSeenAt": "$(fresh_timestamp)"
}
EOF
}

inspect_state_json() {
  local dir="$1"
  (
    cd "$dir" &&
    STATE_PATHS_MODULE="$STATE_PATHS_MODULE" node --input-type=module <<'EOF'
const { resolveSpecwrightRoots, loadSpecwrightState, normalizeActiveWork } = await import(process.env.STATE_PATHS_MODULE);

const roots = resolveSpecwrightRoots();
const state = loadSpecwrightState();
const work = normalizeActiveWork(state);

process.stdout.write(JSON.stringify({
  roots: roots.ok ? {
    projectArtifactsRoot: roots.projectArtifactsRoot,
    repoStateRoot: roots.repoStateRoot,
    worktreeStateRoot: roots.worktreeStateRoot,
    workArtifactsRoot: roots.workArtifactsRoot
  } : roots,
  layout: state.layout,
  sharedConfigPath: state.sharedConfigPath ?? null,
  projectConfigPath: state.projectConfigPath ?? null,
  workflowPath: state.workflowPath ?? null,
  workDirPath: work?.workDirPath ?? null,
  specPath: work?.specPath ?? null,
  planPath: work?.planPath ?? null,
  artifactsRoot: work?.artifactsRoot ?? null
}));
EOF
  )
}

echo "=== audit-chain root model ==="
echo ""

for file in \
  "$CONTEXT_PROTOCOL" \
  "$STATE_PROTOCOL" \
  "$DECISION_PROTOCOL" \
  "$GIT_PROTOCOL" \
  "$GIT_FRESHNESS_PROTOCOL" \
  "$DESIGN_SKILL" \
  "$PLAN_SKILL" \
  "$BUILD_SKILL" \
  "$VERIFY_SKILL" \
  "$SHIP_SKILL"; do
  if [ -f "$file" ]; then
    pass "exists: ${file#"$ROOT_DIR"/}"
  else
    fail "exists: ${file#"$ROOT_DIR"/}"
  fi
done

echo ""
echo "--- Protocol root split ---"
assert_contains "$CONTEXT_PROTOCOL" "\`projectArtifactsRoot\`" "context protocol defines projectArtifactsRoot"
assert_contains "$CONTEXT_PROTOCOL" "\`workArtifactsRoot\`" "context protocol defines workArtifactsRoot"
assert_contains "$CONTEXT_PROTOCOL" '{projectArtifactsRoot}/config.json' "context protocol loads tracked config from projectArtifactsRoot"
assert_contains "$CONTEXT_PROTOCOL" '{workArtifactsRoot}/{workId}' "context protocol loads auditable work artifacts from workArtifactsRoot"
assert_contains "$STATE_PROTOCOL" "work and unit \`stage-report.md\` files" "state protocol treats stage-report files as runtime-only"
assert_contains "$STATE_PROTOCOL" 'relative path under workArtifactsRoot/{workId}' "state protocol moves workDir under workArtifactsRoot"
assert_contains "$DECISION_PROTOCOL" 'Artifacts: {stageReportPath}' "decision protocol parameterizes stage report handoff path"
assert_contains "$GIT_PROTOCOL" "\`workArtifactsRoot = {repoStateRoot}/work\`" "git protocol maps clone-local mode to repoStateRoot/work"
assert_contains "$GIT_PROTOCOL" "\`projectArtifactsRoot\`" "git protocol keeps project artifacts on the tracked root"
assert_contains "$GIT_FRESHNESS_PROTOCOL" "\`implementation-rationale.md\`" "git-freshness protocol names implementation rationale as auditable"
assert_contains "$GIT_FRESHNESS_PROTOCOL" "\`review-packet.md\`" "git-freshness protocol names review packet as auditable"
assert_not_contains "$GIT_FRESHNESS_PROTOCOL" "- \`stage-report.md\`" "git-freshness protocol no longer treats stage-report.md as auditable"
assert_contains "$DESIGN_SKILL" '{repoStateRoot}/work/{id}/stage-report.md' "sw-design routes stage reports through runtime state"
assert_contains "$PLAN_SKILL" '{repoStateRoot}/work/{selectedWork.id}/stage-report.md' "sw-plan routes stage reports through runtime state"
assert_contains "$BUILD_SKILL" '{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md' "sw-build routes unit stage reports through runtime state"
assert_contains "$VERIFY_SKILL" '{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md' "sw-verify routes unit stage reports through runtime state"
assert_contains "$SHIP_SKILL" '{repoStateRoot}/work/{selectedWork.id}/units/{selectedWork.unitId}/stage-report.md' "sw-ship routes unit stage reports through runtime state"
assert_contains "$PLAN_SKILL" '{workArtifactsRoot}/{selectedWork.id}/design.md' "sw-plan reads auditable design artifacts from workArtifactsRoot"
assert_contains "$BUILD_SKILL" '{workArtifactsRoot}/{selectedWork.id}/design.md' "sw-build reads auditable design artifacts from workArtifactsRoot"
assert_contains "$VERIFY_SKILL" '{workArtifactsRoot}/{selectedWork.id}/' "sw-verify reads integration criteria from workArtifactsRoot"

echo ""
echo "--- Config-only shared root model ---"
CONFIG_ONLY_REPO="$TEST_TMPDIR/config-only"
init_git_repo "$CONFIG_ONLY_REPO"
write_project_config "$CONFIG_ONLY_REPO" "clone-local"
CONFIG_ONLY_REAL="$(cd "$CONFIG_ONLY_REPO" && pwd -P)"
CONFIG_ONLY_OUTPUT="$(inspect_state_json "$CONFIG_ONLY_REPO")"
assert_output_contains "$CONFIG_ONLY_OUTPUT" "\"layout\":\"shared\"" "tracked project config alone opts into the shared root model"
assert_output_contains "$CONFIG_ONLY_OUTPUT" "\"sharedConfigPath\":\"$CONFIG_ONLY_REAL/.specwright/config.json\"" "config-only repo still resolves the tracked shared config path"
assert_output_contains "$CONFIG_ONLY_OUTPUT" "\"workArtifactsRoot\":\"$(repo_state_root "$CONFIG_ONLY_REPO")/work\"" "config-only repo falls back to repoStateRoot/work for clone-local artifacts"

echo ""
echo "--- Clone-local work-artifact mode ---"
CLONE_LOCAL_REPO="$TEST_TMPDIR/clone-local"
init_git_repo "$CLONE_LOCAL_REPO"
write_project_config "$CLONE_LOCAL_REPO" "clone-local"
write_runtime_work "$CLONE_LOCAL_REPO" "root-proof"
CLONE_LOCAL_REAL="$(cd "$CLONE_LOCAL_REPO" && pwd -P)"
CLONE_LOCAL_OUTPUT="$(inspect_state_json "$CLONE_LOCAL_REPO")"
assert_output_contains "$CLONE_LOCAL_OUTPUT" "\"layout\":\"shared\"" "clone-local config still resolves shared runtime layout"
assert_output_contains "$CLONE_LOCAL_OUTPUT" "\"projectArtifactsRoot\":\"$CLONE_LOCAL_REAL/.specwright\"" "projectArtifactsRoot resolves to tracked .specwright root"
assert_output_contains "$CLONE_LOCAL_OUTPUT" "\"sharedConfigPath\":\"$CLONE_LOCAL_REAL/.specwright/config.json\"" "shared config prefers tracked project config"
assert_output_contains "$CLONE_LOCAL_OUTPUT" "\"workArtifactsRoot\":\"$(repo_state_root "$CLONE_LOCAL_REPO")/work\"" "clone-local mode resolves workArtifactsRoot under repoStateRoot/work"
assert_output_contains "$CLONE_LOCAL_OUTPUT" "\"workflowPath\":\"$(repo_state_root "$CLONE_LOCAL_REPO")/work/root-proof/workflow.json\"" "runtime workflow stays under repoStateRoot"
assert_output_contains "$CLONE_LOCAL_OUTPUT" "\"specPath\":\"$(repo_state_root "$CLONE_LOCAL_REPO")/work/root-proof/spec.md\"" "clone-local mode routes spec paths through repoStateRoot/work"

echo ""
echo "--- Tracked work-artifact mode ---"
TRACKED_REPO="$TEST_TMPDIR/tracked"
init_git_repo "$TRACKED_REPO"
write_project_config "$TRACKED_REPO" "tracked" ".specwright/audit-work"
write_runtime_work "$TRACKED_REPO" "root-proof"
TRACKED_REAL="$(cd "$TRACKED_REPO" && pwd -P)"
TRACKED_OUTPUT="$(inspect_state_json "$TRACKED_REPO")"
assert_output_contains "$TRACKED_OUTPUT" "\"workArtifactsRoot\":\"$TRACKED_REAL/.specwright/audit-work\"" "tracked mode resolves workArtifactsRoot from config.git.workArtifacts"
assert_output_contains "$TRACKED_OUTPUT" "\"artifactsRoot\":\"$TRACKED_REAL/.specwright/audit-work\"" "tracked mode keeps normalized work artifacts on the tracked root"
assert_output_contains "$TRACKED_OUTPUT" "\"specPath\":\"$TRACKED_REAL/.specwright/audit-work/root-proof/spec.md\"" "tracked mode routes spec paths through configured workArtifactsRoot"
assert_output_contains "$TRACKED_OUTPUT" "\"workflowPath\":\"$(repo_state_root "$TRACKED_REPO")/work/root-proof/workflow.json\"" "tracked mode keeps workflow.json in runtime state"

echo ""
echo "--- Tracked work-artifact safety boundaries ---"
GIT_ROOT_REPO="$TEST_TMPDIR/git-root"
init_git_repo "$GIT_ROOT_REPO"
write_project_config "$GIT_ROOT_REPO" "tracked" ".git/specwright"
GIT_ROOT_OUTPUT="$(inspect_state_json "$GIT_ROOT_REPO")"
assert_output_contains "$GIT_ROOT_OUTPUT" "\"workArtifactsRoot\":\"$(repo_state_root "$GIT_ROOT_REPO")/work\"" "trackedRoot under .git is rejected in favor of repoStateRoot/work"

OUTSIDE_ROOT_REPO="$TEST_TMPDIR/outside-root"
init_git_repo "$OUTSIDE_ROOT_REPO"
write_project_config "$OUTSIDE_ROOT_REPO" "tracked" "../../outside"
OUTSIDE_ROOT_OUTPUT="$(inspect_state_json "$OUTSIDE_ROOT_REPO")"
assert_output_contains "$OUTSIDE_ROOT_OUTPUT" "\"workArtifactsRoot\":\"$(repo_state_root "$OUTSIDE_ROOT_REPO")/work\"" "trackedRoot outside the project is rejected in favor of repoStateRoot/work"

REPO_ROOT_REPO="$TEST_TMPDIR/repo-root"
init_git_repo "$REPO_ROOT_REPO"
write_project_config "$REPO_ROOT_REPO" "tracked" "."
REPO_ROOT_OUTPUT="$(inspect_state_json "$REPO_ROOT_REPO")"
assert_output_contains "$REPO_ROOT_OUTPUT" "\"workArtifactsRoot\":\"$(repo_state_root "$REPO_ROOT_REPO")/work\"" "trackedRoot overlapping the repo root is rejected in favor of repoStateRoot/work"

SYMLINK_ROOT_REPO="$TEST_TMPDIR/symlink-root"
init_git_repo "$SYMLINK_ROOT_REPO"
mkdir -p "$SYMLINK_ROOT_REPO/.specwright" "$(repo_state_root "$SYMLINK_ROOT_REPO")/work"
ln -s "$(repo_state_root "$SYMLINK_ROOT_REPO")/work" "$SYMLINK_ROOT_REPO/.specwright/audit-link"
write_project_config "$SYMLINK_ROOT_REPO" "tracked" ".specwright/audit-link"
SYMLINK_ROOT_OUTPUT="$(inspect_state_json "$SYMLINK_ROOT_REPO")"
assert_output_contains "$SYMLINK_ROOT_OUTPUT" "\"workArtifactsRoot\":\"$(repo_state_root "$SYMLINK_ROOT_REPO")/work\"" "trackedRoot symlinked into runtime state is rejected in favor of repoStateRoot/work"

echo ""
echo "--- Malformed workDir containment ---"
ESCAPE_REPO="$TEST_TMPDIR/escape-workdir"
init_git_repo "$ESCAPE_REPO"
write_project_config "$ESCAPE_REPO" "tracked" ".specwright/audit-work"
write_runtime_work "$ESCAPE_REPO" "root-proof" "../escape"
ESCAPE_REAL="$(cd "$ESCAPE_REPO" && pwd -P)"
ESCAPE_OUTPUT="$(inspect_state_json "$ESCAPE_REPO")"
assert_output_contains "$ESCAPE_OUTPUT" "\"workDirPath\":\"$ESCAPE_REAL/.specwright/audit-work/root-proof\"" "escaped workDir falls back to a contained tracked work directory"
assert_output_contains "$ESCAPE_OUTPUT" "\"specPath\":\"$ESCAPE_REAL/.specwright/audit-work/root-proof/spec.md\"" "escaped workDir cannot push spec paths outside workArtifactsRoot"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
