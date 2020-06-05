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
    'BUILDKITE_TIMEOUT',
    'BUILDKITE_AGENT_NAME',
    'BUILDKITE_ORGANIZATION_SLUG',
    'BUILDKITE_PIPELINE_SLUG',
    'BUILDKITE_PIPELINE_PROVIDER',
    'BUILDKITE_PULL_REQUEST',
    'BUILDKITE_PULL_REQUEST_BASE_BRANCH',
    'BUILDKITE_PULL_REQUEST_REPO',
    'BUILDKITE_REBUILT_FROM_BUILD_ID',
    'BUILDKITE_REBUILT_FROM_BUILD_NUMBER',
    'BUILDKITE_REPO',
    'BUILDKITE_SOURCE',
  ]
);

local identity = function(f) f;

local numberSuffix(s) =
  local t = std.split(s, '_');
  std.format('%05s', t[std.length(t) - 1]);

local labelChars = std.set(std.stringChars('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.'));
local labelValue(s) =
  local sanitizedValue = std.join('', [
    if std.setMember(c, labelChars) then c else '_'
    for c in std.stringChars(s)
  ]);
  if std.length(sanitizedValue) < 63 then sanitizedValue else std.substr(sanitizedValue, 0, 63);

function(jobName, agentEnv={}, stepEnvFile='', patchFunc=identity) patchFunc({
  local buildSubPath = std.join('/', [
    env.BUILDKITE_AGENT_NAME,
    env.BUILDKITE_ORGANIZATION_SLUG,
    env.BUILDKITE_PIPELINE_SLUG,
  ]),

  local env = {
    BUILDKITE_TIMEOUT: '10',
    BUILDKITE_PLUGIN_K8S_SECRET_NAME: 'buildkite',
    BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_KEY: '',
    BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_NAME: '',
    BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_KEY: '',
    BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_NAME: '',
    BUILDKITE_PLUGIN_K8S_AGENT_TOKEN_SECRET_KEY: 'buildkite-agent-token',
    BUILDKITE_PLUGIN_K8S_INIT_IMAGE: 'embarkstudios/k8s-buildkite-agent@sha256:421c6757ba26e0858e20248477b3c36f0249693df82e9dc84013e545b2c69d66',
    BUILDKITE_PLUGIN_K8S_ALWAYS_PULL: false,
    BUILDKITE_PLUGIN_K8S_BUILD_PATH_HOST_PATH: '',
    BUILDKITE_PLUGIN_K8S_BUILD_PATH_PVC: '',
    BUILDKITE_PLUGIN_K8S_GIT_MIRRORS_HOST_PATH: '',
    BUILDKITE_PLUGIN_K8S_MOUNT_SECRET: '',
    BUILDKITE_PLUGIN_K8S_MOUNT_BUILDKITE_AGENT: 'true',
    BUILDKITE_PLUGIN_K8S_PRIVILEGED: 'false',
    BUILDKITE_PLUGIN_K8S_RESOURCES_REQUEST_CPU: '',
    BUILDKITE_PLUGIN_K8S_RESOURCES_LIMIT_CPU: '',
    BUILDKITE_PLUGIN_K8S_RESOURCES_REQUEST_MEMORY: '',
    BUILDKITE_PLUGIN_K8S_RESOURCES_LIMIT_MEMORY: '',
    BUILDKITE_PLUGIN_K8S_WORKDIR: std.join('/', [env.BUILDKITE_BUILD_PATH, buildSubPath]),
    BUILDKITE_PLUGIN_K8S_JOB_TTL_SECONDS_AFTER_FINISHED: '86400',
  } + agentEnv,

  local stepEnv =
    [
      {
        local kv = std.splitLimit(l, '=', 1),
        name: kv[0],
        value: kv[1],
      }
      for l in std.split(stepEnvFile, '\n')
      if l != '' && !std.startsWith(l, 'BUILDKITE')
    ],

  local podEnv =
    stepEnv +
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
    ] + [
      {
        local kv = std.splitLimit(env[f], '=', 1),
        name: kv[0],
        value: kv[1],
      }
      for f in std.sort(std.objectFields(env), numberSuffix)
      if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_ENVIRONMENT_')
         && !std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_ENVIRONMENT_FROM_SECRET')
    ],

  local secretEnv =
    [
      { secretRef: { name: env[f] } }
      for f in std.objectFields(env)
      if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_ENVIRONMENT_FROM_SECRET')
    ],

  local labels = {
    'build/branch': labelValue(env.BUILDKITE_BRANCH),
    'build/pipeline': labelValue(env.BUILDKITE_PIPELINE_SLUG),
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
    'build/organization': env.BUILDKITE_ORGANIZATION_SLUG,
    'build/repo': env.BUILDKITE_REPO,
    'build/source': env.BUILDKITE_SOURCE,
    'buildkite/agent-id': env.BUILDKITE_AGENT_ID,
    'buildkite/agent-name': env.BUILDKITE_AGENT_NAME,
    'buildkite/job-id': env.BUILDKITE_JOB_ID,
    'job-name': jobName,
  },

  local buildVolume =
    if env.BUILDKITE_PLUGIN_K8S_BUILD_PATH_PVC != ''
    then { persistentVolumeClaim: { claimName: env.BUILDKITE_PLUGIN_K8S_BUILD_PATH_PVC } }
    else if env.BUILDKITE_PLUGIN_K8S_BUILD_PATH_HOST_PATH != ''
    then { hostPath: { path: env.BUILDKITE_PLUGIN_K8S_BUILD_PATH_HOST_PATH, type: 'DirectoryOrCreate' } }
    else { emptyDir: {} }
  ,

  local gitMirrorsVolume =
    if env.BUILDKITE_PLUGIN_K8S_GIT_MIRRORS_HOST_PATH != ''
    then { hostPath: { path: env.BUILDKITE_PLUGIN_K8S_GIT_MIRRORS_HOST_PATH, type: 'DirectoryOrCreate' } }
    else { emptyDir: {} }
  ,

  local gitCredentials = {
    mount:
      if env.BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_KEY == '' then []
      else [{ mountPath: '/secrets/git-credentials', name: 'git-credentials', subPath: 'git-credentials' }],
    volume:
      if env.BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_KEY == '' then []
      else [{
        name: 'git-credentials',
        secret: {
          defaultMode: 256,
          secretName:
            if env.BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_NAME != ''
            then env.BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_NAME
            else env.BUILDKITE_PLUGIN_K8S_SECRET_NAME,
          items: [{ key: env.BUILDKITE_PLUGIN_K8S_GIT_CREDENTIALS_SECRET_KEY, path: 'git-credentials' }],
        },
      }],
  },

  local gitSSH = {
    mount:
      if env.BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_KEY == '' then []
      else [{ mountPath: '/secrets/ssh-key', name: 'git-ssh-key', subPath: 'ssh-key' }],
    volume:
      if env.BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_KEY == '' then []
      else [{
        name: 'git-ssh-key',
        secret: {
          defaultMode: 256,
          secretName:
            if env.BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_NAME != ''
            then env.BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_NAME
            else env.BUILDKITE_PLUGIN_K8S_SECRET_NAME,
          items: [{ key: env.BUILDKITE_PLUGIN_K8S_GIT_SSH_SECRET_KEY, path: 'ssh-key' }],
        },
      }],
  },

  local hostPathMount = {
    local cfg =
      std.mapWithIndex(
        function(i, v) ['hostpath-' + i] + v,
        [
          std.splitLimit(env[f], ':', 1)
          for f in std.objectFields(env)
          if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_MOUNT_HOSTPATH')
             && env[f] != ''
        ]
      ),
    mount: [
      { name: c[0], mountPath: c[2] }
      for c in cfg
    ],
    volume: [
      { name: c[0], hostPath: { path: c[1], type: 'DirectoryOrCreate' } }
      for c in cfg
    ],
  },

  local secretMount = {
    local cfg = [
      std.splitLimit(env[f], ':', 1)
      for f in std.objectFields(env)
      if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_MOUNT_SECRET')
         && env[f] != ''
    ],
    mount: [
      { name: c[0], mountPath: c[1] }
      for c in cfg
    ],
    volume: [
      { name: c[0], secret: { secretName: c[0], defaultMode: 256 } }
      for c in cfg
    ],
  },

  local agentMount =
    if env.BUILDKITE_PLUGIN_K8S_MOUNT_BUILDKITE_AGENT == 'false'
    then []
    else [{
      name: 'buildkite-agent',
      mountPath: '/usr/local/bin/buildkite-agent',
      subPath: 'buildkite-agent',
    }],

  local commandArgs =
    if env.BUILDKITE_COMMAND != '' then {
      command: ['/bin/sh', '-c'],
      args: [env.BUILDKITE_COMMAND],
    } else {
      command: [env[f] for f in std.sort(std.objectFields(env), numberSuffix) if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_ENTRYPOINT_')],
      args: [env[f] for f in std.sort(std.objectFields(env), numberSuffix) if std.startsWith(f, 'BUILDKITE_PLUGIN_K8S_COMMAND_')],
    },

  local deadline = std.parseInt(env.BUILDKITE_TIMEOUT) * 60,

  apiVersion: 'batch/v1',
  kind: 'Job',
  metadata: {
    name: jobName,
    labels: labels,
    annotations: annotations,
  },
  spec: {
    backoffLimit: 0,
    activeDeadlineSeconds: deadline,
    completions: 1,
    ttlSecondsAfterFinished: std.parseInt(env.BUILDKITE_PLUGIN_K8S_JOB_TTL_SECONDS_AFTER_FINISHED),
    template: {
      metadata: {
        labels: labels,
        annotations: annotations,
      },
      spec: {
        activeDeadlineSeconds: deadline,
        restartPolicy: 'Never',
        initContainers: [
          {
            name: 'bootstrap',
            image: env.BUILDKITE_PLUGIN_K8S_INIT_IMAGE,
            args: ['bootstrap', '--experiment=git-mirrors', '--git-mirrors-path=/git-mirrors', '--ssh-keyscan', '--command', 'true'],
            env: podEnv,
            volumeMounts: [
              { mountPath: env.BUILDKITE_BUILD_PATH, name: 'build' },
              { mountPath: '/git-mirrors', name: 'git-mirrors' },
              { mountPath: '/local', name: 'buildkite-agent' },
            ] + gitCredentials.mount + gitSSH.mount,
          },
        ],
        containers: [
          {
            name: 'step',
            image: env.BUILDKITE_PLUGIN_K8S_IMAGE,
            imagePullPolicy: if env.BUILDKITE_PLUGIN_K8S_ALWAYS_PULL == 'true' then 'Always' else 'IfNotPresent',
            env: podEnv,
            envFrom: secretEnv,
            securityContext: {
              privileged: std.asciiLower(env.BUILDKITE_PLUGIN_K8S_PRIVILEGED) == 'true',
            },
            resources: {
              requests:
                (if env.BUILDKITE_PLUGIN_K8S_RESOURCES_REQUEST_CPU != '' then
                   { cpu: env.BUILDKITE_PLUGIN_K8S_RESOURCES_REQUEST_CPU }
                 else {})
                +
                (if env.BUILDKITE_PLUGIN_K8S_RESOURCES_REQUEST_MEMORY != '' then
                   { memory: env.BUILDKITE_PLUGIN_K8S_RESOURCES_REQUEST_MEMORY }
                 else {}),
              limits:
                (if env.BUILDKITE_PLUGIN_K8S_RESOURCES_LIMIT_CPU != '' then
                   { cpu: env.BUILDKITE_PLUGIN_K8S_RESOURCES_LIMIT_CPU }
                 else {})
                +
                (if env.BUILDKITE_PLUGIN_K8S_RESOURCES_LIMIT_MEMORY != '' then
                   { memory: env.BUILDKITE_PLUGIN_K8S_RESOURCES_LIMIT_MEMORY }
                 else {}),
            },
            volumeMounts: [
              { mountPath: env.BUILDKITE_PLUGIN_K8S_WORKDIR, name: 'build', subPath: buildSubPath },
              { mountPath: '/build', name: 'build', subPath: buildSubPath },
              { mountPath: '/git-mirrors', name: 'git-mirrors' },
            ] + secretMount.mount + hostPathMount.mount + agentMount,
            workingDir: '/build',
          } + commandArgs,
        ],
        volumes: [
          { name: 'build' } + buildVolume,
          { name: 'git-mirrors' } + gitMirrorsVolume,
          { name: 'buildkite-agent', emptyDir: {} },
        ] + gitCredentials.volume + gitSSH.volume + secretMount.volume + hostPathMount.volume,
      },
    },
  },
})
