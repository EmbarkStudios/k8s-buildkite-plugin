#!/bin/bash
set -xeuo pipefail

git config --global credential.helper "store --file=/secrets/git-credentials"

if [[ -f /secrets/ssh-key ]]; then
  eval "$(ssh-agent -s)"
  ssh-add -k /secrets/ssh-key
fi

if [[ -d /local ]]; then
  cp /usr/local/bin/buildkite-agent /local/
fi

exec /usr/local/bin/buildkite-agent "$@"
