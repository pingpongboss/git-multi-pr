#!/bin/bash
source "shared.sh"

abort() {
  _abort_rebase "$@"

  $cmd list
}