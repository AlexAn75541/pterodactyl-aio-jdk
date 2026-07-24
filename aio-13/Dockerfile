# ----------------------------------
# Pterodactyl Core Dockerfile
# Environment: Java 13 (Multi-vendor)
# Minimum Panel Version: 1.7.0
# ----------------------------------

# ---- Malloc implementations builder stage ----
FROM debian:stable-slim AS malloc-builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential graphviz which lsof curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 tzdata iproute2 libstdc++6 autoconf cmake && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt /tmp/jprof /tmp/nmt /tmp/pmap /diagnostic

WORKDIR /opt/jemalloc
RUN git clone https://github.com/jemalloc/jemalloc.git . && \
    ./autogen.sh --enable-prof && \
    make dist && \
    make && \
    make install

WORKDIR /opt/mimalloc
RUN git clone https://github.com/microsoft/mimalloc.git . && \
    mkdir -p build && \
    cd build && \
    cmake -DMI_BUILD_TESTS=OFF ../ && \
    make install

FROM azul/zulu-openjdk:13 AS zulu
FROM bellsoft/liberica-openjdk-debian:13 AS liberica

FROM debian:stable-slim AS jdk-builder

RUN mkdir -p /opt/java

COPY --from=zulu      /usr/lib/jvm  /tmp/zulu-jvm
COPY --from=liberica  /usr/lib/jvm  /tmp/liberica-jvm

RUN set -eux && \
    ZULU_DIR=$(find /tmp/zulu-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && \
    if [ -n "$ZULU_DIR" ]; then mv "$ZULU_DIR" /opt/java/zulu; else echo "ERROR: No Zulu JDK directory found!" && exit 1; fi && \
    rm -rf /tmp/zulu-jvm && \
    LIBERICA_DIR=$(find /tmp/liberica-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && \
    if [ -n "$LIBERICA_DIR" ]; then mv "$LIBERICA_DIR" /opt/java/liberica; else echo "ERROR: No Liberica JDK directory found!" && exit 1; fi && \
    rm -rf /tmp/liberica-jvm && \
    for jdk in zulu liberica; do \
        if [ ! -f "/opt/java/$jdk/bin/java" ]; then echo "ERROR: /opt/java/$jdk/bin/java not found!" && exit 1; fi; \
        echo "OK /opt/java/$jdk/bin/java"; \
    done && \
    for dir in man demo sample legal jmods include; do find /opt/java -type d -name "$dir" -exec rm -rf {} + 2>/dev/null || true; done && \
    find /opt/java -type f \( -name "src.zip" -o -name "*.debuginfo" -o -name "*.diz" -o -name "*.map" \) -delete 2>/dev/null || true && \
    REF_CACERTS=$(find /opt/java -name "cacerts" -type f ! -type l 2>/dev/null | head -n1) && if [ -n "$REF_CACERTS" ]; then for jdk_dir in /opt/java/*; do for sub in "lib/security" "jre/lib/security" "conf/security"; do if [ -d "$jdk_dir/$sub" ]; then target="$jdk_dir/$sub/cacerts"; if [ -L "$target" ] || [ ! -s "$target" ]; then rm -f "$target" && cp "$REF_CACERTS" "$target" || true; fi; fi; done; done; fi && \
    echo "=== Per-JDK sizes ===" && du -sh /opt/java/* && echo "=== Total ===" && du -sh /opt/java

FROM debian:stable-slim

ARG TARGETARCH

LABEL       author="Aretzera" maintainer="agroup168@proton.me"
LABEL org.opencontainers.image.description="Java 13 Multi-vendor Image"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

RUN apt-get update -y \
    && apt-get install -y --no-install-recommends curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 libstdc++6 lsof build-essential tzdata iproute2 locales libnuma1 numactl graphviz perl procps google-perftools \
    && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && useradd -m -d /home/container container

# Copy all pre-stripped JDKs in a single layer
COPY --from=jdk-builder /opt/java /opt/java

# --- Sync OS CA certificates into every JDK's truststore ---
RUN update-ca-certificates && \
    mkdir -p /etc/ssl/certs/java /etc/pki/java /tmp/certs && \
    KEYTOOL=$(find /opt/java -name "keytool" -type f 2>/dev/null | head -n1) && \
    if [ -n "$KEYTOOL" ] && [ -f /etc/ssl/certs/ca-certificates.crt ]; then \
        TMP_KS="/tmp/cacerts.tmp" && \
        rm -f "$TMP_KS" && \
        awk '/-----BEGIN CERTIFICATE-----/{n++; file="/tmp/certs/cert" n ".crt"} n>0{print > file}' /etc/ssl/certs/ca-certificates.crt && \
        for f in /tmp/certs/*.crt; do \
            [ -f "$f" ] || continue; \
            "$KEYTOOL" -importcert -noprompt -trustcacerts \
                -keystore "$TMP_KS" -storepass changeit \
                -alias "os-ca-$(basename "$f")" \
                -file "$f" >/dev/null 2>&1 || true; \
        done && \
        rm -rf /tmp/certs && \
        if [ -f "$TMP_KS" ]; then \
            mv "$TMP_KS" /etc/ssl/certs/java/cacerts && \
            chmod 644 /etc/ssl/certs/java/cacerts; \
        fi; \
    fi && \
    ln -sf /etc/ssl/certs/java/cacerts /etc/pki/java/cacerts && \
    for JDK_DIR in /opt/java/*; do \
        if [ -d "$JDK_DIR" ]; then \
            for sub in "lib/security" "jre/lib/security" "conf/security"; do \
                if [ -d "$JDK_DIR/$sub" ]; then \
                    CACERTS_TARGET="$JDK_DIR/$sub/cacerts" && \
                    if [ -s /etc/ssl/certs/java/cacerts ]; then \
                        rm -f "$CACERTS_TARGET" 2>/dev/null || true && \
                        cp /etc/ssl/certs/java/cacerts "$CACERTS_TARGET" 2>/dev/null || true && \
                        chmod 644 "$CACERTS_TARGET" 2>/dev/null || true; \
                    fi; \
                fi; \
            done; \
        fi; \
    done
COPY --from=malloc-builder /usr/local/lib/libjemalloc.so /usr/local/lib/libjemalloc.so
COPY --from=malloc-builder /usr/local/lib/libmimalloc.so /usr/local/lib/libmimalloc.so
COPY --from=malloc-builder /usr/local/bin/jeprof /usr/local/bin/jeprof

ENV JDK_VENDOR=zulu

USER        container
ENV         USER=container HOME=/home/container

WORKDIR     /home/container

COPY        ./../scripts/entrypoint.sh /entrypoint.sh

CMD         ["/bin/bash", "/entrypoint.sh"]