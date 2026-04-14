#!/usr/bin/env bash

git_nested_prepare() {
  if [ "${GIT_NESTED_LOCAL_ENV_VARS_READY:-0}" = "1" ]; then
    return 0
  fi

  if ! GIT_NESTED_LOCAL_ENV_VARS="$(git rev-parse --local-env-vars 2>/dev/null)"; then
    echo "ERROR: git rev-parse --local-env-vars is required for nested git isolation helpers" >&2
    return 1
  fi

  GIT_NESTED_LOCAL_ENV_VARS_READY=1
}

git_nested() {
  git_nested_prepare || return 1

  local env_cmd=(env)
  local git_var
  while IFS= read -r git_var; do
    [ -n "$git_var" ] || continue
    env_cmd+=(-u "$git_var")
  done <<< "$(printf '%s\n%s\n%s\n' "$GIT_NESTED_LOCAL_ENV_VARS" "GIT_CONFIG_COUNT" "GIT_CONFIG_PARAMETERS")"

  "${env_cmd[@]}" git "$@"
}

init_git_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git_nested -C "$dir" -c core.hooksPath=/dev/null init -q || return 1
  git_nested -C "$dir" -c core.hooksPath=/dev/null config user.name "Specwright Tests" || return 1
  git_nested -C "$dir" -c core.hooksPath=/dev/null config user.email "specwright-tests@example.com" || return 1
  git_nested -C "$dir" -c core.hooksPath=/dev/null checkout -qb main >/dev/null 2>&1 || true
  printf 'seed\n' > "$dir/README.md"
  git_nested -C "$dir" -c core.hooksPath=/dev/null add README.md || return 1
  git_nested -C "$dir" -c core.hooksPath=/dev/null commit -qm "test: init repo" || return 1
}

run_with_outer_git_context() {
  local outer="$1"
  shift
  local outer_git_dir outer_common_dir outer_root
  outer_git_dir="$(git_nested -C "$outer" rev-parse --path-format=absolute --git-dir)" || return 1
  outer_common_dir="$(git_nested -C "$outer" rev-parse --path-format=absolute --git-common-dir)" || return 1
  outer_root="$(cd "$outer" && pwd -P)"
  GIT_DIR="$outer_git_dir" \
  GIT_WORK_TREE="$outer_root" \
  GIT_COMMON_DIR="$outer_common_dir" \
  GIT_PREFIX="" \
  "$@"
}

git_common_dir() {
  git_nested -C "$1" rev-parse --path-format=absolute --git-common-dir
}

git_dir() {
  git_nested -C "$1" rev-parse --path-format=absolute --git-dir
}
