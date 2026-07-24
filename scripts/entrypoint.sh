#!/bin/bash

#
# Copyright (c) 2026 Matthew Penner & Aretzera
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Set JAVA_HOME based on JDK_VENDOR (default: temurin)
JDK_VENDOR=${JDK_VENDOR:-temurin}
export JAVA_HOME="/opt/java/${JDK_VENDOR}"

# Select the memory allocator via MALLOC_IMPL (injected by Pterodactyl from the egg variable).
# We read it directly here — no startup-command placeholder needed.
MALLOC_IMPL=${MALLOC_IMPL:-none}
case "$MALLOC_IMPL" in
    none|"")
        ;;
    jemalloc|mimalloc|tcmalloc)
        ;;
    *)
        echo "ERROR: Unknown malloc implementation '${MALLOC_IMPL}'."
        echo "Allowed values: none, jemalloc, mimalloc, tcmalloc"
        exit 1
        ;;
esac

# Check if the selected JDK vendor exists
if [ ! -d "${JAVA_HOME}" ]; then
    echo "ERROR: JDK vendor '${JDK_VENDOR}' is not available in this image."
    echo "Available vendors:"
    ls -1 /opt/java/ 2>/dev/null || echo "  (none found)"
    echo ""
    echo "Please set JDK_VENDOR to one of the available options."
    exit 1
fi

export PATH="${JAVA_HOME}/bin:${PATH}"

# Ensure system CA certificates are updated and synchronized across all JDK vendors
update_java_cacerts() {
    update-ca-certificates >/dev/null 2>&1 || true

    JAVA_CACERTS_FILE="/etc/ssl/certs/java/cacerts"
    mkdir -p /etc/ssl/certs/java /etc/pki/java /tmp/certs 2>/dev/null || true

    if [ ! -e /etc/pki/java/cacerts ]; then
        ln -sf /etc/ssl/certs/java/cacerts /etc/pki/java/cacerts 2>/dev/null || true
    fi

    KEYTOOL=""
    for k in "${JAVA_HOME}/bin/keytool" /opt/java/*/bin/keytool keytool; do
        if command -v "$k" >/dev/null 2>&1 || [ -x "$k" ]; then
            KEYTOOL="$k"
            break
        fi
    done

    if [ -f /etc/ssl/certs/ca-certificates.crt ] && [ -n "$KEYTOOL" ]; then
        # Rebuild if the file is absent/empty OR if keytool reports zero trusted entries
        # (catches the case where awk produced a file but keytool imported nothing)
        _NEED_REBUILD=false
        if [ ! -s "$JAVA_CACERTS_FILE" ]; then
            _NEED_REBUILD=true
        elif ! "$KEYTOOL" -list -keystore "$JAVA_CACERTS_FILE" -storepass changeit 2>/dev/null | grep -q 'trustedCertEntry'; then
            _NEED_REBUILD=true
        fi

        if [ "$_NEED_REBUILD" = "true" ]; then
            TMP_KS="/tmp/cacerts.tmp"
            rm -f "$TMP_KS"
            # Split bundle into one PEM file per certificate so keytool can import each
            awk '/-----BEGIN CERTIFICATE-----/{n++; file="/tmp/certs/cert" n ".crt"} n>0{print > file}' /etc/ssl/certs/ca-certificates.crt 2>/dev/null || true
            for f in /tmp/certs/*.crt; do
                [ -f "$f" ] || continue
                "$KEYTOOL" -importcert -noprompt -trustcacerts \
                    -keystore "$TMP_KS" -storepass changeit \
                    -alias "os-ca-$(basename "$f")" \
                    -file "$f" >/dev/null 2>&1 || true
            done
            rm -rf /tmp/certs 2>/dev/null || true
            if [ -f "$TMP_KS" ]; then
                mv "$TMP_KS" "$JAVA_CACERTS_FILE" 2>/dev/null || true
                chmod 644 "$JAVA_CACERTS_FILE" 2>/dev/null || true
            fi
        fi
    fi

    # Always sync the shared cacerts into every JDK's security directory
    # (unconditional copy so a stale/symlinked/empty vendor cacerts is always replaced)
    if [ -s "$JAVA_CACERTS_FILE" ]; then
        for JDK_DIR in /opt/java/*; do
            if [ -d "$JDK_DIR" ]; then
                for sub in "lib/security" "jre/lib/security" "conf/security"; do
                    if [ -d "$JDK_DIR/$sub" ]; then
                        CACERTS_TARGET="$JDK_DIR/$sub/cacerts"
                        rm -f "$CACERTS_TARGET" 2>/dev/null || true
                        cp "$JAVA_CACERTS_FILE" "$CACERTS_TARGET" 2>/dev/null || true
                        chmod 644 "$CACERTS_TARGET" 2>/dev/null || true
                    fi
                done
            fi
        done
    fi
}

update_java_cacerts

# Switch to the container's working directory
cd /home/container || exit 1

# Some color shit
LIGHT_BLUE='\033[1;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
LIGHT_RED='\033[1;31m' 
RESET_COLOR='\033[0m'
CYAN='\033[0;36m'

# Print Java version
printf "${LIGHT_BLUE}container@java-info~ ${RESET_COLOR}java -version\n"
java -version 2>&1 | cat
echo ""


# initial lines for implementing Skullians's stuff(imma copy all of em) 


# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")
DUMPS_ENABLED=$(echo "$PARSED" | sed -n 's/.*-Ddump=\([^ ]*\).*/\1/p')
TRACE_ENABLED=$(echo "$PARSED" | sed -n 's/.*-Danalyse=\([^ ]*\).*/\1/p')

# Apply the malloc implementation chosen via the MALLOC_IMPL egg variable.
# MALLOC_IMPL is injected directly by Pterodactyl — no startup placeholder needed.
JEMALLOC_ENABLED=false
MIMALLOC_ENABLED=false
TCMALLOC_ENABLED=false
case "$MALLOC_IMPL" in
    jemalloc)
        JEMALLOC_ENABLED=true
        printf "${CYAN}container@memory-allocator~ ${RESET_COLOR}Enabling jemalloc!\n"
        export LD_PRELOAD="/usr/local/lib/libjemalloc.so"
        ;;
    mimalloc)
        MIMALLOC_ENABLED=true
        printf "${CYAN}container@memory-allocator~ ${RESET_COLOR}Enabling mimalloc!\n"
        export LD_PRELOAD="/usr/local/lib/libmimalloc.so"
        ;;
    tcmalloc)
        TCMALLOC_ENABLED=true
        TCMALLOC_LIB=$(ldconfig -p 2>/dev/null | awk '/libtcmalloc_minimal\.so/{print $NF; exit}')
        if [ -z "$TCMALLOC_LIB" ]; then
            printf "${CYAN}container@memory-allocator~ ${RESET_COLOR}${LIGHT_RED}ERROR: tcmalloc requested but library was not found!${RESET_COLOR}\n"
            exit 1
        fi
        printf "${CYAN}container@memory-allocator~ ${RESET_COLOR}Enabling tcmalloc!\n"
        export LD_PRELOAD="$TCMALLOC_LIB"
        ;;
