# Kubernetes Buildkite Plugin

[![Build Status](https://badge.buildkite.com/c061bcad854e7a95c03d1baebfab8a01dc25768dab272dd8e5.svg)](https://buildkite.com/embark-studios/k8s-buildkite-plugin)

An opinionated [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps as [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/) on a cluster with minimal effort.

The plugin tries to stay reasonably compatible with the [Docker plugin](https://github.com/buildkite-plugins/docker-buildkite-plugin) to make it easy to change pipelines to run on a cluster. It also takes lots of inspiration from the [kustomize-job-buildkite-plugin](https://github.com/MYOB-Technology/kustomize-job-buildkite-plugin).

## Example

```yaml
steps:
  - command: "echo 'Hello, World!'"
    plugins:
      - EmbarkStudios/k8s:
          image: alpine
```

If you want to control how your command is passed to the container, you can use the `command` parameter on the plugin directly:

```yaml
steps:
  - plugins:
      - EmbarkStudios/k8s:
          image: "embarkstudios/fortune"
          always-pull: true
          command: ["startrek"]
```

You can pass in additional environment variables, including values from a [Secret](https://kubernetes.io/docs/concepts/configuration/secret/):

```yaml
steps:
  - command:
      - "yarn install"
      - "yarn run test"
    plugins:
      - EmbarkStudios/k8s:
          image: "node:7"
          environment:
            - "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens"
          environment-from-secret:
            - "kitten-secrets"
```

## Configuration

### Required

### `image` (required, string)

The name of the container image to use.

Example: `golang:1.12.5`

### Optional

### `always-pull` (optional, boolean)

Whether to always pull the latest image before running the command. Sets [imagePullPolicy](https://kubernetes.io/docs/concepts/containers/images/#updating-images) on the container. If `false`, the value `IfNotPresent` is used. 

Default: `false`

### `command` (optional, array)

Sets the command for the container. Useful if the container image has an entrypoint, but requires extra arguments.

Note that [this has different meaning than in Docker](https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#notes). This sets the `args` field for the Container.

This option can't be used if your step already has a top-level, non-plugin `command` option present.

Examples: `[ "/bin/mycommand", "-c", "test" ]`, `["arg1", "arg2"]`

### `entrypoint` (optional, string)

Override the image’s default entrypoint.

Note that [this has different meaning than in Docker](https://kubernetes.io/docs/tasks/inject-data-application/define-command-argument-container/#notes). This sets the `command` field for the Container.

Example: `/my/custom/entrypoint.sh`

### `environment` (optional, array)

An array of additional environment variables to pass into to the docker container. Items can be specified as `KEY=value`. 

Example: `[ "FOO=bar", "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens" ]`

### `environment-from-secret` (optional, string or array)

One or more [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) that should be added to the container as environment variables. Each key in the secret will be exposed as an environment variable. If specified as an array, all listed secrets will be added in order.

Example: `my-secrets`

### `init-image` (optional, string)

Override the [job initContainer](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/). A buildkite-agent binary is expected to exist to do the checkout, along with git and ssh. The default is to use a public image based on the Dockerfile in this repository.

Example: `embarkstudios/k8s:1.0.0`

### `privileged` (optional, boolean)

Wether to run the container in [privileged mode](https://kubernetes.io/docs/concepts/workloads/pods/pod/#privileged-mode-for-pod-containers).

### `secret-name` (optional, string)

The name of the secret containing the buildkite agent token and, optionally, ssh or git credentials used for bootstrapping in the init container.

### `agent-token-secret-key` (optional, string)

The key of the secret value containing the buildkite agent token, within the secret specified in `secret-name`.

### `git-credentials-secret-name` (optional, string)

The name of the secret containing the git credentials used for checking out source code with HTTPS.

### `git-credentials-secret-key` (optional, string)

The key of the secret value containing the git credentials used for checking out source code with HTTPS.

The contents of this file will be used as the [git credential store](https://git-scm.com/docs/git-credential-store) file.

### `git-ssh-secret-name` (optional, string)

The name of the secret containing the git credentials used for checking out source code with SSH.

### `git-ssh-secret-key` (optional, string)

The key of the secret value containing the SSH key used when checking out source code with SSH as transport.

### `mount-secret` (optional, string or array)

Mount a secret as a directory inside the container. Must be in the form of `secretName:/some/mount/path`.
Multiple secrets may be mounted by specifying a list of secret/mount pairs.

Example: `my-secret:/my/secret`

### `build-path-host-path` (optional, string)

Optionally mount a [host path](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath) to be used as base directory for buildkite builds. This allows local caching and incremental builds using fast local storage.

Should be used with some care, since the actual storage used is outside the control of Kubernetes itself.

Example: `/var/lib/buildkite/builds`

### `build-path-pvc` (optional, string)

Optionally mount an existing [Persistent Volume Claim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) used as backing storage for the build.

### `workdir` (optional, string)

Override the working directory to run the command in, inside the container. The default is the build directory where the buildkite bootstrap and git checkout runs.

### `patch` (optional, string)

(Advanced / hack use). Provide a [jsonnet](https://jsonnet.org/) function to transform the resulting job manifest.

Example:
```
function(job) job {
  metadata: {
    labels: job.metadata.labels {
      foo: 'some extra label value',
    },
  },
}
```

## License

Apache 2.0 (see [LICENSE](LICENSE))
