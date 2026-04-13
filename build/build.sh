#!/usr/bin/env bash
#
# Specwright Build Script
#
# Builds platform-specific packages from core/ + adapters/.
#
# Usage: ./build/build.sh [platform]
#   platform: claude-code | opencode | codex | all (default: all)
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

# ─── Helpers ────────────────────────────────────────────────────────

# Get the line number of the closing --- of YAML frontmatter.
# Returns 0 if no frontmatter found.
frontmatter_end() {
  local file="$1"
  awk 'NR==1 && /^---$/ { found=1; next }
       found && /^---$/ { print NR; exit }' "$file"
}

# ─── Transformation Functions ───────────────────────────────────────

transform_frontmatter_tools() {
  local file="$1"
  local mapping_file="$2"

  local tool_keys
  tool_keys=$(jq -r '.tools | keys[]' "$mapping_file" 2>/dev/null)
  [ -z "$tool_keys" ] && return 0

  local fm_end
  fm_end=$(frontmatter_end "$file")
  [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && return 0

  local tmpfile
  tmpfile=$(mktemp)

  while IFS= read -r tool_name; do
    local new_name
    new_name=$(jq -r --arg k "$tool_name" '.tools[$k]' "$mapping_file")
    # Only transform within YAML frontmatter (lines 1 to fm_end)
    sed "1,${fm_end} s/^\\(  - \\)${tool_name}$/\\1${new_name}/" "$file" > "$tmpfile"
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

  local fm_end
  fm_end=$(frontmatter_end "$file")
  [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && return 0

  local tmpfile
  tmpfile=$(mktemp)

  while IFS= read -r tool_name; do
    # Remove "  - ToolName" lines within YAML frontmatter only
    sed "1,${fm_end} { /^  - ${tool_name}$/d; }" "$file" > "$tmpfile"
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
  local fm_end
  fm_end=$(frontmatter_end "$file")
  [ -z "$fm_end" ] && fm_end=0

  awk -v fm_end="$fm_end" -v prefix="$prefix" '
    NR > fm_end { gsub(/protocols\//, prefix "protocols/") }
    { print }
  ' "$file" > "$tmpfile"
  cp "$tmpfile" "$file"

  rm -f "$tmpfile"
}

strip_platform_sections() {
  local file="$1"
  local platform="$2"

  local tmpfile
  tmpfile=$(mktemp)

  awk -v target="$platform" '
    /^[[:space:]]*<!-- platform:[a-zA-Z0-9_-]+ -->[[:space:]]*$/ {
      line = $0
      sub(/^[[:space:]]*<!-- platform:/, "", line)
      sub(/ -->[[:space:]]*$/, "", line)
      if (line == target) {
        in_block = 1
        skip = 0
      } else {
        in_block = 1
        skip = 1
      }
      next
    }
    /^[[:space:]]*<!-- \/platform -->[[:space:]]*$/ {
      if (in_block) {
        in_block = 0
        skip = 0
        next
      }
    }
    {
      if (!skip) print
    }
  ' "$file" > "$tmpfile"
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
    local fm_end
    fm_end=$(frontmatter_end "$file")
    [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && return 0

    local tmpfile
    tmpfile=$(mktemp)

    while IFS= read -r model_name; do
      local new_model
      new_model=$(jq -r --arg k "$model_name" '.models[$k]' "$mapping_file")
      sed "1,${fm_end} s/model: ${model_name}/model: ${new_model}/" "$file" > "$tmpfile"
      cp "$tmpfile" "$file"
    done <<< "$model_keys"

    rm -f "$tmpfile"
  fi
}

add_agent_mode() {
  local file="$1"
  local mode="$2"

  local fm_end
  fm_end=$(frontmatter_end "$file")
  [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && return 0

  # Only add if mode: is not already present in frontmatter
  if ! sed -n "1,${fm_end}p" "$file" | grep -q '^mode:'; then
    local tmpfile
    tmpfile=$(mktemp)
    # Insert "mode: <value>" on line 2 (after opening ---)
    # Use awk for portability across BSD and GNU sed
    awk -v mode="mode: ${mode}" 'NR==1{print; print mode; next} {print}' "$file" > "$tmpfile"
    cp "$tmpfile" "$file"
    rm -f "$tmpfile"
  fi
}

transform_agent_tools() {
  local file="$1"
  local mapping_file="$2"

  local fm_end
  fm_end=$(frontmatter_end "$file")
  [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ] && return 0

  # Pass 1: Transform mapped tools "  - OldName" -> "  newname: true"
  local tool_keys
  tool_keys=$(jq -r '.tools | keys[]' "$mapping_file" 2>/dev/null)

  local tmpfile
  tmpfile=$(mktemp)
  cp "$file" "$tmpfile"

  if [ -n "$tool_keys" ]; then
    while IFS= read -r tool_name; do
      local new_name
      new_name=$(jq -r --arg k "$tool_name" '.tools[$k]' "$mapping_file")
      sed "1,${fm_end} s/^  - ${tool_name}$/  ${new_name}: true/" "$tmpfile" > "${tmpfile}.new"
      mv "${tmpfile}.new" "$tmpfile"
    done <<< "$tool_keys"
  fi

  # Pass 2: Convert any remaining "  - ToolName" lines to "  toolname: true"
  awk -v fm_end="$fm_end" '
    NR <= fm_end && /^  - [A-Za-z]/ {
      tool = substr($0, 5)
      print "  " tolower(tool) ": true"
      next
    }
    { print }
  ' "$tmpfile" > "${tmpfile}.2"
  mv "${tmpfile}.2" "$tmpfile"

  cp "$tmpfile" "$file"
  rm -f "$tmpfile"
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

    # Extract only the first frontmatter block for validation
    local fm_end
    fm_end=$(frontmatter_end "$skill_file")

    if [ -z "$fm_end" ] || [ "$fm_end" -eq 0 ]; then
      echo "  FAIL: $skill_name/SKILL.md has no YAML frontmatter"
      errors=$((errors + 1))
      continue
    fi

    local frontmatter
    frontmatter=$(sed -n "1,${fm_end}p" "$skill_file")

    # Check for name: in YAML frontmatter
    if ! echo "$frontmatter" | grep -q '^name:'; then
      echo "  FAIL: $skill_name/SKILL.md missing 'name:' in frontmatter"
      errors=$((errors + 1))
    fi

    # Check for description: in YAML frontmatter
    if ! echo "$frontmatter" | grep -q '^description:'; then
      echo "  FAIL: $skill_name/SKILL.md missing 'description:' in frontmatter"
      errors=$((errors + 1))
    fi
  done

  return $errors
}

copy_shared_adapters() {
  rm -rf "$DIST_DIR/shared"
  cp -r "$ROOT_DIR/adapters/shared" "$DIST_DIR/shared"
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
  copy_shared_adapters

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

  # Strip platform-conditional sections
  for skill_file in "$dist"/skills/*/SKILL.md; do
    strip_platform_sections "$skill_file" "$platform"
  done

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

build_opencode() {
  local platform="opencode"
  local mapping_file="$ROOT_DIR/build/mappings/opencode.json"
  local dist="$DIST_DIR/$platform"

  echo "Building: $platform"

  # Clean
  rm -rf "$dist"
  mkdir -p "$dist"

  # Copy core content
  cp -r "$ROOT_DIR/core/skills" "$dist/skills"
  cp -r "$ROOT_DIR/core/protocols" "$dist/protocols"
  cp -r "$ROOT_DIR/core/agents" "$dist/agents"

  # Copy adapter content (opencode-specific, no hooks/.claude-plugin/CLAUDE.md).
  # Opencode does not import adapters/shared because it has no runtime hooks.
  cp -r "$ROOT_DIR/adapters/opencode/commands" "$dist/commands"
  cp "$ROOT_DIR/adapters/opencode/package.json" "$dist/package.json"
  cp "$ROOT_DIR/adapters/opencode/plugin.ts" "$dist/plugin.ts"

  # Copy adapter-specific README
  cp "$ROOT_DIR/adapters/opencode/README.md" "$dist/README.md"

  # Apply skill transformations
  for skill_file in "$dist"/skills/*/SKILL.md; do
    transform_frontmatter_tools "$skill_file" "$mapping_file"
    strip_tools "$skill_file" "$mapping_file"
    rewrite_protocol_refs "$skill_file" "$mapping_file"
  done

  # Apply agent transformations
  for agent_file in "$dist"/agents/*.md; do
    translate_agent "$agent_file" "$mapping_file"
    add_agent_mode "$agent_file" "subagent"
    transform_agent_tools "$agent_file" "$mapping_file"
  done

  # Apply skill overrides (adapter versions replace transformed core versions)
  apply_skill_overrides "$platform" "$dist/skills" "$mapping_file"

  # Re-transform overridden skills (they were copied after the initial pass)
  local override_list
  override_list=$(jq -r '.skillOverrides[]' "$mapping_file" 2>/dev/null)
  if [ -n "$override_list" ]; then
    while IFS= read -r skill_name; do
      local override_skill="$dist/skills/$skill_name/SKILL.md"
      [ -f "$override_skill" ] || continue
      transform_frontmatter_tools "$override_skill" "$mapping_file"
      strip_tools "$override_skill" "$mapping_file"
      rewrite_protocol_refs "$override_skill" "$mapping_file"
    done <<< "$override_list"
  fi

  # Strip platform-conditional sections
  for skill_file in "$dist"/skills/*/SKILL.md; do
    strip_platform_sections "$skill_file" "$platform"
  done

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

build_codex() {
  local platform="codex"
  local mapping_file="$ROOT_DIR/build/mappings/codex.json"
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
  cp -r "$ROOT_DIR/adapters/codex/commands" "$dist/commands"
  cp -r "$ROOT_DIR/adapters/codex/hooks" "$dist/hooks"
  cp "$ROOT_DIR/adapters/codex/hooks.json" "$dist/hooks.json"
  cp -r "$ROOT_DIR/adapters/codex/.codex-plugin" "$dist/.codex-plugin"
  copy_shared_adapters

  # Copy adapter-specific README
  cp "$ROOT_DIR/adapters/codex/README.md" "$dist/README.md"

  # Apply skill transformations
  for skill_file in "$dist"/skills/*/SKILL.md; do
    transform_frontmatter_tools "$skill_file" "$mapping_file"
    strip_tools "$skill_file" "$mapping_file"
    rewrite_protocol_refs "$skill_file" "$mapping_file"
  done

  # Apply agent transformations
  for agent_file in "$dist"/agents/*.md; do
    translate_agent "$agent_file" "$mapping_file"
  done

  apply_skill_overrides "$platform" "$dist/skills" "$mapping_file"

  # Re-transform overridden skills (they were copied after the initial pass)
  local override_list
  override_list=$(jq -r '.skillOverrides[]' "$mapping_file" 2>/dev/null)
  if [ -n "$override_list" ]; then
    while IFS= read -r skill_name; do
      local override_skill="$dist/skills/$skill_name/SKILL.md"
      [ -f "$override_skill" ] || continue
      transform_frontmatter_tools "$override_skill" "$mapping_file"
      strip_tools "$override_skill" "$mapping_file"
      rewrite_protocol_refs "$override_skill" "$mapping_file"
    done <<< "$override_list"
  fi

  # Strip platform-conditional sections
  for skill_file in "$dist"/skills/*/SKILL.md; do
    strip_platform_sections "$skill_file" "$platform"
  done

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
    opencode)
      build_opencode
      ;;
    codex)
      build_codex
      ;;
    all)
      build_claude_code
      build_opencode
      build_codex
      ;;
    *)
      echo "ERROR: Unknown platform '$target'"
      echo "Usage: $0 [claude-code | opencode | codex | all]"
      exit 1
      ;;
  esac
}

# Only run main when executed directly, not when sourced (e.g., by tests)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
