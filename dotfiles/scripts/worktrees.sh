#!/usr/bin/env bash

set -euo pipefail

# Git Worktrees Manager
#
# Features:
# - create: Create a worktree per branch (defaults to all local branches except main)
# - new:    Create branch(es) from a base and add worktree(s) (optionally push & set upstream)
# - update: Fetch/pull each worktree (ff-only by default, --rebase optional)
# - diff:   Show diffs vs upstream (origin/<branch> by default)
# - push:   Push all or only changed branches
# - exec:   Run an arbitrary command in each worktree
# - tui:    Interactive TUI per worktree (dotbare/lazygit) and fzf interactive selectors
# - list:   List branches and their worktree paths
# - status: Show short status per worktree
# - prune:  Prune stale worktrees and verify
#
# Configuration via env vars (override as needed). Values can be persisted in .worktrees.env:
#   WORKTREES_ROOT: where to place worktrees (default: <repo_root>/worktrees)
#   EXCLUDE_BRANCHES: space-separated branches to exclude (default: "main")
#   DEFAULT_BASE_BRANCH: base branch for creating new branches (default: "main")
#   AUTO_PUSH_NEW_BRANCHES: if "true", push new branches on creation (default: "false")
#   RUN_PRE_COMMIT: run pre-commit in tasks phases if available (default: "false")
#   PRE_CREATE_TASKS, POST_CREATE_TASKS, PRE_UPDATE_TASKS, POST_UPDATE_TASKS,
#   PRE_PUSH_TASKS, POST_PUSH_TASKS, PRE_DIFF_TASKS, POST_DIFF_TASKS: shell commands to run
#   ENABLE_DOTBARE: if "true", enable dotbare integration (default: "true")
#   DOTBARE_CMD: dotbare binary name/path (default: "dotbare")
#   FZF_CMD: fzf binary name/path (default: "fzf")
#   ENABLE_PARALLEL: if "true", allow parallel execution (default: "false")
#   PARALLEL_JOBS: number of parallel jobs (default: CPU cores or 4)
#   ENABLE_PARALLEL: if "true", allow parallel execution (default: "false")
#   PARALLEL_JOBS: number of parallel jobs (default: CPU cores or 4)
#
# Usage examples:
#   scripts/worktrees.sh create                    # create for all branches except main
#   scripts/worktrees.sh create --branches "dev Aline"
#   scripts/worktrees.sh new --branches "feature-x" --base main --push
#   scripts/worktrees.sh update --rebase
#   scripts/worktrees.sh diff --stat
#   scripts/worktrees.sh push --changed
#   scripts/worktrees.sh exec -- "npm test"
#   scripts/worktrees.sh tui
#   scripts/worktrees.sh list
#   scripts/worktrees.sh status
#   scripts/worktrees.sh prune

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

