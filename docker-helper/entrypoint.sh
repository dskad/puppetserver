#!/usr/bin/bash

shopt -s nocasematch
set -eo pipefail
if [[ -v DEBUG ]]; then set -x; fi

if [[ "$2" = "foreground" ]]; then
  for f in /entrypoint.d/*.sh; do
    echo "Running $f"
    chmod +x "$f"
    "$f"
  done
  echo 'Starting puppet server...'
fi
## Pass control on to the command supplied on the CMD line of the Dockerfile
## This makes puppetserver PID 1
exec "$@"
