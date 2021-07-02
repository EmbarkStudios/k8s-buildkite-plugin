# Kubernetes Buildkite Plugin

[![Build Status](https://badge.buildkite.com/c061bcad854e7a95c03d1baebfab8a01dc25768dab272dd8e5.svg)](https://buildkite.com/embark-studios/k8s-buildkite-plugin)
[![Contributor Covenant](https://img.shields.io/badge/contributor%20covenant-v1.4%20adopted-ff69b4.svg)](CODE_OF_CONDUCT.md)
[![Embark](https://img.shields.io/badge/embark-open%20source-blueviolet.svg)](https://github.com/EmbarkStudios)

An opinionated [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps as [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/) on a cluster with minimal effort.

The plugin tries to stay reasonably compatible with the [Docker plugin](https://github.com/buildkite-plugins/docker-buildkite-plugin) to make it easy to change pipelines to run on a cluster. It also takes lots of inspiration from the [kustomize-job-buildkite-plugin](https://github.com/MYOB-Technology/kustomize-job-buildkite-plugin).

## Quirks & Issues

Since the step isn't actually performed by the build-agent itself, but in a separately scheduled (and isolated) container, a few things don't work as on a "normal" build-agent.

The build step container will have the `buildkite-agent` binary mounted at `/usr/local/bin/buildkite-agent` to allow using the agent subcommands for annotations, metadata and artifacts directly.

This behavior may be disabled by setting `mount-buildkite-agent: false` in the pipeline.

> ** Note: ** The user is responsible for making sure the container specified in `image` contains any external dependencies required by the otherwise statically linked buildkite-agent binary. This includes certificate authorities, and possibly git and ssh depending on how it's being used.

### Build artifacts

As the build-agent doesn't run in the same container as the actual commands, automatic upload of artifacts specified in `artifact_paths` won't work.
A workaround to this is to run `buildkite-agent artifact upload ...` as a command in the step itself.


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

### `init-environment-from-secret` (optional, string or array)

One or more [Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) that should be added to the [job init container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/) as environment variables. Each key in the secret will be exposed as an environment variable. If specified as an array, all listed secrets will be added in order.

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

### `mount-hostpath` (optional, string or array)

Mount a host path as a directory inside the container. Must be in the form of `/host/path:/some/mount/path`.
Multiple host paths may be mounted by specifying a list of host/mount pairs.

Example: `my-secret:/my/secret`

### `mount-secret` (optional, string or array)

Mount a secret as a directory inside the container. Must be in the form of `secretName:/some/mount/path`.
Multiple secrets may be mounted by specifying a list of secret/mount pairs.

Example: `my-secret:/my/secret`

### `default-secret-name` (optional, string)

The name of the secret containing the buildkite agent token, ssh and git credentials used for bootstrapping in the init container. The key names of the secret are not configurable and as such must contain the following:
```yaml
  buildkite-agent-token: <token>
  git-credentials: <credentials>
  ssh-key: <sshkey>
```
This is useful if you have control over secret creation and would like to avoid explicitly providing the key and secret names.

Example: `buildkite-secret`

### `build-path-host-path` (optional, string)

Optionally mount a [host path](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath) to be used as base directory for buildkite builds. This allows local caching and incremental builds using fast local storage.

Should be used with some care, since the actual storage used is outside the control of Kubernetes itself.

Example: `/var/lib/buildkite/builds`

### `build-path-pvc` (optional, string)

Optionally mount an existing [Persistent Volume Claim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) used as backing storage for the build.

### `git-mirrors-host-path` (optional, string)

Optionally mount a [host path](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath) to be used as [git-mirrors](https://forum.buildkite.community/t/shared-git-repository-checkouts-in-the-agent/443) path. This enables multiple pipelines to share a single git repository.

Should be used with some care, since the actual storage used is outside the control of Kubernetes itself.

Example: `/var/lib/buildkite/builds`

### `resources-request-cpu` (optional, string)

Sets [cpu request](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) for the build container.

### `resources-limit-cpu` (optional, string)

Sets [cpu limit](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) for the build container.

### `resources-request-memory` (optional, string)

Sets [memory request](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) for the build container.

### `resources-limit-memory` (optional, string)

Sets [memory limit](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) for the build container.

### `service-account-name` (optional, string)

Sets the [service account](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) for the build container.

Default: `default`

### `use-agent-node-affinity` (optional, boolean)

If set to `true`, the spawned jobs will use the same [node affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/) and [tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) as the buildkite agent.

### `workdir` (optional, string)

Override the working directory to run the command in, inside the container. The default is the build directory where the buildkite bootstrap and git checkout runs.

### `patch` (optional, string)

(Advanced / hack use). Provide a [jsonnet](https://jsonnet.org/) function to transform the resulting job manifest.

Example:
```
patch: |
  function(job) job {
    spec+: {
      template+: {
        spec+: {
          tolerations: [ { key: 'foo', value: 'bar', operator: 'Equal', effect: 'NoSchedule' }, ],
        },
      },
    },
  }
```

### `print-resulting-job-spec` (optional, boolean)

If set to `true`, the resulting k8s job spec is printed to the log. This can be useful when debugging.

### `job-ttl-seconds-after-finished` (optional, integer)

Configures [`spec.ttlSecondsAfterFinished`](https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/) on the k8s job, requires TTL Controller enabled in the cluster, otherwise ignored.
Default value: `86400`.  

### `jobs-cleanup-via-plugin` (optional, boolean)

If set to `true`, the plugin cleans up k8s jobs older than 1 day even if they're still running. 
Default value: `true`.

If you have [TTL Controller](https://kubernetes.io/docs/concepts/workloads/controllers/ttlafterfinished/) enabled or some other means to cleanup finished jobs, it is recommended to set the value to `false` in order to reduce load on k8s api servers.

### `job-cleanup-after-finished-via-plugin` (optional, boolean)

If set to `true` plugin cleans up finished k8s job.
Default value: `true`.

If you have TTL controller or https://github.com/lwolf/kube-cleanup-operator running, it is highly recommended to set the value to `false` to reduce load on k8s api servers.

## Low Level Configuration via Environment Variables

Some of the plugin options can be configured via environment variables as following ([also see Buildkite docs](https://buildkite.com/docs/pipelines/environment-variables#defining-your-own)):

```yaml
env:
  BUILDKITE_PLUGIN_K8S_JOB_APPLY_RETRY_INTERVAL_SEC: "10"
```

### BUILDKITE_PLUGIN_K8S_JOB_APPLY_RETRY_INTERVAL_SEC

- Configures the interval between attempts to schedule the k8s job
- Default: `5`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_JOB_APPLY_TIMEOUT_SEC

- Configures the total time limit across attempts to schedule the k8s job
- Default: `120`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_JOB_STATUS_RETRY_INTERVAL_SEC

- Configures the interval between attempts to get k8s job status
- Default: `5`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_LOG_COMPLETE_RETRY_INTERVAL_SEC

- Configures the interval between attempts to verify that log streaming has ended
- Default: `1`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_LOG_COMPLETE_TIMEOUT_SEC

- Configures the total time limit across attempts to verify that log streaming has ended
- Default: `30`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_LOG_RETRY_INTERVAL_SEC

- Configures the interval between attempts to stream job logs
- Default: `3`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_LOG_ATTEMPT_TIMEOUT_SEC

- Configures time limit for a _single_ plugin attempt to stream job logs
- Default: `5`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_JOB_CLEANUP_RETRY_INTERVAL_SEC

- Configures the interval between attempts to cleanup finished jobs
- Default: `5`
- Unit type: integer seconds

### BUILDKITE_PLUGIN_K8S_JOB_CLEANUP_TIMEOUT_SEC

- Configures the total time limit across attempts to cleanup finished jobs
- Default: `60`
- Unit type: integer seconds

## Contributing

We welcome community contributions to this project.

Please read our [Contributor Guide](CONTRIBUTING.md) for more information on how to get started.

## License

Licensed under either of

* Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or http://www.apache.org/licenses/LICENSE-2.0)
* MIT license ([LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT)

at your option.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without any additional terms or conditions.