# Load persistent configuration from .worktrees.env if present
WORKTREES_ENV_FILE="${WORKTREES_ENV_FILE:-${REPO_ROOT}/.worktrees.env}"
if [[ -f "${WORKTREES_ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${WORKTREES_ENV_FILE}"
  set +a
fi

WORKTREES_ROOT="${WORKTREES_ROOT:-${REPO_ROOT}/worktrees}"
EXCLUDE_BRANCHES_DEFAULT=(main)
DEFAULT_BASE_BRANCH="${DEFAULT_BASE_BRANCH:-main}"
AUTO_PUSH_NEW_BRANCHES="${AUTO_PUSH_NEW_BRANCHES:-false}"
RUN_PRE_COMMIT="${RUN_PRE_COMMIT:-false}"
ENABLE_DOTBARE="${ENABLE_DOTBARE:-true}"
DOTBARE_CMD="${DOTBARE_CMD:-dotbare}"
FZF_CMD="${FZF_CMD:-fzf}"

_log() { printf "[worktrees] %s\n" "$*"; }
_err() { printf "[worktrees][error] %s\n" "$*" 1>&2; }
_die() { _err "$*"; exit 1; }

_ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
}

_has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

_all_local_branches() {
  git for-each-ref --format='%(refname:short)' refs/heads
}

_contains() {
  local needle="$1"; shift
  for x in "$@"; do
    [[ "$x" == "$needle" ]] && return 0
  done
  return 1
}

_default_excludes() {
  printf "%s\n" "${EXCLUDE_BRANCHES:-${EXCLUDE_BRANCHES_DEFAULT[*]}}" | xargs -n1
}

_resolve_branches() {
  # Reads branches from args (space-separated) or defaults to all local minus excludes
  # Usage: _resolve_branches "$branches_csv"
  local requested="$1"
  local -a branches=()
  if [[ -n "$requested" ]]; then
    # shellcheck disable=SC2206
    branches=($requested)
  else
    mapfile -t branches < <(_all_local_branches)
    local -a excludes
    mapfile -t excludes < <(_default_excludes)
    local -a filtered=()
    local b
    for b in "${branches[@]}"; do
      if _contains "$b" "${excludes[@]}"; then
        continue
      fi
      filtered+=("$b")
    done
    branches=(${filtered[@]:-})
  fi
  printf "%s\n" "${branches[@]:-}"
}

_fzf_select_branches() {
  # Usage: _fzf_select_branches <provided-space-separated-or-empty> [--multi]
  local provided_list="$1"; shift || true
  local multi=false
  if [[ "${1:-}" == "--multi" ]]; then multi=true; fi
  local -a branches
  if [[ -n "$provided_list" ]]; then
    # shellcheck disable=SC2206
    branches=($provided_list)
  else
    mapfile -t branches < <(_resolve_branches "")
  fi
  if ! _has_cmd "$FZF_CMD"; then
    _die "fzf is required for --interactive. Install it and retry."
  fi
  if $multi; then
    printf "%s\n" "${branches[@]}" | "$FZF_CMD" --multi --prompt="branches> "
  else
    printf "%s\n" "${branches[@]}" | "$FZF_CMD" --prompt="branch> " | head -n1
  fi
}

_ensure_upstream() {
  local branch="$1"
  if git rev-parse --abbrev-ref --symbolic-full-name "$branch@{upstream}" >/dev/null 2>&1; then
    return 0
  fi
  # Try to set upstream to origin/<branch> if it exists
  if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
    _log "Setting upstream of $branch -> origin/$branch"
    git branch --set-upstream-to="origin/${branch}" "$branch" >/dev/null
  else
    _err "No upstream found for ${branch} and origin/${branch} does not exist"
  fi
}

_worktree_path_for() {
  local branch="$1"
  printf "%s\n" "${WORKTREES_ROOT}/${branch}"
}

_run_phase_tasks() {
  # Usage: _run_phase_tasks <phase> <branch> <path>
  # phase in: pre_create, post_create, pre_update, post_update, pre_push, post_push, pre_diff, post_diff
  local phase="$1" branch="$2" path="$3"
  local var_name
  case "$phase" in
    pre_create) var_name=PRE_CREATE_TASKS;;
    post_create) var_name=POST_CREATE_TASKS;;
    pre_update) var_name=PRE_UPDATE_TASKS;;
    post_update) var_name=POST_UPDATE_TASKS;;
    pre_push) var_name=PRE_PUSH_TASKS;;
    post_push) var_name=POST_PUSH_TASKS;;
    pre_diff) var_name=PRE_DIFF_TASKS;;
    post_diff) var_name=POST_DIFF_TASKS;;
    *) return 0;;
  esac
  # Indirection to read env var by name
  local tasks_string="${!var_name-}"
  (
    cd "$path"
    if [[ -n "$tasks_string" ]]; then
      _log "Running ${var_name} in $branch"
      bash -lc "$tasks_string" || _err "Tasks failed for $branch phase=$phase"
    fi
    if [[ "$RUN_PRE_COMMIT" == "true" && -x "$(command -v pre-commit || true)" ]]; then
      if [[ -f ".pre-commit-config.yaml" || -f ".pre-commit-config.yml" ]]; then
        _log "Running pre-commit in $branch"
        pre-commit run -a || _err "pre-commit issues in $branch"
      fi
    fi
  )
}