esac

# failsafe in case dumps folder does not exist
mkdir -p dumps


# im gonna pretend that i under stand ts

# haha we hate nohup
if [ "$DUMPS_ENABLED" = "true" ]; then
    if [ "$JEMALLOC_ENABLED" != "true" ]; then
        printf "${CYAN}container@memory-allocator~ ${RESET_COLOR}${LIGHT_RED}ERROR: -Ddump=true requires jemalloc.${RESET_COLOR}\n"
        printf "${CYAN}container@memory-allocator~ ${RESET_COLOR}Select jemalloc with MALLOC_IMPL or remove the dump flag.\n"
        exit 1
    fi

    export MALLOC_CONF="prof:true,lg_prof_interval:31,lg_prof_sample:17,prof_prefix:/home/container/dumps/jeprof,background_thread:true,dirty_decay_ms:1000,muzzy_decay_ms:0,narenas:1,tcache_max:1024,abort_conf:true"

    (
        while true; do
            # loop through heapdump files
            for heapfile in dumps/*.heap; do
                if [ -f "$heapfile" ]; then
                    basefilename="${heapfile%.heap}"
                    
                    timestamp=$(date +"%d.%m.%y-%H:%M:%S")
                    
                    gif_output="dumps/output/${basefilename}-${timestamp}.gif"
                    
                    mkdir -p "$(dirname "$gif_output")"
                    
                    jeprof --show_bytes --maxdegree=20 --nodefraction=0 --edgefraction=0 --gif \
                        "${JAVA_HOME}/bin/java" \
                        "$heapfile" > "$gif_output"
                    
                    # Remove processed heap file
                    rm "$heapfile"
                fi
            done
            
            # Wait one minute before checking again
            sleep 60
        done
    ) &
fi

if [ "$TRACE_ENABLED" = "true" ]; then
    # Extract the keyword from the PARSED variable
    KEYWORD=$(echo "$PARSED" | sed -n 's/.*-Dkeyword=\([^ ]*\).*/\1/p')
    INTERVAL=$(echo "$PARSED" | sed -n 's/.*-Dinterval=\([^ ]*\).*/\1/p')

    if [ -z "$KEYWORD" ]; then
        printf "KEYWORD is empty. Ensure -Dkeyword is set.\n"
        exit 1
    fi
    if [ -z "$INTERVAL" ]; then
        printf "INTERVAL is empty. Ensure -Dinterval is set. (In seconds)\n"
        exit 1
    fi

    printf "Searching for keyword $KEYWORD\n"

    (
        mkdir -p dumps/traces

        while true; do
            sleep "$INTERVAL"

            PID=$(pgrep java)
            jstack "${PID}" > "profiling.log"

            JVM_LOG="profiling.log"

            if [ -f "$JVM_LOG" ]; then
                timestamp=$(date +"%d.%m.%y-%H:%M:%S")
                TRACE_OUTPUT="dumps/traces/trace-${timestamp}.log"

                if grep -qE "$KEYWORD" "$JVM_LOG"; then
                    cat "$JVM_LOG" > "$TRACE_OUTPUT"

                    printf "Detected keyword (%s):" "$KEYWORD" >> "$TRACE_OUTPUT"
                    grep -E "$KEYWORD" "$JVM_LOG" >> "$TRACE_OUTPUT"
                fi
            fi
        done
    ) &
fi


# (mimalloc is now handled in the MALLOC_IMPL case block above)

# (tcmalloc is now handled in the MALLOC_IMPL case block above)

# malloc i've found randomly on the internet





# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "${GREEN}container@game-panel-command~ ${RESET_COLOR}%s\n" "$PARSED"

# shellcheck disable=SC2086
exec env ${PARSED}
