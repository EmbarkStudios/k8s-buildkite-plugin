FROM buildkite/agent:3.11.5 AS buildkite

FROM mexisme/jsonnet:alpine AS jsonnet

FROM alpine

RUN apk add --no-cache bash coreutils curl git jq libstdc++ openssh

ENV K8S_VERSION="v1.14.1"
RUN curl -sfL https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

COPY --from=buildkite /usr/local/bin/buildkite-agent /usr/local/bin/buildkite-agent

COPY --from=jsonnet /jsonnet /usr/local/bin/jsonnet

COPY buildkite-agent.gitconfig /root/.gitconfig

ENTRYPOINT [ "/usr/local/bin/buildkite-agent" ]
