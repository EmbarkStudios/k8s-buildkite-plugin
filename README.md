# Kubernetes Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/agent/v3/plugins) for running pipeline steps as [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/jobs-run-to-completion/).

The plugin tries to stay reasonably compatible with the [Docker plugin](https://github.com/buildkite-plugins/docker-buildkite-plugin) to make it easy to change pipelines to run on a cluster. It also takes lots of inspiration from the [kustomize-job-buildkite-plugin](https://github.com/MYOB-Technology/kustomize-job-buildkite-plugin).

## Example

```yaml
steps:
  - command: "echo 'Hello, World!'"
    plugins:
      - EmbarkStudios/k8s
          image: alpine
```
