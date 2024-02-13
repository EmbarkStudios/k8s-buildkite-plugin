# Wrapper for kubectl invocations that prints errors in meaningful way including the kubectl command that was run
# Otherwise you might see random kubectl errors in your Builkite log without knowing that it came from the kubectl invocation
# Like "error: You must be logged in to the server (Unauthorized)" appearing in the middle or your build logs.
function kubectl_wrapper() {
  local stderr_file=$(mktemp)

  set +e
  kubectl "$@" 2>"$stderr_file"
  local kubectl_exit_code=$?
  set -e

  if [[ "$kubectl_exit_code" != "0" ]]; then
    echo "Error executing 'kubectl $@':" >&2
    cat "$stderr_file" >&2
  fi

  rm -f "$stderr_file"

  return "$kubectl_exit_code"
}