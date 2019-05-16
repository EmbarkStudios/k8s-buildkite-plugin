function(jobName, agentEnv={}) {
  local env = {
    BUILDKITE_PLUGIN_K8S_SECRET_NAME: 'buildkite',
    BUILDKITE_PLUGIN_K8S_SSH_SECRET_KEY: 'ssh-key',
    BUILDKITE_PLUGIN_K8S_AGENT_TOKEN_SECRET_KEY: 'buildkite-agent-token',
    BUILDKITE_PLUGIN_K8S_INIT_IMAGE: 'embarkstudios/k8s-buildkite-agent',
  } + agentEnv + {
    BUILDKITE_BUILD_PATH: '/buildkite/builds',
  },

  local podEnv = [{ name: f, value: env[f] } for f in std.objectFields(env) if std.startsWith(f, 'BUILDKITE_')] +
                 [
                   {
                     name: 'BUILDKITE_AGENT_TOKEN',
                     valueFrom: {
                       secretKeyRef: {
                         name: env.BUILDKITE_PLUGIN_K8S_SECRET_NAME,
                         key: env.BUILDKITE_PLUGIN_K8S_AGENT_TOKEN_SECRET_KEY,
                       },
                     },
                   },
                   {
                     name: 'SSH_PRIVATE_RSA_KEY',
                     valueFrom: {
                       secretKeyRef: {
                         name: env.BUILDKITE_PLUGIN_K8S_SECRET_NAME,
                         key: env.BUILDKITE_PLUGIN_K8S_SSH_SECRET_KEY,
                       },
                     },
                   },
                 ],

  apiVersion: 'batch/v1',
  kind: 'Job',
  metadata: {
    name: jobName,
  },
  spec: {
    backoffLimit: 0,
    completions: 1,
    template: {
      spec: {
        restartPolicy: 'Never',
        initContainers: [
          {
            name: 'bootstrap',
            image: env.BUILDKITE_PLUGIN_K8S_INIT_IMAGE,
            command: ['uname'],
            // args: ['bootstrap', '--command', 'true'],
            env: podEnv,
            volumeMounts: [{ mountPath: env.BUILDKITE_BUILD_PATH, name: 'build' }],
          },
        ],
        containers: [
          {
            name: 'step',
            image: env.BUILDKITE_PLUGIN_K8S_IMAGE,
            command: [env[f] for f in std.objectFields(env) if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_COMMAND_')],
            env: podEnv,
            volumeMounts: [{ mountPath: env.BUILDKITE_BUILD_PATH, name: 'build' }],
            workingDir: std.join('/', [env.BUILDKITE_BUILD_PATH, env.BUILDKITE_AGENT_NAME, env.BUILDKITE_ORGANIZATION_SLUG, env.BUILDKITE_PIPELINE_SLUG]),
          },
        ],
        volumes: [{ name: 'build', emptyDir: {} }],
      },
    },
  },
}
