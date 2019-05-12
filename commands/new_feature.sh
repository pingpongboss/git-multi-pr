#!/bin/bash
source "shared.sh"

new_feature() {
  if [ -z "$1" ]; then
    usage
    exit 1
  fi

  echo "Creating new branch $1"
  git checkout "origin/$master" &>/dev/null
  git checkout -b "$1"
}
