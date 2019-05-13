#!/bin/bash
source "$GMP_DIR/shared.sh"

sync() {
  _git_check_clean_state || { echo "Your branch has uncommitted changes or is in rebase. Cancelling."; return 1; }

  echo "Syncing..."
  git fetch --all --prune &>/dev/null
  git rebase "origin/$master"
}
