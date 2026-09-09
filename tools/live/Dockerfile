# C3 live runner: reproducible Forge 1.12.2-2860 proof environment.
#
# This image runs tools/run-live.sh (JDK 8 native: -source/-target, server
# runtime), NOT tools/check.sh stage 1 (which needs a modern javac for
# --release). JAVA8_HOME points at the image JDK.
#
# R3: the image runs as a non-root `builder` user so bind-mounted checkouts
# (C3_DIR, /w) keep host ownership — pre-R3 images wrote build/ as root and
# poisoned the shared cache. Match the host user at build time
# (--build-arg UID/GID below); a conflicting id fails the build loudly,
# never silently.
#
# Build (from a checkout parent holding the 5 sibling repos):
#   docker build -f bridge-1122/tools/live/Dockerfile \
#     --build-arg UID=$(id -u) --build-arg GID=$(id -g) -t matou-live-1122 .
#
# First run (network once to provision C3_DIR cache: 2860 installer +
# vanilla server + MCP mappings):
#   docker run --rm -v "$PWD:/w" -v matou-c3:/tmp/matou-c3-live \
#     -w /w/bridge-1122 matou-live-1122
#
# Offline re-run (cache already provisioned):
#   docker run --rm -v "$PWD:/w" -v matou-c3:/tmp/matou-c3-live \
#     -e C3_OFFLINE=1 -w /w/bridge-1122 matou-live-1122
#
# Root-owned `build/` leftovers in an old cache must be cleared once
# (rm or fresh C3_DIR): run-live.sh refuses to build over them loudly.
#
# No machine paths inside the image: Java 8 + python3 + curl + git only
# (git serves the R2 release guards: VERSION + clean-tree checks).
# Pins live in tools/run-live.sh, not here. Unlike bridge-1710, no SRG
# file is mounted: the MCP->SRG narrow map derives from the pinned
# installer + MCP config inside the run.
# Repro pin (multi-arch index digest): same tag == same bytes.
# Refresh deliberately (Docker Hub API), never silently.
FROM eclipse-temurin:8-jdk-jammy@sha256:0d568cc4232ceb9ed2b5def9647c8f505ff504e8b21e3558e7a89ec59cd9ed0c
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 curl ca-certificates git \
 && rm -rf /var/lib/apt/lists
ENV JAVA8_HOME=/opt/java/openjdk
ARG UID=1000
ARG GID=1000
RUN groupadd -g "$GID" builder \
 && useradd -m -u "$UID" -g "$GID" -s /bin/bash builder \
 && mkdir -p /w/bridge-1122 && chown builder:builder /w /w/bridge-1122
USER builder
WORKDIR /w/bridge-1122
CMD ["sh", "tools/run-live.sh"]
