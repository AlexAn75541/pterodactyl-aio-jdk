# ----------------------------------
# Pterodactyl Core Dockerfile
# Environment: Java (GraalVM + Temurin)
# Minimum Panel Version: 1.7.0
# ----------------------------------

# ---- Malloc implementations builder stage ----
FROM debian:stable-slim AS malloc-builder

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
RUN git clone https://github.com/facebook/jemalloc.git . && \
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

# ---- JDK source stages ----
FROM eclipse-temurin:21-jdk AS temurin
FROM container-registry.oracle.com/graalvm/jdk:21 AS graalvm
FROM ghcr.io/graalvm/jdk-community:21 AS graalvm-ce
FROM container-registry.oracle.com/graalvm/native-image:21 AS graalvm-native

FROM shipilev/openjdk:21-lilliput AS shenandoah 
# Subjected to removed because this img is smh large and shenandoah is not exclusive to this anymore atm

FROM azul/zulu-openjdk:21 AS zulu

# FROM azul/prime-debian:21 as azul-prime
# this one image is required to have a license in order to be used ig

FROM amazoncorretto:21 AS corretto
FROM ibm-semeru-runtimes:open-21-jdk AS semeru
FROM bellsoft/liberica-openjdk-debian:21 AS liberica
FROM alibabadragonwell/dragonwell:21 AS dragonwell

# ---- Builder stage: assemble and strip all JDKs in one place ----
# This avoids layer bloat — each COPY+RUN pair in the old approach kept
# the unstripped JDK in a cached layer, doubling disk usage during build.
FROM debian:stable-slim AS jdk-builder

# Copy all JDKs into the builder
COPY --from=temurin         /opt/java/openjdk                              /opt/java/temurin
COPY --from=graalvm         /usr/lib64/graalvm/graalvm-java21              /opt/java/graalvm
COPY --from=graalvm-ce      /usr/lib64/graalvm/graalvm-community-java21    /opt/java/graalvm-ce
COPY --from=graalvm-native  /usr/lib64/graalvm/graalvm-java21              /opt/java/graalvm-native
COPY --from=shenandoah      /opt/jdk                                       /opt/java/shenandoah
COPY --from=corretto        /usr/lib/jvm/java-21-amazon-corretto           /opt/java/corretto
COPY --from=semeru          /opt/java/openjdk                              /opt/java/semeru
COPY --from=dragonwell      /opt/java/openjdk                              /opt/java/dragonwell

# Zulu and Liberica use variable directory names, handle them
COPY --from=zulu      /usr/lib/jvm  /tmp/zulu-jvm
COPY --from=liberica  /usr/lib/jvm  /tmp/liberica-jvm

# i will make sure that I will never touch this again, or atleast dont break the logic
# Keeps bin/ and lib/ intact (javac, jlink, jshell, jar, jfr, native-image, etc.)
# Single RUN: move variable-named dirs, then strip ALL JDKs in one pass
RUN set -eux && \
    # Debug: show what's actually inside the temp dirs
    echo "=== Contents of /tmp/zulu-jvm ===" && ls -la /tmp/zulu-jvm/ && \
    echo "=== Contents of /tmp/liberica-jvm ===" && ls -la /tmp/liberica-jvm/ && \
    \
    # Move Zulu — match any subdirectory containing "zulu" (case-insensitive)
    ZULU_DIR=$(find /tmp/zulu-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && \
    if [ -n "$ZULU_DIR" ]; then \
        echo "Moving Zulu from: $ZULU_DIR" && \
        mv "$ZULU_DIR" /opt/java/zulu; \
    else \
        echo "ERROR: No Zulu JDK directory found!" && exit 1; \
    fi && \
    rm -rf /tmp/zulu-jvm && \
    \
    # Move Liberica — match any subdirectory
    LIBERICA_DIR=$(find /tmp/liberica-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && \
    if [ -n "$LIBERICA_DIR" ]; then \
        echo "Moving Liberica from: $LIBERICA_DIR" && \
        mv "$LIBERICA_DIR" /opt/java/liberica; \
    else \
        echo "ERROR: No Liberica JDK directory found!" && exit 1; \
    fi && \
    rm -rf /tmp/liberica-jvm && \
    \
    # Verify every JDK has a bin/java
    for jdk in temurin graalvm graalvm-ce graalvm-native zulu corretto shenandoah semeru liberica dragonwell; do \
        if [ ! -f "/opt/java/$jdk/bin/java" ]; then \
            echo "ERROR: /opt/java/$jdk/bin/java not found!" && \
            ls -laR /opt/java/$jdk/ 2>/dev/null || echo "Directory missing entirely" && \
            exit 1; \
        fi; \
        echo "OK /opt/java/$jdk/bin/java"; \
    done && \
    \
    # Remove non-essential directories to save space (keeps bin/, lib/ with all dev tools)
    for dir in man demo sample legal jmods include; do \
        find /opt/java -type d -name "$dir" -exec rm -rf {} + 2>/dev/null || true; \
    done && \
    \
    # Remove non-essential files
    find /opt/java -type f \( -name "src.zip" -o -name "*.debuginfo" -o -name "*.diz" -o -name "*.map" \) -delete 2>/dev/null || true && \
    \
    # Strip debug symbols from shared libraries 
    find /opt/java -type f \( -name "*.so" -o -name "*.so.*" \) -exec strip --strip-debug {} \; 2>/dev/null || true && \
    \
    # Log final sizes for debugging
    echo "=== Per-JDK sizes ===" && du -sh /opt/java/* && \
    echo "=== Total ===" && du -sh /opt/java

    # too lazy to understand all ts

# ---- Final image ----
FROM debian:stable-slim

ARG TARGETARCH

LABEL       author="Aretzera" maintainer="agroup168@proton.me"
LABEL org.opencontainers.image.description="Experimental Image btw"

ENV DEBIAN_FRONTEND=noninteractive

# Default to UTF-8 file.encoding
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'


# NUMA tools and stuff here + jemalloc profiling tools (graphviz, perl for jeprof)
RUN         apt-get update -y \
            && apt-get install -y --no-install-recommends screen curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 libstdc++6 lsof tzdata iproute2 locales libnuma1 numactl graphviz perl procps libtcmalloc-minimal4 \
            && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \                                                                                                                          
            && locale-gen en_US.UTF-8 \
            && update-locale LANG=en_US.UTF-8 \
            && apt-get clean \
            && rm -rf /var/lib/apt/lists/* \
            && useradd -m -d /home/container container

# Copy all pre-stripped JDKs in a single layer from the builder
COPY --from=jdk-builder /opt/java /opt/java

# Copy malloc libraries from malloc-builder
COPY --from=malloc-builder /usr/local/lib/libjemalloc.so /usr/local/lib/libjemalloc.so
COPY --from=malloc-builder /usr/local/lib/libmimalloc.so /usr/local/lib/libmimalloc.so
# hell yeah

# Copy jeprof tool for heap dump analysis
COPY --from=malloc-builder /usr/local/bin/jeprof /usr/local/bin/jeprof



# JDK_VENDOR is the arg to set the type of jdk to be launched, defaulted to temurin
ENV JDK_VENDOR=temurin

USER        container
ENV         USER=container HOME=/home/container

WORKDIR     /home/container

COPY        ./../scripts/entrypoint_exp.sh /entrypoint_exp.sh

CMD         ["/bin/bash", "/entrypoint_exp.sh"]