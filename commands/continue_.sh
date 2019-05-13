#!/bin/bash
source "$GMP_DIR/shared.sh"

continue_() {
  _continue_rebase "$@"

  # Detect conflict.
  _git_check_clean_state || {
    echo "Resolve the conflicts and continue the rebase again."
    return 0
  }

  $cmd list
}
