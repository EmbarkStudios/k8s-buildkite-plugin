local envfilter(v) = if v != 'BUILDKITE_AGENT_ACCESS_TOKEN' && std.startsWith(v, 'BUILDKITE_') then true else false;

function(jobName, agentEnv={}) {
  local env = {
    BUILDKITE_PLUGIN_K8S_SECRET_NAME: 'buildkite',
    BUILDKITE_PLUGIN_K8S_SSH_SECRET_KEY: 'ssh-key',
    BUILDKITE_PLUGIN_K8S_AGENT_TOKEN_SECRET_KEY: 'buildkite-agent-token',
    BUILDKITE_PLUGIN_K8S_INIT_IMAGE: 'embarkstudios/k8s-buildkite-agent',
  } + agentEnv + {
    BUILDKITE_BUILD_PATH: '/buildkite/builds',
  },

  local podEnv = [{ name: f, value: env[f] } for f in std.objectFields(env) if envfilter(f)] +
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

  local labels = {
    'build/branch': env.BUILDKITE_BRANCH,
    'build/project': env.BUILDKITE_PROJECT_SLUG,
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
            imagePullPolicy: 'Always',
            args: ['bootstrap', '--command', 'true'],
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
