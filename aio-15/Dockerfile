# ----------------------------------
# Pterodactyl Core Dockerfile
# Environment: Java 15 (Multi-vendor)
# Minimum Panel Version: 1.7.0
# ----------------------------------

FROM debian:stable-slim AS malloc-builder
RUN apt-get update && apt-get install -y --no-install-recommends build-essential graphviz which lsof curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 tzdata iproute2 libstdc++6 autoconf cmake && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /opt /tmp/jprof /tmp/nmt /tmp/pmap /diagnostic
WORKDIR /opt/jemalloc
RUN git clone https://github.com/jemalloc/jemalloc.git . && ./autogen.sh --enable-prof && make dist && make && make install
WORKDIR /opt/mimalloc
RUN git clone https://github.com/microsoft/mimalloc.git . && mkdir -p build && cd build && cmake -DMI_BUILD_TESTS=OFF ../ && make install

FROM azul/zulu-openjdk:15 AS zulu
FROM bellsoft/liberica-openjdk-debian:15 AS liberica
FROM amazoncorretto:15 AS corretto

FROM adoptopenjdk/openjdk15:debian-slim AS cacerts-provider
FROM debian:stable-slim AS jdk-builder

RUN mkdir -p /opt/java
COPY --from=zulu      /usr/lib/jvm  /tmp/zulu-jvm
COPY --from=liberica  /usr/lib/jvm  /tmp/liberica-jvm
COPY --from=corretto  /usr/lib/jvm/java-15-amazon-corretto /opt/java/corretto
COPY --from=cacerts-provider /opt/java/openjdk               /tmp/cacerts-provider
RUN set -eux && \
    ZULU_DIR=$(find /tmp/zulu-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && if [ -n "$ZULU_DIR" ]; then mv "$ZULU_DIR" /opt/java/zulu; else echo "ERROR: No Zulu JDK directory found!" && exit 1; fi && \
    rm -rf /tmp/zulu-jvm && \
    LIBERICA_DIR=$(find /tmp/liberica-jvm -mindepth 1 -maxdepth 1 -type d | head -n1) && if [ -n "$LIBERICA_DIR" ]; then mv "$LIBERICA_DIR" /opt/java/liberica; else echo "ERROR: No Liberica JDK directory found!" && exit 1; fi && \
    rm -rf /tmp/liberica-jvm && \
    for jdk in zulu liberica corretto; do if [ ! -f "/opt/java/$jdk/bin/java" ]; then echo "ERROR: /opt/java/$jdk/bin/java not found!" && exit 1; fi; echo "OK /opt/java/$jdk/bin/java"; done && \
    for dir in man demo sample legal jmods include; do find /opt/java -type d -name "$dir" -exec rm -rf {} + 2>/dev/null || true; done && \
    find /opt/java -type f \( -name "src.zip" -o -name "*.debuginfo" -o -name "*.diz" -o -name "*.map" \) -delete 2>/dev/null || true && \
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
    echo "=== Per-JDK sizes ===" && du -sh /opt/java/* && echo "=== Total ===" && du -sh /opt/java

FROM debian:stable-slim
ARG TARGETARCH
LABEL       author="Aretzera" maintainer="agroup168@proton.me"
LABEL org.opencontainers.image.description="Java 15 Multi-vendor Image"
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'
RUN apt-get update -y && apt-get install -y --no-install-recommends curl ca-certificates openssl git tar sqlite3 fontconfig libfreetype6 libstdc++6 lsof build-essential tzdata iproute2 locales libnuma1 numactl graphviz perl procps google-perftools && echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen en_US.UTF-8 && update-locale LANG=en_US.UTF-8 && apt-get clean && rm -rf /var/lib/apt/lists/* && useradd -m -d /home/container container
# Copy all pre-stripped JDKs in a single layer
COPY --from=jdk-builder /opt/java /opt/java

COPY --from=malloc-builder /usr/local/lib/libjemalloc.so /usr/local/lib/libjemalloc.so
COPY --from=malloc-builder /usr/local/lib/libmimalloc.so /usr/local/lib/libmimalloc.so
COPY --from=malloc-builder /usr/local/bin/jeprof /usr/local/bin/jeprof
ENV JDK_VENDOR=zulu
USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container
COPY        ./../scripts/entrypoint.sh /entrypoint.sh
CMD         ["/bin/bash", "/entrypoint.sh"]