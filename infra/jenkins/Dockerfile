FROM node:22-bookworm-slim AS node-runtime
FROM docker:28-cli AS docker-cli

FROM jenkins/jenkins:lts-jdk21

USER root

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

COPY --from=node-runtime /usr/local/bin/node /usr/local/bin/node
COPY --from=node-runtime /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose

RUN ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -s /usr/local/lib/node_modules/corepack/dist/corepack.js /usr/local/bin/corepack \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && ln -s /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/lib/docker/cli-plugins/docker-compose \
    && apt-get update \
    && apt-get install --no-install-recommends -y bash ca-certificates curl git \
    && corepack enable \
    && corepack prepare pnpm@10.12.1 --activate \
    && npx --yes playwright@1.60.0 install --with-deps chromium \
    && chown -R jenkins:jenkins /ms-playwright \
    && chmod -R 755 /ms-playwright \
    && rm -rf /var/lib/apt/lists/* /root/.npm

ENV PATH=/opt/java/openjdk/bin:/usr/local/bin:/usr/bin:/bin
ENV COREPACK_HOME=/opt/corepack

RUN cp -a /root/.cache/node/corepack /opt/corepack \
    && chown -R jenkins:jenkins /opt/corepack

COPY --chown=jenkins:jenkins infra/jenkins/plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

COPY --chown=jenkins:jenkins infra/jenkins/jenkins.yaml /usr/share/jenkins/ref/casc/jenkins.yaml
COPY --chown=jenkins:jenkins infra/jenkins/inventory-job.groovy /usr/share/jenkins/ref/casc/inventory-job.groovy

# Pre-download Gradle distribution at build time to avoid DNS failures during pipeline runs
RUN mkdir -p /opt/gradle-cache && chown jenkins:jenkins /opt/gradle-cache
COPY --chown=jenkins:jenkins backend/gradle /tmp/gradle-setup/gradle
COPY --chown=jenkins:jenkins backend/gradlew /tmp/gradle-setup/gradlew

USER jenkins

ENV GRADLE_USER_HOME=/opt/gradle-cache
RUN cd /tmp/gradle-setup \
    && chmod +x gradlew \
    && ./gradlew --version \
    && rm -rf /tmp/gradle-setup
