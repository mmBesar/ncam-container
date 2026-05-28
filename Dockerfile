# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 — Build NCam from source
#
# Uses Alpine edge as build environment.
# NCam source comes from the upstream branch (build context = src/).
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:edge AS builder

# Build dependencies:
#   build-base      — gcc, make, libc-dev
#   git             — needed by NCam's Makefile for version info
#   libdvbcsa-dev   — DVB Common Scrambling Algorithm (needed for DVBAPI)
#   libusb-dev      — USB smartcard readers (Smargo etc.)
#   linux-headers   — kernel headers for DVB/USB interfaces
#   openssl         — runtime ssl libs needed at build time
#   openssl-dev     — SSL headers for HTTPS webif + reader TLS
#   pcsc-lite-dev   — PC/SC smartcard reader support
RUN apk add --no-cache \
    build-base \
    git \
    libdvbcsa-dev \
    libusb-dev \
    linux-headers \
    openssl \
    openssl-dev \
    pcsc-lite-dev

# NCam source is copied from the build context (upstream branch via workflow)
WORKDIR /build
COPY . .

# Step 1 — Configure NCam features
# Enable everything, then disable hardware/platform stuff not relevant
# to a generic PC/server container (no LCD, LED, STB hardware, etc.)
RUN ./config.sh \
    --enable all \
    --disable \
        CARDREADER_DB2COM \
        CARDREADER_INTERNAL \
        CARDREADER_STAPI \
        CARDREADER_STAPI5 \
        CARDREADER_STINGER \
        IPV6SUPPORT \
        LCDSUPPORT \
        LEDSUPPORT \
        READ_SDT_CHARSETS

# Step 2 — Compile NCam
# pcsc-libusb  — build target that includes PCSC and libusb support
# CONF_DIR     — default config directory inside the container
# NCAM_BIN     — output binary path (default would be ncam-<ver>-<rev>-<arch>)
# EXTRA_FLAGS  — PCSC headers location on Alpine
RUN make \
    CONF_DIR=/etc/ncam \
    NCAM_BIN=/usr/bin/ncam \
    EXTRA_FLAGS="-I/usr/include/PCSC" \
    pcsc-libusb

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 — Lean runtime image
#
# Only the compiled binary + runtime libraries. No build tools.
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:edge

LABEL org.opencontainers.image.title="ncam-container" \
      org.opencontainers.image.description="NCam softcam (fairbird/NCam) with EMU — multi-arch container" \
      org.opencontainers.image.source="https://github.com/mmBesar/ncam-container" \
      org.opencontainers.image.licenses="GPL-2.0"

# Runtime dependencies:
#   ccid          — USB CCID smartcard reader driver
#   libdvbcsa     — DVB Common Scrambling Algorithm runtime
#   libusb        — USB smartcard reader runtime
#   openssl       — SSL runtime for HTTPS webif
#   pcsc-lite     — PC/SC smartcard daemon
#   pcsc-lite-libs — PC/SC runtime libraries
#   su-exec       — drop root privileges cleanly before exec
#   tini          — minimal init (PID 1) for proper signal handling
#   tzdata        — timezone data for TZ env variable
RUN apk add --no-cache \
    ccid \
    libdvbcsa \
    libusb \
    openssl \
    pcsc-lite \
    pcsc-lite-libs \
    su-exec \
    tini \
    tzdata

# Copy compiled binary from build stage
COPY --from=builder /usr/bin/ncam /usr/bin/ncam
RUN chmod 755 /usr/bin/ncam

# Create ncam system user and group with UID/GID 1000 (most common host user).
# The entrypoint remaps these to PUID/PGID at runtime, so this is just
# a safe default used if PUID/PGID are not set.
RUN addgroup -g 1000 ncam && \
    adduser -D -u 1000 -G ncam -s /sbin/nologin ncam

# Create config and log directories, set initial ownership
RUN mkdir -p /etc/ncam /var/log/ncam && \
    chown -R ncam:ncam /etc/ncam /var/log/ncam

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# /etc/ncam holds all NCam config files (ncam.conf, ncam.server,
# ncam.user, SoftCam.Key, etc.) — mount this as a volume to persist config
VOLUME ["/etc/ncam"]

# NCam web interface default port is 8181 (set via httpport in ncam.conf)
EXPOSE 8181

# Default UID/GID — override in compose with PUID/PGID env vars
# TZ — timezone, e.g. Africa/Cairo
ENV PUID=1000 \
    PGID=1000 \
    TZ=UTC

# tini as PID 1 ensures clean signal handling and zombie reaping
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
