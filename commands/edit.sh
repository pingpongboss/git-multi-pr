#!/bin/bash
source "$GMP_DIR/shared.sh"

edit() {
  _edit_ref "$@"

  if _git_check_rebase_state; then
    echo
    echo "Remember to call \`$cmd continue\` after you make your changes, or \`$cmd abort\` to cancel."
  fi
}
