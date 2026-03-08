#!/usr/bin/env bash
#
# Specwright Build Script
#
# Builds platform-specific packages from core/ + adapters/.
#
# Usage: ./build/build.sh [platform]
#   platform: claude-code | opencode | all (default: all)
#
# Mapping file schema (build/mappings/{platform}.json):
#   platform       — platform identifier
#   tools          — object mapping Claude Code tool names to platform equivalents
#   strip          — array of tool names to remove from allowed-tools
#   events         — object mapping Claude Code event names to platform equivalents
#   models         — object mapping shorthand model names to full model IDs
#   protocolPrefix — string to prepend to "protocols/" references
#   skillOverrides — array of skill names to replace with adapter-specific versions
#
# Dependencies: bash, sed, jq, cp, mkdir, rm, diff, find

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"

# ─── Transformation Functions ───────────────────────────────────────

transform_frontmatter_tools() {
  local file="$1"
  local mapping_file="$2"

  local tool_keys
  tool_keys=$(jq -r '.tools | keys[]' "$mapping_file" 2>/dev/null)
  [ -z "$tool_keys" ] && return 0

  local tmpfile
  tmpfile=$(mktemp)

  while IFS= read -r tool_name; do
    local new_name
    new_name=$(jq -r --arg k "$tool_name" '.tools[$k]' "$mapping_file")
    # Only transform within YAML frontmatter allowed-tools arrays
    # Match lines like "  - ToolName" between --- markers
    sed "/^---$/,/^---$/ s/^\\(  - \\)${tool_name}$/\\1${new_name}/" "$file" > "$tmpfile"
    cp "$tmpfile" "$file"
  done <<< "$tool_keys"

  rm -f "$tmpfile"
}

strip_tools() {
  local file="$1"
  local mapping_file="$2"

  local strip_list
  strip_list=$(jq -r '.strip[]' "$mapping_file" 2>/dev/null)
  [ -z "$strip_list" ] && return 0

  local tmpfile
  tmpfile=$(mktemp)

  while IFS= read -r tool_name; do
    # Remove "  - ToolName" lines within YAML frontmatter
    sed "/^---$/,/^---$/ { /^  - ${tool_name}$/d; }" "$file" > "$tmpfile"
    cp "$tmpfile" "$file"
  done <<< "$strip_list"

  rm -f "$tmpfile"
}

rewrite_protocol_refs() {
  local file="$1"
  local mapping_file="$2"

  local prefix
  prefix=$(jq -r '.protocolPrefix // ""' "$mapping_file")
  [ -z "$prefix" ] && return 0

  local tmpfile
  tmpfile=$(mktemp)

  # Prepend prefix to "protocols/" references in skill body (after frontmatter)
  # Match references like: protocols/state.md, `protocols/git.md`
  sed "s|protocols/|${prefix}protocols/|g" "$file" > "$tmpfile"
  cp "$tmpfile" "$file"

  rm -f "$tmpfile"
}

translate_agent() {
  local file="$1"
  local mapping_file="$2"

  # Transform model names in frontmatter
  local model_keys
  model_keys=$(jq -r '.models | keys[]' "$mapping_file" 2>/dev/null)

  if [ -n "$model_keys" ]; then
    local tmpfile
    tmpfile=$(mktemp)

    while IFS= read -r model_name; do
      local new_model
      new_model=$(jq -r --arg k "$model_name" '.models[$k]' "$mapping_file")
      sed "/^---$/,/^---$/ s/model: ${model_name}/model: ${new_model}/" "$file" > "$tmpfile"
      cp "$tmpfile" "$file"
    done <<< "$model_keys"

    rm -f "$tmpfile"
  fi
}

apply_skill_overrides() {
  local platform="$1"
  local dist_skills_dir="$2"
  local mapping_file="$3"

  local overrides
  overrides=$(jq -r '.skillOverrides[]' "$mapping_file" 2>/dev/null)
  [ -z "$overrides" ] && return 0

  while IFS= read -r skill_name; do
    local override_file="$ROOT_DIR/adapters/$platform/skills/$skill_name/SKILL.md"
    if [ -f "$override_file" ]; then
      cp "$override_file" "$dist_skills_dir/$skill_name/SKILL.md"
      echo "  Override applied: $skill_name"
    else
      echo "  WARNING: Override listed for $skill_name but file not found: $override_file"
    fi
  done <<< "$overrides"
}

# ─── Validation ─────────────────────────────────────────────────────

validate_skills() {
  local platform="$1"
  local skills_dir="$DIST_DIR/$platform/skills"
  local errors=0

  for skill_dir in "$skills_dir"/*/; do
    local skill_file="$skill_dir/SKILL.md"
    [ -f "$skill_file" ] || continue

    local skill_name
    skill_name=$(basename "$skill_dir")

    # Check for name: in YAML frontmatter
    if ! sed -n '/^---$/,/^---$/p' "$skill_file" | grep -q '^name:'; then
      echo "  FAIL: $skill_name/SKILL.md missing 'name:' in frontmatter"
      errors=$((errors + 1))
    fi

    # Check for description: in YAML frontmatter
    if ! sed -n '/^---$/,/^---$/p' "$skill_file" | grep -q '^description:'; then
      echo "  FAIL: $skill_name/SKILL.md missing 'description:' in frontmatter"
      errors=$((errors + 1))
    fi
  done

  return $errors
}

# ─── Platform Builds ────────────────────────────────────────────────

build_claude_code() {
  local platform="claude-code"
  local mapping_file="$ROOT_DIR/build/mappings/claude-code.json"
  local dist="$DIST_DIR/$platform"

  echo "Building: $platform"

  # Clean
  rm -rf "$dist"
  mkdir -p "$dist"

  # Copy core content
  cp -r "$ROOT_DIR/core/skills" "$dist/skills"
  cp -r "$ROOT_DIR/core/protocols" "$dist/protocols"
  cp -r "$ROOT_DIR/core/agents" "$dist/agents"

  # Copy adapter content
  cp -r "$ROOT_DIR/adapters/claude-code/hooks" "$dist/hooks"
  cp -r "$ROOT_DIR/adapters/claude-code/.claude-plugin" "$dist/.claude-plugin"
  cp "$ROOT_DIR/adapters/claude-code/CLAUDE.md" "$dist/CLAUDE.md"

  # Copy README
  cp "$ROOT_DIR/README.md" "$dist/README.md"

  # Apply transformations (no-ops for claude-code with empty mappings)
  for skill_file in "$dist"/skills/*/SKILL.md; do
    transform_frontmatter_tools "$skill_file" "$mapping_file"
    strip_tools "$skill_file" "$mapping_file"
    rewrite_protocol_refs "$skill_file" "$mapping_file"
  done

  for agent_file in "$dist"/agents/*.md; do
    translate_agent "$agent_file" "$mapping_file"
  done

  apply_skill_overrides "$platform" "$dist/skills" "$mapping_file"

  # Validate
  echo "Validating: $platform"
  if validate_skills "$platform"; then
    echo "  All skills valid"
  else
    echo "  ERROR: Validation failed"
    return 1
  fi

  echo "Build complete: $platform → dist/$platform/"
}

# ─── Main ───────────────────────────────────────────────────────────

main() {
  local target="${1:-all}"

  case "$target" in
    claude-code)
      build_claude_code
      ;;
    all)
      build_claude_code
      ;;
    *)
      echo "ERROR: Unknown platform '$target'"
      echo "Usage: $0 [claude-code | opencode | all]"
      exit 1
      ;;
  esac
}

main "$@"
