#!/bin/bash
source "$GMP_DIR/shared.sh"

export_() {
  _git_check_clean_state || { echo "Your branch has uncommitted changes or is in rebase. Cancelling."; return 1; }

  local branch="$(_git_get_branch)"
  local commits="$(_git_get_commits)"
  local IFS=$'\n' commits_array=($commits)

  # For each commit in the queue (oldest first), create a hidden branch and PR.
  local count="${#commits_array[@]}"
  local i="$(($count-1))"

  local prev_ref_branch="origin/$master"
  while [ $i -ge 0 ]; do
    local ref="HEAD~$i"
    local sha="$(_get_sha_in_local_queue "$ref")"

    # Break on first WIP commit.
    local subject="$(_git_get_commit_subject "$ref")"
    if [[ "$subject" == "WIP"* ]]; then
      echo
      echo "${bold}Found WIP commit at $ref: $subject${normal}"
      echo "Stopping."
      break
    fi

    # Break if commit PR is already merged.
    local pr_number="$(_get_ref_pr_number "$ref")"
    if [ ! -z "$pr_number" ] && _is_pr_merged "$pr_number"; then
      echo "${bold}Detected merged PR #$pr_number for $ref ($sha): $subject${normal}"
      echo "Please run \`$cmd sync\` first to remove the PR from your local queue."
      echo "Stopping."
      break
    fi

    echo "${bold}Exporting $ref ($sha): $subject${normal}"

    # Create/update hidden branch.
    local ref_branch="$(_generate_ref_branch_name "$ref")"
    echo "Will use hidden branch $ref_branch for $ref."
    _create_or_update_ref_branch "$prev_ref_branch" "$ref_branch" "$ref"

    # Create/update PR.
    _create_or_update_ref_pr "$prev_ref_branch" "$ref_branch" "$ref"

    i="$(($i-1))"
    prev_ref_branch="$ref_branch"
    git checkout "$branch" &>/dev/null
    echo
    echo
  done

  git checkout "$branch" &>/dev/null

  $cmd list
}

_generate_ref_branch_name() {
  local ref="$1"

  local ref_branch="$(_get_ref_branch_name "$ref")"
  if [[ ! -z "$ref_branch" ]]; then
    echo "$ref_branch"
    return 0
  fi

  # Prefix.
  ref_branch="$REF_BRANCH_PREFIX"

  # Pick a few words from the subject.
  local subject="$(_git_get_commit_subject "$ref")"
  subject="$(echo "$subject" | tr ' ' '\n')"
  local IFS=$'\n' words=($subject)

  local num=0
  for word in "${words[@]}"; do
    word="$(echo "$word" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]')"
    ref_branch="$ref_branch-$word"

    num=$((num + 1))
    if [ "$num" -ge "3" ]; then
      break
    fi
  done

  # Suffix.
  ref_branch="$ref_branch-$(uuidgen)"

  echo "$ref_branch"
}

_create_or_update_ref_branch() {
  local prev_ref_branch="$1"
  local ref_branch="$2"
  local ref="$3"

  local branch="$(_git_get_branch)"


  if _git_verify_branch "$ref_branch"; then
    _update_ref_branch "$prev_ref_branch" "$ref_branch" "$ref"
  else
    _create_ref_branch "$prev_ref_branch" "$ref_branch" "$ref"
  fi

  _push_ref_branch "$prev_ref_branch" "$ref_branch" "$ref" "$branch"

  git checkout "$branch" &>/dev/null
}

_update_ref_branch() {
  local prev_ref_branch="$1"
  local ref_branch="$2"
  local ref="$3"

  local sha="$(_get_sha_in_local_queue "$ref")"

  echo "Updating hidden branch $ref_branch for $ref ($sha)."
  git checkout "$ref_branch" &>/dev/null

  git merge "$prev_ref_branch" --no-edit  &>/dev/null

  git diff HEAD.."$sha" | git apply --index &>/dev/null

  _commit_to_new_snapshot
}

_get_relative_non_merge_commits_count() {
  local prev_ref_branch="$1"

  local count=0

  local commits="$(_git_get_relative_commits "$prev_ref_branch")"
  for commit in $commits; do
    if ! _git_is_merge_commit "$commit"; then
      ((count++))
    fi
  done

  echo "$count"
}

_create_ref_branch() {
  local prev_ref_branch="$1"
  local ref_branch="$2"
  local ref="$3"

  _remove_ref_commit_message "$ref" "$KEY_GIT_MULTI_BRANCH="
  _append_ref_commit_message "$ref" "$KEY_GIT_MULTI_BRANCH=$ref_branch"

  local sha="$(_get_sha_in_local_queue "$ref")"

  echo "Creating hidden branch $ref_branch for $ref ($sha)."
  git checkout "$prev_ref_branch" &>/dev/null
  git checkout -b "$ref_branch" &>/dev/null

  git diff HEAD.."$sha" | git apply --index &>/dev/null

  _commit_to_new_snapshot
}

_commit_to_new_snapshot() {
  if _git_check_clean_state; then
    echo "No changes detected."
  else
    local count="$(_get_relative_non_merge_commits_count "$prev_ref_branch")"

    echo "Changes detected. Adding to ${bold}Snapshot $((count+1))${normal}."

    git add . &>/dev/null
    git commit -m "Snapshot $((count+1))" &>/dev/null
  fi
}

