FROM buildkite/agent:3.38.0

ARG CI_COMMIT_TIMESTAMP
ARG CI_COMMIT_SHA
ARG BUILDKITE_AGENT_VERSION
ARG KUBERNETES_VERSION
ARG CI_COMMIT_TAG

LABEL maintainer="Daniel Muehlbachler-Pietrzykowski <daniel.muehlbachler@niftyside.com>"
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date="$CI_COMMIT_TIMESTAMP"
LABEL org.label-schema.name="builkite-agent-k8s"
LABEL org.label-schema.description="Buildkite Agent with Kubernetes Support"
LABEL org.label-schema.vcs-url="https://github.com/muhlba91/buildkite-plugin-k8s"
LABEL org.label-schema.vcs-ref="$CI_COMMIT_SHA"
LABEL org.label-schema.vendor="Daniel Muehlbachler-Pietrzykowski"
LABEL org.label-schema.version="$BUILDKITE_AGENT_VERSION-$KUBERNETES_VERSION-$CI_COMMIT_TAG"

USER root

COPY entrypoint.sh /entrypoint.sh

RUN apk add --no-cache bash ca-certificates coreutils curl git jq libstdc++ openssh jsonnet
RUN curl -sfL https://storage.googleapis.com/kubernetes-release/release/${KUBERNETES_VERSION}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

ENTRYPOINT [ "/entrypoint.sh"]
CMD ["start"]