cmd_create() {
  local branches_csv="" force_rebase_start=false interactive=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches)
        branches_csv="$2"; shift 2;;
      --root)
        WORKTREES_ROOT="$2"; shift 2;;
      --interactive|-i) interactive=true; shift;;
      *) _die "Unknown option for create: $1";;
    esac
  done

  _ensure_dir "$WORKTREES_ROOT"
  git fetch --all --prune

  if $interactive; then
    local selected
    selected=$(_fzf_select_branches "$branches_csv" --multi)
    mapfile -t branches < <(printf "%s\n" "$selected")
  else
    mapfile -t branches < <(_resolve_branches "$branches_csv")
  fi
  [[ ${#branches[@]} -gt 0 ]] || _die "No branches to create worktrees for"

  local branch path
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ -d "$path/.git" || -f "$path/.git" ]]; then
      _log "Worktree already exists: $branch -> $path"
      continue
    fi
    # Ensure local branch exists
    if ! git show-ref --verify --quiet "refs/heads/${branch}"; then
      if git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
        _log "Creating local branch $branch from origin/$branch"
        git branch "$branch" "origin/${branch}"
      else
        # Create from base if not found anywhere
        local base="${BASE_BRANCH:-${DEFAULT_BASE_BRANCH}}"
        if git show-ref --verify --quiet "refs/heads/${base}"; then
          _log "Creating local branch $branch from $base"
          git branch "$branch" "$base"
        elif git show-ref --verify --quiet "refs/remotes/origin/${base}"; then
          _log "Creating local base $base from origin/$base"
          git branch "$base" "origin/${base}"
          _log "Creating local branch $branch from $base"
          git branch "$branch" "$base"
        else
          _die "Base branch ${base} not found locally or on origin"
        fi
      fi
    fi
    _log "Adding worktree for ${branch} at ${path}"
    git worktree add "$path" "$branch" >/dev/null
    (cd "$path" && _ensure_upstream "$branch")
    _run_phase_tasks pre_create "$branch" "$path"
    _run_phase_tasks post_create "$branch" "$path"
  done
}

cmd_new() {
  local branches_csv="" base="${DEFAULT_BASE_BRANCH}" do_push=false interactive=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --base) base="$2"; shift 2;;
      --push) do_push=true; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      --interactive|-i) interactive=true; shift;;
      *) _die "Unknown option for new: $1";;
    esac
  done
  _ensure_dir "$WORKTREES_ROOT"
  git fetch --all --prune
  if $interactive; then
    local input
    input=$(_fzf_select_branches "$branches_csv" --multi)
    mapfile -t branches < <(printf "%s\n" "$input")
  else
    mapfile -t branches < <(_resolve_branches "$branches_csv")
  fi
  [[ ${#branches[@]} -gt 0 ]] || _die "No branches provided to create"
  local branch path
  for branch in "${branches[@]}"; do
    if git show-ref --verify --quiet "refs/heads/${branch}" || git show-ref --verify --quiet "refs/remotes/origin/${branch}"; then
      _log "Branch $branch already exists; skipping creation"
      continue
    fi
    if ! git show-ref --verify --quiet "refs/heads/${base}"; then
      if git show-ref --verify --quiet "refs/remotes/origin/${base}"; then
        _log "Creating local base $base from origin/$base"
        git branch "$base" "origin/${base}"
      else
        _die "Base branch $base not found locally or on origin"
      fi
    fi
    _log "Creating new branch $branch from $base"
    git branch "$branch" "$base"
    path=$(_worktree_path_for "$branch")
    _log "Adding worktree for ${branch} at ${path}"
    git worktree add "$path" "$branch" >/dev/null
    (
      cd "$path"
      if $do_push || [[ "$AUTO_PUSH_NEW_BRANCHES" == "true" ]]; then
        _log "Pushing and setting upstream for $branch"
        git push -u origin "$branch"
      else
        _ensure_upstream "$branch"
      fi
    )
    _run_phase_tasks pre_create "$branch" "$path"
    _run_phase_tasks post_create "$branch" "$path"
  done
}

cmd_update() {
  local branches_csv="" rebase=false ffonly=true interactive=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --rebase) rebase=true; ffonly=false; shift;;
      --ff-only|--ffonly) ffonly=true; rebase=false; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      --interactive|-i) interactive=true; shift;;
      *) _die "Unknown option for update: $1";;
    esac
  done
  if $interactive; then
    local selected
    selected=$(_fzf_select_branches "$branches_csv" --multi)
    mapfile -t branches < <(printf "%s\n" "$selected")
  else
    mapfile -t branches < <(_resolve_branches "$branches_csv")
  fi
  local branch path
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ ! -d "$path" ]]; then
      _err "Missing worktree for $branch at $path (skipping)"
      continue
    fi
    _log "Updating $branch at $path"
    (
      cd "$path"
      git remote update --prune
      _ensure_upstream "$branch"
      _run_phase_tasks pre_update "$branch" "$path"
      if $ffonly; then
        git pull --ff-only
      elif $rebase; then
        git pull --rebase
      else
        git pull
      fi
      _run_phase_tasks post_update "$branch" "$path"
    )
  done
}

