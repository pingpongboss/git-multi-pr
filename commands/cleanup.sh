#!/bin/bash
source "$GMP_DIR/shared.sh"

cleanup() {
  local prefix="$REF_BRANCH_PREFIX"

  local current_branch="$(_git_get_branch)"
  local obsolete_branches=()

  # Ensure clean branch.
  _git_check_clean_state || { echo "$current_branch has uncommitted changes. Exiting."; return 1; }

  echo "Searching for obsolete branches..."

  # Step 1: For each non-hidden branch, go through every local commit and mark every referenced
  # hidden branch as visited.
  local visited_branches=()
  for branch in $(git for-each-ref --format='%(refname:short)' refs/heads/); do
    if [[ "$branch" == "$prefix"* ]]; then
      continue
    fi

    git checkout "$branch" &>/dev/null
    local commits="$(_git_get_commits)"
    for commit in $commits; do
      local ref_branch="$(_get_ref_branch_name "$commit")"
      if [[ ! -z "$ref_branch" ]]; then
        visited_branches+=("$ref_branch")
      fi
    done
  done

  # Step 2: For each hidden branch, check if it was previously visited. Hidden that were not visited
  # will be deleted in the next step.
  for branch in $(git for-each-ref --format='%(refname:short)' "refs/heads/$prefix*"); do
    if ! _contains_element "$branch" "${visited_branches[@]}"; then
      obsolete_branches+=("$branch")
    fi
  done

  # Step 3: Delete obsolete branches.
  if [ "${#obsolete_branches[@]}" -eq 0 ]; then
    echo "Didn't find any obsolete branches."
    git checkout "$current_branch" &>/dev/null
    return 0
  fi

  echo "Found obsolete branches:"
  printf '\t%s\n' "${obsolete_branches[@]}"

  for branch in "${obsolete_branches[@]}"; do
    echo
    echo "Cleaning up $branch..."
    git push origin -d "$(_get_remote_ref_branch "$branch")"
    git branch -D "$branch"
  done

  git checkout "$current_branch" &>/dev/null
}

_contains_element () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}
