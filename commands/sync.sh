#!/bin/bash
source "shared.sh"

sync() {
  echo "Syncing..."
  git fetch --all --prune &>/dev/null
  git rebase "origin/$master"
}
