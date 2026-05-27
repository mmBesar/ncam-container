# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – build NCam from source
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:edge AS builder

# Build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    libcrypto3 \
    openssl-dev \
    libusb-dev \
    pcsc-lite-dev \
    linux-headers

# Copy NCam source (synced from fairbird/NCam via upstream branch)
WORKDIR /build
COPY . .

# Compile NCam with EMU support
# USE_SSL=1        – HTTPS webif + reader TLS
# USE_LIBUSB=1     – Smargo / USB smartcard readers
# USE_PCSC=1       – PC/SC smartcard readers
# USE_EMU=1        – built-in EMU (the whole point of NCam over OSCam)
# CONF_DIR          – default config directory inside container
RUN make \
    USE_SSL=1 \
    USE_LIBUSB=1 \
    USE_PCSC=1 \
    USE_EMU=1 \
    CONF_DIR=/etc/ncam \
    -j"$(nproc)"

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – lean runtime image
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:edge

LABEL org.opencontainers.image.title="ncam-container" \
      org.opencontainers.image.description="NCam softcam (fairbird/NCam) with EMU — multi-arch container" \
      org.opencontainers.image.source="https://github.com/mmBesar/ncam-container" \
      org.opencontainers.image.licenses="GPL-2.0"

# Runtime dependencies + tini + tzdata
RUN apk add --no-cache \
    libcrypto3 \
    libssl3 \
    libusb \
    pcsc-lite-libs \
    tzdata \
    tini

# Copy compiled binary
COPY --from=builder /build/ncam /usr/local/bin/ncam
RUN chmod 755 /usr/local/bin/ncam

# Create ncam system user (UID 2000 — overridden at runtime via PUID/PGID)
RUN addgroup -g 2000 ncam && \
    adduser -D -u 2000 -G ncam -s /sbin/nologin ncam

# Config and log directories
RUN mkdir -p /etc/ncam /var/log/ncam && \
    chown -R ncam:ncam /etc/ncam /var/log/ncam

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Config persisted; logs optional (can also stdout via -r 0)
VOLUME ["/etc/ncam"]

# NCam web interface default port
EXPOSE 8888

# PUID/PGID – runtime user remapping (non-negotiable)
ENV PUID=2000 \
    PGID=2000 \
    TZ=UTC

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
