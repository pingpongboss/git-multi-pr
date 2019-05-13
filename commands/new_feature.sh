#!/bin/bash
source "$GMP_DIR/shared.sh"

new_feature() {
  if [ -z "$1" ]; then
    usage
    exit 1
  fi

  local branch="$1"

  if _git_verify_branch "$branch"; then
    git checkout "$branch"
  else
    echo "Creating new branch $branch"
    git checkout "origin/$master" &>/dev/null
    git checkout -b "$branch"
  fi
}