_push_ref_branch() {
  local prev_ref_branch="$1"
  local ref_branch="$2"
  local ref="$3"

  local sha="$(_get_sha_in_local_queue "$ref")"

  _ensure_ref_pr_open "$prev_ref_branch" "$sha"

  local remote_branch="$(_get_remote_ref_branch "$ref_branch")"
  echo "Pushing hidden branch $ref_branch to origin/$remote_branch."
  git push origin "$ref_branch:$remote_branch" &>/dev/null
}

_append_ref_commit_message() {
  local ref="$1"
  local message="$2"

  echo "Adding $message to commit message of $ref."
  _edit_ref "$ref" &>/dev/null
  # Ensure only one single empty line before $message.
  git filter-branch -f --msg-filter "$cmd _ref_commit_message_helper append $message" HEAD~..HEAD &>/dev/null
  _continue_rebase &>/dev/null
}

_remove_ref_commit_message() {
  local ref="$1"
  local message="$2"

  echo "Removing $message from commit message of $ref."
  _edit_ref "$ref" &>/dev/null
  git filter-branch -f --msg-filter "$cmd _ref_commit_message_helper remove $message" HEAD~..HEAD &>/dev/null
  _continue_rebase &>/dev/null
}

_ref_commit_message_helper() {
  local operation="$1"
  local message="$2"
  local commit="$(cat)"

  local empty_lines=0
  local encountered_metadata=false

  while IFS=$'\n' read line; do
    if [ -z "$line" ]; then
      empty_lines="$(($empty_lines+1))"
      continue
    fi

    if [[ "$operation" == "remove" ]] && [[ "$line" == "$message"* ]]; then
      continue
    fi

    if [[ "$line" =~ ^[A-Z_]+= ]]; then
      if $encountered_metadata ; then
        empty_lines=0
      else
        empty_lines=1
      fi

      encountered_metadata=true
    fi

    if [[ "$empty_lines" -ne "0" ]]; then
      printf '\n%.0s' {1..$empty_lines}
    fi
    echo "$line"
  done < <(echo "$commit")

  if [[ "$operation" == "append" ]]; then
    if ! $encountered_metadata ; then
      echo
    fi
    echo "$message"
  fi
}

_create_or_update_ref_pr() {
  echo
  echo "Creating or updating PR for $ref_branch."

  local prev_ref_branch="$1"
  local ref_branch="$2"
  local ref="$3"

  local repo_org="$(_get_repo_org)"
  local repo_name="$(_get_repo_name)"
  local pr_number="$(_get_ref_pr_number "$ref")"

  local title="$(_git_get_commit_subject "$ref")"
  local body="$(_git_get_commit_body "$ref")"
  body="$(echo "$body" | $cmd _ref_commit_message_helper remove "$KEY_GIT_MULTI_BRANCH=" | $cmd _ref_commit_message_helper remove "$KEY_PR=")"

  # Sanitize.
  title="$(_escape "$title")"
  body="$(_escape "$body")"

  if [[ "$prev_ref_branch" == "origin/$master" ]]; then
    local prev_remote_branch="$master"
  else
    local prev_remote_branch="$(_get_remote_ref_branch "$prev_ref_branch")"
  fi
  local remote_branch="$(_get_remote_ref_branch "$ref_branch")"

  if [ -z "$pr_number" ]; then
    echo "Did not find existing PR # for $ref_branch."

    echo "> $oksh \"create_pull_request\" \"$repo_org/$repo_name\" \"$title\" \"$remote_branch\" \"$prev_remote_branch\" body=\"$body\""
    local response="$($oksh create_pull_request "$repo_org/$repo_name" "$title" "$remote_branch" "$prev_remote_branch" body="$body")"
    pr_number="$(echo "$response" | cut -f1)"

    if [ ! -z "$pr_number" ]; then
      _remove_ref_commit_message "$ref" "$KEY_PR="
      _append_ref_commit_message "$ref" "$KEY_PR=$pr_number"

      echo "> $oksh add_comment \"$repo_org/$repo_name\" \"$pr_number\" \":lock: PR author to merge via \`$cmd merge\`\""
      $oksh add_comment "$repo_org/$repo_name" "$pr_number" ":lock: PR author to merge via \`$cmd merge\`"
    else
      echo "\nFailed to create pull request."
      echo "Manually check if a new PR was created. If it was, copy the PR number, and manually amend the commit message with:"
      echo "$KEY_PR=[PR_NUMBER]"
      return 1
    fi
  else
    echo "Found existing PR #$pr_number for $ref_branch."

    echo "> $oksh update_pull_request \"$repo_org/$repo_name\" \"$pr_number\" title=\"$title\" body=\"$body\" base=\"$prev_remote_branch\" state=\"open\""
    $oksh update_pull_request "$repo_org/$repo_name" "$pr_number" title="$title" body="$body" base="$prev_remote_branch" state="open" &>/dev/null
  fi

  local url="$(_get_ref_pr_url "$ref")"
  if [ ! -z "$url" ]; then
    echo "${underline}$url${normal}"
  fi
}
