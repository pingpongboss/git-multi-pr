#!/bin/bash
source "shared.sh"

merge() {
  status &>/dev/null || {
    echo "You are missing required configurations or dependencies. Please run \`$cmd status\` to fix this."
    exit 1
  }

  local refs="$(_git_get_commits --reverse)"
  local IFS=$'\n' refs_array=($refs)
  local ref="${refs_array[0]}"

  # TODO: Check that PR base is master

  echo
  echo "${bold}Merging oldest PR onto origin/$master: $(git log -n 1 --oneline --no-decorate "$ref")${normal}"

  echo "If this is not the PR what you want to merge, then use \`$cmd edit\` to reorder your local history, or \`$cmd sync\` to sync your local queue."
  echo "${bold}Do you want to merge $ref? [y/N]:${normal} "
  read prompt

  case "$prompt" in
    y | Y)
      local repo_org="$(_get_repo_org)"
      local repo_name="$(_get_repo_name)"
      local pr_number="$(_get_ref_pr_number "$ref")"
      local pr_url="$(_get_ref_pr_url "$ref")"

      if [[ "${#refs_array[@]}" -ge 2 ]]; then
        local next_ref="${refs_array[1]}"
        _ensure_ref_pr_open "origin/$master" "$next_ref"
      fi

      echo "> $oksh add_comment \"$repo_org/$repo_name\" \"$pr_number\" \":unlock: Merging via \`$cmd merge\`\""
      $oksh add_comment "$repo_org/$repo_name" "$pr_number" ":unlock: Merging via \`$cmd merge\`"

      echo "> $oksh add_comment \"$repo_org/$repo_name\" \"$pr_number\" \":dash:\""
      $oksh add_comment "$repo_org/$repo_name" "$pr_number" ":dash:"

      echo "Check ${underline}$pr_url${normal} for the status on your merge."
      echo "When it is merged into master, sync your local queue with \`$cmd sync\`."
      echo "Any subsequent PRs will have invalid diffs until you export again with \`$cmd export\`."
      ;;
    *)
      echo "Merge cancelled. Exiting."
      return 1
      ;;
  esac
}
