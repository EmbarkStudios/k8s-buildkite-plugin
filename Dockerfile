FROM buildkite/agent:3.12.0 AS buildkite

FROM mexisme/jsonnet:alpine AS jsonnet

FROM alpine
COPY entrypoint.sh /entrypoint.sh

RUN apk add --no-cache bash ca-certificates coreutils curl git jq libstdc++ openssh

ENV K8S_VERSION="v1.14.2"
RUN curl -sfL https://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

COPY --from=buildkite /usr/local/bin/buildkite-agent /usr/local/bin/buildkite-agent

COPY --from=jsonnet /jsonnet /usr/local/bin/jsonnet

ENTRYPOINT [ "/entrypoint.sh"]
