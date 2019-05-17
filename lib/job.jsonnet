local allowedEnvs = std.set(
  [
    'BUILDKITE_AGENT_ACCESS_TOKEN',
    'BUILDKITE_JOB_ID',
    'BUILDKITE_REPO',
    'BUILDKITE_COMMIT',
    'BUILDKITE_BRANCH',
    'BUILDKITE_MESSAGE',
    'BUILDKITE_BUILD_CREATOR',
    'BUILDKITE_BUILD_CREATOR_EMAIL',
    'BUILDKITE_BUILD_NUMBER',
    'BUILDKITE_BUILD_PATH',
    'BUILDKITE_BUILD_URL',
    'BUILDKITE_TAG',
    'BUILDKITE_AGENT_NAME',
    'BUILDKITE_ORGANIZATION_SLUG',
    'BUILDKITE_PIPELINE_SLUG',
    'BUILDKITE_PIPELINE_PROVIDER',
    'BUILDKITE_PROJECT_PROVIDER',
    'BUILDKITE_PROJECT_SLUG',
    'BUILDKITE_PULL_REQUEST',
    'BUILDKITE_PULL_REQUEST_BASE_BRANCH',
    'BUILDKITE_PULL_REQUEST_REPO',
    'BUILDKITE_REBUILT_FROM_BUILD_ID',
    'BUILDKITE_REBUILT_FROM_BUILD_NUMBER',
    'BUILDKITE_REPO',
    'BUILDKITE_SOURCE',
  ]
);

function(jobName, agentEnv={}) {
  local env = {
    BUILDKITE_PLUGIN_K8S_SECRET_NAME: 'buildkite',
    BUILDKITE_PLUGIN_K8S_SSH_SECRET_KEY: 'ssh-key',
    BUILDKITE_PLUGIN_K8S_AGENT_TOKEN_SECRET_KEY: 'buildkite-agent-token',
    BUILDKITE_PLUGIN_K8S_INIT_IMAGE: 'embarkstudios/k8s-buildkite-agent',
    BUILDKITE_PLUGIN_K8S_ALWAYS_PULL: false,
  } + agentEnv + {
    BUILDKITE_BUILD_PATH: '/buildkite/builds',
  },

  local podEnv =
    [
      { name: f, value: env[f] }
      for f in std.objectFields(env)
      if std.setMember(f, allowedEnvs)
    ] +
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
    ] + [
      {
        local kv = std.splitLimit(env[f], '=', 1),
        name: kv[0],
        value: kv[1],
      }
      for f in std.objectFields(env)
      if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_ENVIRONMENT_')
    ],

  local labels = {
    'build/branch': env.BUILDKITE_BRANCH,
    'build/pipeline': env.BUILDKITE_PIPELINE_SLUG,
    'buildkite/plugin': 'k8s',
  },

  local annotations = {
    'build/commit': env.BUILDKITE_COMMIT,
    'build/creator': env.BUILDKITE_BUILD_CREATOR,
    'build/creator-email': env.BUILDKITE_BUILD_CREATOR_EMAIL,
    'build/id': env.BUILDKITE_BUILD_ID,
    'build/url': env.BUILDKITE_BUILD_URL,
    'build/message': env.BUILDKITE_MESSAGE,
    'build/number': env.BUILDKITE_BUILD_NUMBER,
    'build/project': env.BUILDKITE_PROJECT_SLUG,
    'build/repo': env.BUILDKITE_REPO,
    'build/source': env.BUILDKITE_SOURCE,
    'buildkite/agent-id': env.BUILDKITE_AGENT_ID,
    'buildkite/agent-name': env.BUILDKITE_AGENT_NAME,
    'job-name': jobName,
  },

  apiVersion: 'batch/v1',
  kind: 'Job',
  metadata: {
    name: jobName,
    labels: labels,
    annotations: annotations,
  },
  spec: {
    backoffLimit: 0,
    completions: 1,
    template: {
      metadata: {
        labels: labels,
        annotations: annotations,
      },
      spec: {
        restartPolicy: 'Never',
        initContainers: [
          {
            name: 'bootstrap',
            image: env.BUILDKITE_PLUGIN_K8S_INIT_IMAGE,
            args: ['bootstrap', '--command', 'true'],
            env: podEnv,
            volumeMounts: [{ mountPath: env.BUILDKITE_BUILD_PATH, name: 'build' }],
          },
        ],
        containers: [
          {
            name: 'step',
            image: env.BUILDKITE_PLUGIN_K8S_IMAGE,
            imagePullPolicy: if env.BUILDKITE_PLUGIN_K8S_ALWAYS_PULL == 'true' then 'Always' else 'IfNotPresent',
            command: [env[f] for f in std.objectFields(env) if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_ENTRYPOINT_')],
            args: [env[f] for f in std.objectFields(env) if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_COMMAND_')],
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
