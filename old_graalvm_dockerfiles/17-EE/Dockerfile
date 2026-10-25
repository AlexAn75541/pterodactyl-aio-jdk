# ----------------------------------
# Pterodactyl Core Dockerfile
# Environment: Java
# Minimum Panel Version: 1.7.0
# ----------------------------------
FROM ubuntu:24.04

ARG TARGETPLATFORM
ARG GRAAL_VERSION=22.3.2
ARG JAVA_VERSION=17

LABEL       author="Aretzera" maintainer="agroup168@gmail.com"

ENV DEBIAN_FRONTEND=noninteractive

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apt-get update -y \
  && apt-get install -y curl ca-certificates openssl git tar sqlite3 fontconfig tzdata locales iproute2 \
  && echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen \
  && locale-gen en_US.UTF-8 \
  && case ${TARGETPLATFORM} in \
         "linux/amd64")  ARCH=linux-amd64  ;; \
         "linux/arm64")  ARCH=linux-aarch64  ;; \
    esac \
  && curl --retry 3 -Lfso /tmp/graalvm.tar.gz https://github.com/AlexAn75541/jdks/releases/download/new/graalvm-ee-java17-${ARCH}-21.3.12.tar.gz \
  && mkdir -p /opt/java/graalvm \
  && cd /opt/java/graalvm \
  && tar -xf /tmp/graalvm.tar.gz --strip-components=1 \
  && export PATH="/opt/java/graalvm/bin:$PATH" \
  && rm -rf /var/lib/apt/lists/* \
  && rm -rf /tmp/graalvm.tar.gz

ENV JAVA_HOME=/opt/java/graalvm \
    PATH="/opt/java/graalvm/bin:$PATH"

# Step 2 - add pterodactyl stuff
# Patch for CVE-2026-91403 (eMudhra intermediate CA compromise)
COPY        ./../../scripts/patch-cve-2026-91403.sh /tmp/patch-cve-2026-91403.sh
RUN         bash /tmp/patch-cve-2026-91403.sh /opt/java/graalvm && rm -f /tmp/patch-cve-2026-91403.sh

RUN useradd -d /home/container -m container

USER        container
ENV         USER=container HOME=/home/container

WORKDIR     /home/container

COPY        ./../entrypoint.sh /entrypoint.sh

CMD         ["/bin/bash", "/entrypoint.sh"]