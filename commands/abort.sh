#!/bin/bash
source "$GMP_DIR/shared.sh"

abort() {
  _abort_rebase "$@"

  $cmd list
}
