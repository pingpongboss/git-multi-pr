#!/bin/bash
source "shared.sh"

list() {
  local branch="$(_git_get_branch)"
  local commits="$(_git_get_commits)"
  local IFS=$'\n' commits_array=($commits)
  local count="${#commits_array[@]}"

  echo
  echo "Local changes for $branch:"

  if [ "$count" -eq 0 ]; then
    echo "All of your commits have already landed on origin/$master."
  else
    local output="$(_print_augmented_queue "$commits")"
    echo "$output"
  fi
}

_print_augmented_queue() {
  local commits="$1"
  local IFS=$'\n' commits_array=($commits)

  for commit in "${commits_array[@]}"; do
    local url="$(_get_ref_pr_url "$commit")"

    local sha_format="%C(yellow)%h"
    if [ -z "$url" ]; then
      local url_format=""
    else
      local url_format=" %C(reset)%C(ul)$url%C(noul)"
    fi
    local ref_format="%C(green bold)%d"
    local subject_format="%C(reset)%s"

    echo "$(git log -n 1 --color --pretty=format:"$sha_format$url_format$ref_format $subject_format" "$commit")"
  done
}
