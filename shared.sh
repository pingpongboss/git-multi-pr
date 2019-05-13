#!/bin/bash

master="master"

bold=$(tput bold)
underline=$(tput smul)
normal=$(tput sgr0)

cmd="git-multi-pr"
oksh="$HOME/bin/ok.sh"

REF_BRANCH_PREFIX="_git-multi-pr-"
KEY_GIT_MULTI_BRANCH="GIT_MULTI_BRANCH"
KEY_PR="PR"

_get_ref_pr_url() {
  local ref="$1"

  local pr_number="$(_get_ref_pr_number "$ref")"

  if [[ ! -z "$pr_number" ]]; then
    local repo_org="$(_get_repo_org)"
    local repo_name="$(_get_repo_name)"

    echo "https://github.com/$repo_org/$repo_name/pull/$pr_number"
  fi
}

_get_ref_pr_number() {
  local ref="$1"
  local body="$(_git_get_commit_body "$ref")"
  echo "$body" | while read -r line; do
    if [[ "$line" == "$KEY_PR="* ]]; then
      echo "${line#"$KEY_PR="}"
      break
    fi
  done
}

_git_get_branch() {
  git symbolic-ref --short -q $@ HEAD
}

_git_get_commits() {
  git rev-list --abbrev-commit $@ "origin/$master"..
}

_git_get_relative_commits() {
  git rev-list --abbrev-commit "$@"..
}

_git_get_commit_sha() {
  if [ -z "$1" ]; then
    $cmd usage
    exit 1
  fi

  git rev-parse --short $@ 2>/dev/null
}

_git_get_commit_subject() {
  if [ -z "$1" ]; then
    $cmd usage
    exit 1
  fi

  git log -n 1 --pretty=format:%s $@
}

_git_get_commit_body() {
  if [ -z "$1" ]; then
    $cmd usage
    exit 1
  fi

  git log -n 1 --pretty=format:%b $@
}

_git_check_clean_state() {
  git diff-index --quiet $@ HEAD --
}

_git_check_rebase_state() {
  (test -d "$(git rev-parse --git-path rebase-merge)" ||  \
    test -d "$(git rev-parse --git-path rebase-apply)" ) \
  || return 1

  return 0
}

_git_verify_branch() {
  git rev-parse --verify $@ &>/dev/null
}

_get_sha_in_local_queue() {
  local ref="$1"
  local upper_ref="$(echo "$ref" | tr '[:lower:]' '[:upper:]')"

  if [[ "$upper_ref" == "BASE" ]] || [[ "$upper_ref" == "BASE+"* ]]; then
    local count="$(_git_get_commits | wc -l)"

    if [[ "$upper_ref" == "BASE" ]]; then
      local index="0"
    else
      local index="${ref#BASE+}"
      if [[ -z "$index" ]]; then
        index="1"
      fi
    fi

    ref="HEAD~$(($count - $index - 1))"
  fi

  ref="$(_git_get_commit_sha "$ref")"

  if [[ ! -z "$ref" ]] && ! _is_local_ref "$ref"; then
    echo "ref $1 is not a local commit in your queue." 1>&2
    echo "Run \`$cmd queue\` to find a local commit, or use a relative ref like HEAD~." 1>&2
    exit 1
  fi

  echo "$ref"
}

_edit_ref() {
  if [ -z "$1" ]; then
    git rebase -i "origin/$master"
    return 0
  fi

  local sha="$(_get_sha_in_local_queue "$1")"
  local rebase_command="edit"
  if [ $# -ge 2 ]; then
      rebase_command="$2"
  fi

  echo "Entering rebase for $1 == $sha with command $rebase_command."
  # Replace "pick $sha" and "# pick $sha" with "$rebase_command $sha".
  local regex="'s/^\(# \)\{0,1\}pick $sha/$rebase_command $sha/'"
  GIT_SEQUENCE_EDITOR="sed -i -e $regex" git rebase -i "origin/$master" &>/dev/null
}

_continue_rebase() {
  echo "Exiting rebase."
  git rebase --continue
}

_abort_rebase() {
  echo "Aborting rebase."
  git rebase --abort
}

_is_local_ref() {
  local refs="$(_git_get_commits)"
  for ref in $refs; do
    if [ "$ref" == "$1" ]; then
      return 0
    fi
  done

  return 1
}

_get_remote_ref_branch() {
  local ref_branch="$1"

  local email="$(git config user.email)"
  local username="${email%@*}"

  echo "$username$ref_branch"
}

_escape() {
  # TODO: I can't get this to escape correctly for the following commit message:
  # Hello, world! \"
  echo "$1" | tr '\' '\\' | tr '$' '\$' | tr '`' '\`' | tr '"' '\"' | tr '[' '(' | tr ']' ')'
}

_ensure_ref_pr_open() {
  local prev_ref_branch="$1"
  local ref="$2"

  local repo_org="$(_get_repo_org)"
  local repo_name="$(_get_repo_name)"
  local pr_number="$(_get_ref_pr_number "$ref")"

  if [[ "$prev_ref_branch" == "origin/$master" ]]; then
    local prev_remote_branch="$master"
  else
    local prev_remote_branch="$(_get_remote_ref_branch "$prev_ref_branch")"
  fi

  if [ ! -z "$pr_number" ]; then
    echo "Ensuring that the PR is open."
    # The PR's base must be set to an open branch, or else the PR may become closed forever.
    # https://github.com/isaacs/github/issues/361
    echo "> $oksh update_pull_request \"$repo_org/$repo_name\" \"$pr_number\" base=\"$prev_remote_branch\""
    $oksh update_pull_request "$repo_org/$repo_name" "$pr_number" base="$prev_remote_branch" &>/dev/null
    echo "> $oksh update_pull_request \"$repo_org/$repo_name\" \"$pr_number\" state=\"open\""
    $oksh update_pull_request "$repo_org/$repo_name" "$pr_number" state="open" &>/dev/null
  fi
}

_get_repo_org() {
  # Take the repo url.
  local repo_url="$(git remote get-url --push origin)"
  # Remove the extension.
  repo_url="${repo_url%.git}"
  # Convert : and / to new lines.
  repo_url="$(echo "$repo_url" | tr ':' '\n' | tr '/' '\n')"
  # Split into array.
  local IFS=$'\n' repo_components=($repo_url)
  local count="${#repo_components[@]}"

  local repo_org_index="$(($count-2))"
  echo "${repo_components[$repo_org_index]}"
}

_get_repo_name() {
  # Take the repo url.
  local repo_url="$(git remote get-url --push origin)"
  # Remove the extension.
  repo_url="${repo_url%.git}"
  # Convert : and / to new lines.
  repo_url="$(echo "$repo_url" | tr ':' '\n' | tr '/' '\n')"
  # Split into array.
  local IFS=$'\n' repo_components=($repo_url)
  local count="${#repo_components[@]}"

  local repo_name_index="$(($count-1))"
  echo "${repo_components[$repo_name_index]}"
}

_get_ref_branch_name() {
  local ref="$1"
  local body="$(_git_get_commit_body "$ref")"
  echo "$body" | while read -r line; do
    if [[ "$line" == "$KEY_GIT_MULTI_BRANCH="* ]]; then
      echo "${line#"$KEY_GIT_MULTI_BRANCH="}"
      break
    fi
  done
}

_git_is_merge_commit () {
    local sha="$1"

    local merge_sha=$(git rev-list -1 --merges ${sha}~1..${sha})
    [ -z "$merge_sha" ] && return 1
    return 0
}
