#!/bin/bash
source "$GMP_DIR/shared.sh"

status() {
  local quick=false
  if [[ "$1" == "-q" ]]; then
    quick=true
  fi

  local success=true

  [[ "$(git config --global --get rerere.enabled)" == "true" ]] || {
    success=false

    echo "${bold}Missing config: git rerere${normal}"
    echo "Run:"
    echo
    echo -e "\tgit config --global rerere.enabled true"
    echo
  }

  if ! [ -x "$(command -v jq)" ]; then
    success=false

    echo "${bold}Missing dependency: jq${normal}"
    echo "On Mac OS, run:"
    echo
    echo -e "\tbrew install jq"
    echo
  fi

  if ! [ -x "$(command -v $oksh)" ]; then
    success=false

    echo "${bold}Missing dependency: ok.sh${normal}"
    echo "Run:"
    echo
    echo -e "\tmkdir -p $HOME/bin ; curl -o $HOME/bin/$oksh https://raw.githubusercontent.com/whiteinge/ok.sh/master/ok.sh ; chmod +x $HOME/bin/$oksh"
    echo
  fi

  "$success" && ("$quick" || _ensure_github_permissions || {
    success=false

    echo "${bold}Missing GitHub permissions${normal}"
    echo "Generate a token on GitHub (https://github.com/settings/tokens) with repo permissions and store it in ~/.netrc:"
    echo
    echo -e "\tmachine api.github.com"
    echo -e "\t    login <username>"
    echo -e "\t    password <token>"
    echo -e "\tmachine uploads.github.com"
    echo -e "\t    login <username>"
    echo -e "\t    password <token>"
    echo
    echo "If the repo has single sign-on enabled, you must authorize this token with SSO (https://help.github.com/articles/authorizing-a-personal-access-token-for-use-with-a-saml-single-sign-on-organization/)."
  })

  if $success; then
    echo "All required configurations and dependencies are installed."
    return 0
  else
    echo "Install the missing configurations and dependencies, and run \`$cmd status\` again."
    return 1
  fi
}

_ensure_github_permissions() {
  local repo_org="$(_get_repo_org)"
  local repo_name="$(_get_repo_name)"
  local filter='"\(.permissions.push)\t\(.permissions.pull)"'

  local response="$($oksh _get "/repos/$repo_org/$repo_name" | $oksh _filter_json "$filter")"

  local push="$(echo "$response" | cut -f1)"
  local pull="$(echo "$response" | cut -f2)"

  if [[ "$push" != "true" ]] || [[ "$pull" != "true" ]]; then
    return 1
  fi
  return 0
}