cmd_diff() {
  local branches_csv="" stat=false name_only=false color=always interactive=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --stat) stat=true; shift;;
      --name-only|--name) name_only=true; shift;;
      --no-color) color=never; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      --interactive|-i) interactive=true; shift;;
      *) _die "Unknown option for diff: $1";;
    esac
  done
  if $interactive; then
    local selected
    selected=$(_fzf_select_branches "$branches_csv" --multi)
    mapfile -t branches < <(printf "%s\n" "$selected")
  else
    mapfile -t branches < <(_resolve_branches "$branches_csv")
  fi
  local branch path upstream
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ ! -d "$path" ]]; then
      _err "Missing worktree for $branch at $path (skipping)"
      continue
    fi
    (
      cd "$path"
      upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "${branch}@{upstream}" 2>/dev/null || true)
      if [[ -z "$upstream" ]]; then upstream="origin/${branch}"; fi
      _log "Diff $branch against $upstream"
      _run_phase_tasks pre_diff "$branch" "$path"
      if $stat; then
        git -c color.ui=$color diff --stat --color "$upstream..$branch" || true
      elif $name_only; then
        git -c color.ui=$color diff --name-only "$upstream..$branch" || true
      else
        git -c color.ui=$color diff "$upstream..$branch" || true
      fi
      _run_phase_tasks post_diff "$branch" "$path"
    )
  done
}

cmd_push() {
  local branches_csv="" changed_only=false force_with_lease=false interactive=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --changed) changed_only=true; shift;;
      --force-with-lease) force_with_lease=true; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      --interactive|-i) interactive=true; shift;;
      *) _die "Unknown option for push: $1";;
    esac
  done
  if $interactive; then
    local selected
    selected=$(_fzf_select_branches "$branches_csv" --multi)
    mapfile -t branches < <(printf "%s\n" "$selected")
  else
    mapfile -t branches < <(_resolve_branches "$branches_csv")
  fi
  local branch path has_changes
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ ! -d "$path" ]]; then
      _err "Missing worktree for $branch at $path (skipping)"
      continue
    fi
    (
      cd "$path"
      _ensure_upstream "$branch"
      _run_phase_tasks pre_push "$branch" "$path"
      if $changed_only; then
        if git diff --quiet && git diff --cached --quiet; then
          _log "No changes to push for $branch"
          exit 0
        fi
      fi
      if $force_with_lease; then
        git push --force-with-lease
      else
        git push
      fi
      _run_phase_tasks post_push "$branch" "$path"
    )
  done
}

cmd_exec() {
  local branches_csv=""; local cmd=""; local shell="bash -lc"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --) shift; cmd="$*"; break;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for exec: $1";;
    esac
  done
  [[ -n "$cmd" ]] || _die "Provide a command after --"
  mapfile -t branches < <(_resolve_branches "$branches_csv")
  local branch path
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ ! -d "$path" ]]; then
      _err "Missing worktree for $branch at $path (skipping)"
      continue
    fi
    _log "Exec in $branch: $cmd"
    (
      cd "$path"
      eval $shell "$cmd"
    )
  done
}

