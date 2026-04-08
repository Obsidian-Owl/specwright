#!/usr/bin/env bash

set -euo pipefail

PLUGIN_NAME="specwright"
ASSET_NAME="specwright-codex.tar.gz"
REPO_SLUG="${SPECWRIGHT_REPO:-Obsidian-Owl/specwright}"
ASSET_URL="${SPECWRIGHT_CODEX_ASSET_URL:-}"
MODE="install"
SCOPE="user"
VERSION="latest"
REPO_ROOT=""

usage() {
  cat <<'EOF'
Install or update the Specwright Codex plugin bundle.

Usage:
  install-codex.sh [--user | --repo] [--repo-root PATH] [--version VERSION]
  install-codex.sh --update [--user | --repo] [--repo-root PATH] [--version VERSION]

Options:
  --user             Install into the current user's Codex marketplace (default)
  --repo             Install into a repository-local Codex marketplace
  --repo-root PATH   Target repository root for --repo installs (defaults to cwd)
  --version VERSION  Release version to install, for example 0.27.2 (default: latest)
  --update           Replace an existing installation with the requested version
  --help             Show this help text

Environment:
  SPECWRIGHT_CODEX_ASSET_URL  Override the archive URL. Intended for tests.
  SPECWRIGHT_REPO             Override the GitHub repo slug. Intended for forks.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

normalize_version() {
  if [ "$VERSION" = "latest" ]; then
    return
  fi

  VERSION="${VERSION#v}"
}

resolve_asset_url() {
  if [ -n "$ASSET_URL" ]; then
    printf '%s\n' "$ASSET_URL"
    return
  fi

  if [ "$VERSION" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s\n' "$REPO_SLUG" "$ASSET_NAME"
    return
  fi

  printf 'https://github.com/%s/releases/download/v%s/%s\n' "$REPO_SLUG" "$VERSION" "$ASSET_NAME"
}

resolve_paths() {
  case "$SCOPE" in
    user)
      MARKETPLACE_PATH="$HOME/.agents/plugins/marketplace.json"
      BUNDLE_PATH="$HOME/plugins/$PLUGIN_NAME"
      ;;
    repo)
      if [ -z "$REPO_ROOT" ]; then
        REPO_ROOT="$(pwd)"
      fi
      REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
      MARKETPLACE_PATH="$REPO_ROOT/.agents/plugins/marketplace.json"
      BUNDLE_PATH="$REPO_ROOT/plugins/$PLUGIN_NAME"
      ;;
    *)
      die "unknown scope: $SCOPE"
      ;;
  esac
}

extract_bundle() {
  local archive_url="$1"
  local archive_path="$TMP_DIR/$ASSET_NAME"
  local extract_root="$TMP_DIR/extract"
  local manifest_path

  mkdir -p "$extract_root"
  curl -fsSL "$archive_url" -o "$archive_path"
  tar -xzf "$archive_path" -C "$extract_root"

  if [ -f "$extract_root/.codex-plugin/plugin.json" ]; then
    printf '%s\n' "$extract_root"
    return
  fi

  manifest_path=$(find "$extract_root" -path '*/.codex-plugin/plugin.json' -type f | head -n 1 || true)
  if [ -z "$manifest_path" ]; then
    die "downloaded archive does not contain a Codex plugin manifest"
  fi

  dirname "$(dirname "$manifest_path")"
}

safe_replace_bundle() {
  local source_dir="$1"

  case "$BUNDLE_PATH" in
    */plugins/"$PLUGIN_NAME") ;;
    *)
      die "refusing to replace unexpected plugin path: $BUNDLE_PATH"
      ;;
  esac

  mkdir -p "$(dirname "$BUNDLE_PATH")"
  rm -rf "$BUNDLE_PATH"
  cp -R "$source_dir" "$BUNDLE_PATH"
}

update_marketplace() {
  python3 - "$MARKETPLACE_PATH" "$PLUGIN_NAME" <<'PY'
import json
import sys
from pathlib import Path

marketplace_path = Path(sys.argv[1])
plugin_name = sys.argv[2]

entry = {
    "name": plugin_name,
    "source": {
        "source": "local",
        "path": f"./plugins/{plugin_name}",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    },
    "category": "Coding",
}

payload = {
    "name": "specwright-local",
    "interface": {
        "displayName": "Specwright Local",
    },
    "plugins": [],
}

if marketplace_path.exists():
    loaded = json.loads(marketplace_path.read_text())
    if not isinstance(loaded, dict):
        raise SystemExit(f"{marketplace_path} must contain a JSON object")
    payload = loaded

plugins = payload.get("plugins")
if plugins is None:
    plugins = []
if not isinstance(plugins, list):
    raise SystemExit(f"{marketplace_path} field 'plugins' must be an array")

payload.setdefault("name", "specwright-local")
interface = payload.get("interface")
if interface is None:
    interface = {}
if not isinstance(interface, dict):
    raise SystemExit(f"{marketplace_path} field 'interface' must be an object")
interface.setdefault("displayName", "Specwright Local")
payload["interface"] = interface

updated = []
replaced = False
for plugin in plugins:
    if isinstance(plugin, dict) and plugin.get("name") == plugin_name:
        if not replaced:
            updated.append(entry)
            replaced = True
        continue
    updated.append(plugin)

if not replaced:
    updated.append(entry)

payload["plugins"] = updated
marketplace_path.parent.mkdir(parents=True, exist_ok=True)
marketplace_path.write_text(json.dumps(payload, indent=2) + "\n")
PY
}

print_summary() {
  local action_word="Installed"
  if [ "$MODE" = "update" ]; then
    action_word="Updated"
  fi

  cat <<EOF
$action_word Specwright for Codex.

Bundle path:      $BUNDLE_PATH
Marketplace path: $MARKETPLACE_PATH
Install scope:    $SCOPE
Version:          $VERSION

Next steps:
  1. Start Codex.
  2. Open /plugins.
  3. Install or enable the "specwright" plugin.
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --user)
      SCOPE="user"
      ;;
    --repo)
      SCOPE="repo"
      ;;
    --repo-root)
      shift
      [ $# -gt 0 ] || die "--repo-root requires a path"
      REPO_ROOT="$1"
      ;;
    --version)
      shift
      [ $# -gt 0 ] || die "--version requires a value"
      VERSION="$1"
      ;;
    --update)
      MODE="update"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown argument: $1"
      ;;
  esac
  shift
done

require_cmd curl
require_cmd tar
require_cmd python3
normalize_version
resolve_paths

TMP_DIR="$(mktemp -d 2>/dev/null || mktemp -d -t specwright-codex)"
trap 'rm -rf "$TMP_DIR"' EXIT

ARCHIVE_URL="$(resolve_asset_url)"
BUNDLE_SOURCE="$(extract_bundle "$ARCHIVE_URL")"

safe_replace_bundle "$BUNDLE_SOURCE"
update_marketplace
print_summary
