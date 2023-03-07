local identity = function(f) f;

function(jobName, agentEnv={}, stepEnvFile='', patchFunc=identity) patchFunc({
    local buildSubPath = std.join('/', [
        env.BUILDKITE_AGENT_NAME,
        env.BUILDKITE_ORGANIZATION_SLUG,
        env.BUILDKITE_PIPELINE_SLUG
    ]),

    local env = {
        BUILDKITE_PLUGIN_K8S_EXTERNAL_SECRETS: '',
        BUILDKITE_PLUGIN_K8S_SECRET_STORE: '',
        BUILDKITE_PLUGIN_K8S_CLUSTER_STORE: '',
    } + agentEnv,



    local storeType = 
        if env.BUILDKITE_PLUGIN_K8S_SECRET_STORE == '' then "ClusterStore"
        else "SecretStore",

    local storeName =
        if storeType == "SecretStore" then env.BUILDKITE_PLUGIN_K8S_SECRET_STORE
        else env.BUILDKITE_PLUGIN_K8S_CLUSTER_STORE,

    local secretsData = {
        local cfg = [
            std.split(env[f],':')
            for f in std.objectFields(env)
            if std.startsWith(f,'BUILDKITE_PLUGIN_K8S_EXTERNAL_SECRETS')
                && env[f] != ''
        ],
        data: [
            { secretKey: c[0], remoteRef: {key:c[1],property:c[2] } }
            for c in cfg 
        ],
    },

    apiVersion: 'external-secrets.io/v1beta1',
    kind: 'ExternalSecret',
    metadata: {
        name: jobName,
    },
    spec: {
        //envar: env,
        refreshInterval: "15s",
        secretStoreRef: {
            name: storeName,
            kind: storeType,
        },
        target: {
            name: jobName,
        } 
    }+ secretsData,
})