cmd_tui() {
  # Open an interactive session (dotbare or lazygit) in a selected worktree
  local branch="" interactive=true pass_args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branch) branch="$2"; shift 2;;
      --interactive|-i) interactive=true; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      --) shift; pass_args=("$@"); break;;
      *) _die "Unknown option for tui: $1";;
    esac
  done
  if [[ -z "$branch" && $interactive == true ]]; then
    branch=$(_fzf_select_branches "")
  fi
  [[ -n "$branch" ]] || _die "No branch selected for TUI"
  local path=$(_worktree_path_for "$branch")
  [[ -d "$path" ]] || _die "Worktree not found at $path"
  if [[ "$ENABLE_DOTBARE" == "true" ]] && _has_cmd "$DOTBARE_CMD"; then
    _log "Launching dotbare in $branch"
    (
      cd "$path"
      DOTBARE_DIR="${path}/.git" DOTBARE_TREE="${path}" "$DOTBARE_CMD" "${pass_args[@]:-}"
    )
  elif _has_cmd lazygit; then
    _log "dotbare not found; launching lazygit in $branch"
    (cd "$path" && lazygit)
  else
    _die "Neither dotbare nor lazygit found. Install dotbare to enable TUI."
  fi
}

cmd_list() {
  local branches_csv=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for list: $1";;
    esac
  done
  mapfile -t branches < <(_resolve_branches "$branches_csv")
  local branch path present
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ -d "$path" ]]; then present="yes"; else present="no"; fi
    printf "% -15s  %s  %s\n" "$branch" "$present" "$path"
  done
}

cmd_status() {
  local branches_csv=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for status: $1";;
    esac
  done
  mapfile -t branches < <(_resolve_branches "$branches_csv")
  local branch path
  for branch in "${branches[@]}"; do
    path=$(_worktree_path_for "$branch")
    if [[ ! -d "$path" ]]; then
      _err "Missing worktree for $branch at $path (skipping)"
      continue
    fi
    (
      cd "$path"
      _log "Status for $branch"
      git status --short
    )
  done
}

cmd_prune() {
  _log "Pruning stale worktrees"
  git worktree prune
  _log "Validating"
  git worktree list
}

print_help() {
  cat <<EOF
Git Worktrees Manager

Usage: scripts/worktrees.sh <command> [options]

Commands:
  create [--branches "b1 b2"] [--root PATH]
  new    [--branches "b1 b2"] [--base BRANCH] [--push] [--root PATH]
  update [--branches "b1 b2"] [--ff-only|--rebase] [--root PATH]
  diff   [--branches "b1 b2"] [--stat|--name-only] [--no-color] [--root PATH]
  push   [--branches "b1 b2"] [--changed] [--force-with-lease] [--root PATH]
  exec   [--branches "b1 b2"] -- <cmd to run in each worktree>
  list   [--branches "b1 b2"] [--root PATH]
  status [--branches "b1 b2"] [--root PATH]
  prune

Env vars:
  WORKTREES_ROOT: where to place worktrees (default: <repo_root>/worktrees)
  EXCLUDE_BRANCHES: space-separated list to exclude (default: "main")
  DEFAULT_BASE_BRANCH: base branch for new branches (default: "main")
  AUTO_PUSH_NEW_BRANCHES: if "true", push new branches when created (default: "false")
  RUN_PRE_COMMIT: if "true", run pre-commit when available during tasks phases
  PRE_CREATE_TASKS, POST_CREATE_TASKS, PRE_UPDATE_TASKS, POST_UPDATE_TASKS,
  PRE_PUSH_TASKS, POST_PUSH_TASKS, PRE_DIFF_TASKS, POST_DIFF_TASKS

Examples:
  scripts/worktrees.sh create
  scripts/worktrees.sh new --branches "feature-x feature-y" --base main --push
  scripts/worktrees.sh update --rebase
  scripts/worktrees.sh diff --stat
  scripts/worktrees.sh push --changed
  scripts/worktrees.sh exec -- "npm ci && npm test"
EOF
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    create) cmd_create "$@";;
    new)    cmd_new "$@";;
    update) cmd_update "$@";;
    diff)   cmd_diff "$@";;
    push)   cmd_push "$@";;
    exec)   cmd_exec "$@";;
    list)   cmd_list "$@";;
    status) cmd_status "$@";;
    prune)  cmd_prune "$@";;
    -h|--help|help|"") print_help;;
    *) _die "Unknown command: $cmd";;
  esac
}

main "$@"
