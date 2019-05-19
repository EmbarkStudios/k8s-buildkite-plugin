# Kubernetes Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps as [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/).

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
          always-pull: true
          environment:
            - "MY_SPECIAL_BUT_PUBLIC_VALUE=kittens"
          environment-from-secret:
            - "kitten-secrets"
```
