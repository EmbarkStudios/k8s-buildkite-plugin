#!/bin/bash
set -xeuo pipefail

git config --global credential.helper "store --file=/secrets/git-credentials"

if [[ -f /secrets/ssh-key ]]; then
  eval "$(ssh-agent -s)"
  ssh-add -k /secrets/ssh-key
fi

/usr/local/bin/buildkite-agent "$@"
