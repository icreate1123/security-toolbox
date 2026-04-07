FROM eclipse-temurin:25-jdk-jammy

ARG SNYK_VERSION=stable

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    jq \
    maven \
 && rm -rf /var/lib/apt/lists/*

RUN curl --compressed -L "https://downloads.snyk.io/cli/${SNYK_VERSION}/snyk-linux" -o /usr/local/bin/snyk \
 && chmod +x /usr/local/bin/snyk \
 && snyk --version

WORKDIR /work

LABEL org.opencontainers.image.title="security-toolbox" \
      org.opencontainers.image.description="Reusable scanner image with Snyk CLI and common tooling" \
      org.opencontainers.image.source="https://github.com/iCreate1123/security-toolbox" \
      org.opencontainers.image.licenses="MIT"

CMD ["/bin/bash"]
