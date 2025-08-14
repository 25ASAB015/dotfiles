#!/usr/bin/env bash

set -euo pipefail

# Git Worktrees Manager
#
# Features:
# - create: Create a worktree per branch (defaults to all local branches except main)
# - update: Fetch/pull each worktree (ff-only by default, --rebase optional)
# - diff:   Show diffs vs upstream (origin/<branch> by default)
# - push:   Push all or only changed branches
# - list:   List branches and their worktree paths
# - status: Show short status per worktree
# - prune:  Prune stale worktrees and verify
#
# Configuration via env vars (override as needed):
#   WORKTREES_ROOT: where to place worktrees (default: <repo_root>/worktrees)
#   EXCLUDE_BRANCHES: space-separated branches to exclude (default: "main")
#
# Usage examples:
#   scripts/worktrees.sh create                    # create for all branches except main
#   scripts/worktrees.sh create --branches "dev Aline"
#   scripts/worktrees.sh update --rebase
#   scripts/worktrees.sh diff --stat
#   scripts/worktrees.sh push --changed
#   scripts/worktrees.sh list
#   scripts/worktrees.sh status
#   scripts/worktrees.sh prune

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "${REPO_ROOT}"

WORKTREES_ROOT="${WORKTREES_ROOT:-${REPO_ROOT}/worktrees}"
EXCLUDE_BRANCHES_DEFAULT=(main)

_log() { printf "[worktrees] %s\n" "$*"; }
_err() { printf "[worktrees][error] %s\n" "$*" 1>&2; }
_die() { _err "$*"; exit 1; }

_ensure_dir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
  fi
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

cmd_create() {
  local branches_csv="" force_rebase_start=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches)
        branches_csv="$2"; shift 2;;
      --root)
        WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for create: $1";;
    esac
  done

  _ensure_dir "$WORKTREES_ROOT"
  git fetch --all --prune

  mapfile -t branches < <(_resolve_branches "$branches_csv")
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
        _die "Branch ${branch} not found locally or on origin"
      fi
    fi
    _log "Adding worktree for ${branch} at ${path}"
    git worktree add "$path" "$branch" >/dev/null
    (cd "$path" && _ensure_upstream "$branch")
  done
}

cmd_update() {
  local branches_csv="" rebase=false ffonly=true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --rebase) rebase=true; ffonly=false; shift;;
      --ff-only|--ffonly) ffonly=true; rebase=false; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for update: $1";;
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
    _log "Updating $branch at $path"
    (
      cd "$path"
      git remote update --prune
      _ensure_upstream "$branch"
      if $ffonly; then
        git pull --ff-only
      elif $rebase; then
        git pull --rebase
      else
        git pull
      fi
    )
  done
}

cmd_diff() {
  local branches_csv="" stat=false name_only=false color=always
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --stat) stat=true; shift;;
      --name-only|--name) name_only=true; shift;;
      --no-color) color=never; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for diff: $1";;
    esac
  done
  mapfile -t branches < <(_resolve_branches "$branches_csv")
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
      if $stat; then
        git -c color.ui=$color diff --stat --color "$upstream..$branch" || true
      elif $name_only; then
        git -c color.ui=$color diff --name-only "$upstream..$branch" || true
      else
        git -c color.ui=$color diff "$upstream..$branch" || true
      fi
    )
  done
}

cmd_push() {
  local branches_csv="" changed_only=false force_with_lease=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --branches) branches_csv="$2"; shift 2;;
      --changed) changed_only=true; shift;;
      --force-with-lease) force_with_lease=true; shift;;
      --root) WORKTREES_ROOT="$2"; shift 2;;
      *) _die "Unknown option for push: $1";;
    esac
  done
  mapfile -t branches < <(_resolve_branches "$branches_csv")
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
    )
  done
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
  update [--branches "b1 b2"] [--ff-only|--rebase] [--root PATH]
  diff   [--branches "b1 b2"] [--stat|--name-only] [--no-color] [--root PATH]
  push   [--branches "b1 b2"] [--changed] [--force-with-lease] [--root PATH]
  list   [--branches "b1 b2"] [--root PATH]
  status [--branches "b1 b2"] [--root PATH]
  prune

Env vars:
  WORKTREES_ROOT: where to place worktrees (default: <repo_root>/worktrees)
  EXCLUDE_BRANCHES: space-separated list to exclude (default: "main")

Examples:
  scripts/worktrees.sh create
  scripts/worktrees.sh update --rebase
  scripts/worktrees.sh diff --stat
  scripts/worktrees.sh push --changed
EOF
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    create) cmd_create "$@";;
    update) cmd_update "$@";;
    diff)   cmd_diff "$@";;
    push)   cmd_push "$@";;
    list)   cmd_list "$@";;
    status) cmd_status "$@";;
    prune)  cmd_prune "$@";;
    -h|--help|help|"") print_help;;
    *) _die "Unknown command: $cmd";;
  esac
}

main "$@"


