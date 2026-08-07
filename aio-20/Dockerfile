# ----------------------------------
# Pterodactyl Core Dockerfile
# Environment: Java 20 (Multi-vendor + GraalVM)
# Minimum Panel Version: 1.7.0
# ----------------------------------

# ---- Malloc implementations builder stage ----
FROM debian:stable-slim AS malloc-builder

# deprived from aio-17

# Install build dependencies for both jemalloc and mimalloc
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        graphviz \
        which \
        lsof \
        curl \
        ca-certificates \
        openssl \
        git \
        tar \
        sqlite3 \
        fontconfig \
        libfreetype6 \
        tzdata \
        iproute2 \
        libstdc++6 \
        autoconf \
        cmake && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt /tmp/jprof /tmp/nmt /tmp/pmap /diagnostic

# Build jemalloc with profiling support
WORKDIR /opt/jemalloc
# We manually compile jemalloc here, as installing through apt-get (libjemalloc2) does not enable the profiling options we need in Jemalloc.
# If you look below, we use the --enable-prof flag in the autogen.sh script to enable profiling.
RUN git clone https://github.com/jemalloc/jemalloc.git . && \
    ./autogen.sh --enable-prof && \
    make dist && \
    make && \
    make install

# Build mimalloc for performance, they manually compiled the mimalloc fr
WORKDIR /opt/mimalloc
RUN git clone https://github.com/microsoft/mimalloc.git . && \
    mkdir -p build && \
    cd build && \
    cmake -DMI_BUILD_TESTS=OFF ../ && \
    make install

# get JDK source
FROM eclipse-temurin:20-jdk AS temurin
FROM container-registry.oracle.com/graalvm/jdk:20 AS graalvm
FROM ghcr.io/graalvm/jdk-community:20 AS graalvm-ce
FROM container-registry.oracle.com/graalvm/native-image:20 AS graalvm-native
FROM azul/zulu-openjdk:20 AS zulu
FROM amazoncorretto:20 AS corretto
# FROM ibm-semeru-runtimes:open-20-jdk AS semeru
FROM bellsoft/liberica-openjdk-debian:20 AS liberica
# FROM alibabadragonwell/dragonwell:20 AS dragonwell

# ---- Builder stage: assemble and strip all JDKs in one place ----
FROM eclipse-temurin:20-jdk AS cacerts-provider
FROM debian:stable-slim AS jdk-builder

# Copy all JDKs into the builder
COPY --from=temurin         /opt/java/openjdk                              /opt/java/temurin
COPY --from=graalvm         /usr/lib64/graalvm/graalvm-java20              /opt/java/graalvm
COPY --from=graalvm-ce      /usr/lib64/graalvm/graalvm-community-java20    /opt/java/graalvm-ce
COPY --from=graalvm-native  /usr/lib64/graalvm/graalvm-java20              /opt/java/graalvm-native
COPY --from=corretto        /usr/lib/jvm/java-20-amazon-corretto           /opt/java/corretto
COPY --from=cacerts-provider /opt/java/openjdk               /tmp/cacerts-provider
# COPY --from=semeru          /opt/java/openjdk                              /opt/java/semeru
# COPY --from=dragonwell      /opt/java/openjdk                              /opt/java/dragonwell

# Zulu and Liberica use variable directory names
COPY --from=zulu      /usr/lib/jvm  /tmp/zulu-jvm
COPY --from=liberica  /usr/lib/jvm  /tmp/liberica-jvm

# Single RUN: move variable-named dirs, then strip ALL JDKs
RUN set -eux && \
    # Move Zulu
    ZULU_DIR=$(find /tmp/zulu-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && \
    if [ -n "$ZULU_DIR" ]; then \
        mv "$ZULU_DIR" /opt/java/zulu; \
    else \
        echo "ERROR: No Zulu JDK directory found!" && exit 1; \
    fi && \
    rm -rf /tmp/zulu-jvm && \
    \
    # Move Liberica
    LIBERICA_DIR=$(find /tmp/liberica-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && \
    if [ -n "$LIBERICA_DIR" ]; then \
        mv "$LIBERICA_DIR" /opt/java/liberica; \
    else \
        echo "ERROR: No Liberica JDK directory found!" && exit 1; \
    fi && \
    rm -rf /tmp/liberica-jvm && \
    \
    # Verify every JDK has a bin/java
    for jdk in temurin graalvm graalvm-ce graalvm-native zulu corretto liberica; do \
        if [ ! -f "/opt/java/$jdk/bin/java" ]; then \
            echo "ERROR: /opt/java/$jdk/bin/java not found!" && exit 1; \
        fi; \
        echo "OK /opt/java/$jdk/bin/java"; \
    done && \
    \
    # Remove non-essential directories
    for dir in man demo sample legal jmods include; do \
        find /opt/java -type d -name "$dir" -exec rm -rf {} + 2>/dev/null || true; \
    done && \
    \
    # Remove non-essential files
    find /opt/java -type f \( -name "src.zip" -o -name "*.debuginfo" -o -name "*.diz" -o -name "*.map" \) -delete 2>/dev/null || true && \
    \
    # Fix Corretto's broken cacerts symlink using separate cacerts-provider JDK
    if [ -d "/opt/java/corretto" ]; then \
        CACERTS_SRC=$(find /tmp/cacerts-provider -name "cacerts" -type f ! -type l 2>/dev/null | head -n1) && \
        if [ -n "$CACERTS_SRC" ]; then \
            for sub in "lib/security" "jre/lib/security" "conf/security"; do \
                if [ -d "/opt/java/corretto/$sub" ]; then \
                    echo "Fixing Corretto cacerts: copying from separate provider ($CACERTS_SRC)"; \
                    rm -f "/opt/java/corretto/$sub/cacerts"; \
                    cp "$CACERTS_SRC" "/opt/java/corretto/$sub/cacerts"; \
                    chmod 644 "/opt/java/corretto/$sub/cacerts"; \
                fi; \
            done; \
        fi && \
        rm -rf /tmp/cacerts-provider; \
    fi && \
    \
    # Log final sizes
    echo "=== Per-JDK sizes ===" && du -sh /opt/java/* && \
    echo "=== Total ===" && du -sh /opt/java

# ---- Final image ----
FROM debian:stable-slim

ARG TARGETARCH

LABEL       author="Aretzera" maintainer="agroup168@proton.me"
LABEL org.opencontainers.image.description="Java 20 Multi-vendor Image with GraalVM"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN         apt-get update -y \
            && apt-get install -y --no-install-recommends curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 libstdc++6 lsof build-essential tzdata iproute2 locales libnuma1 numactl graphviz perl procps google-perftools \
            && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
            && locale-gen en_US.UTF-8 \
            && update-locale LANG=en_US.UTF-8 \
            && apt-get clean \
            && rm -rf /var/lib/apt/lists/* \
            && useradd -m -d /home/container container

# Copy all pre-stripped JDKs in a single layer
COPY --from=jdk-builder /opt/java /opt/java

COPY --from=malloc-builder /usr/local/lib/libjemalloc.so /usr/local/lib/libjemalloc.so
COPY --from=malloc-builder /usr/local/lib/libmimalloc.so /usr/local/lib/libmimalloc.so

# Copy jeprof tool for heap dump analysis
COPY --from=malloc-builder /usr/local/bin/jeprof /usr/local/bin/jeprof

ENV JDK_VENDOR=temurin

USER        container
ENV         USER=container HOME=/home/container

WORKDIR     /home/container

COPY        ./../scripts/entrypoint.sh /entrypoint.sh

CMD         ["/bin/bash", "/entrypoint.sh"]
