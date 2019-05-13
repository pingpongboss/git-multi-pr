#!/bin/bash
source "$GMP_DIR/shared.sh"

continue_() {
  _git_check_clean_state || { echo "Your branch has uncommitted changes or is in rebase. Cancelling."; return 1; }

  _continue_rebase "$@"

  # Detect conflict.
  _git_check_clean_state || {
    echo "Resolve the conflicts and continue the rebase again."
    return 0
  }

  $cmd list
}
