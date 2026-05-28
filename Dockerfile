# syntax=docker/dockerfile:1
# ─────────────────────────────────────────────────────────────────────────────
# Stage 1 – build NCam from source
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:edge AS builder

ENV MAKEFLAGS="-j$(nproc)"

RUN apk add --no-cache --virtual=build-dependencies \
    build-base \
    git \
    libusb-dev \
    linux-headers \
    openssl-dev \
    pcsc-lite-dev

# NCam source is the build context (upstream branch)
WORKDIR /build
COPY . .

# 1. Configure: enable all, disable hardware/platform-specific stuff not
#    relevant to a generic PC container (same pattern as linuxserver OSCam)
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

# 2. Compile: pcsc-libusb target, clean binary name, config dir
RUN make \
    CONF_DIR=/etc/ncam \
    NCAM_BIN=/usr/bin/ncam \
    pcsc-libusb

# ─────────────────────────────────────────────────────────────────────────────
# Stage 2 – lean runtime image
# ─────────────────────────────────────────────────────────────────────────────
FROM alpine:edge

LABEL org.opencontainers.image.title="ncam-container" \
      org.opencontainers.image.description="NCam softcam (fairbird/NCam) with EMU — multi-arch container" \
      org.opencontainers.image.source="https://github.com/mmBesar/ncam-container" \
      org.opencontainers.image.licenses="GPL-2.0"

RUN apk add --no-cache \
    ccid \
    libusb \
    openssl \
    pcsc-lite \
    pcsc-lite-libs \
    su-exec \
    tini \
    tzdata

COPY --from=builder /usr/bin/ncam /usr/bin/ncam
RUN chmod 755 /usr/bin/ncam

RUN addgroup -g 2000 ncam && \
    adduser -D -u 2000 -G ncam -s /sbin/nologin ncam

RUN mkdir -p /etc/ncam /var/log/ncam && \
    chown -R ncam:ncam /etc/ncam /var/log/ncam

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/etc/ncam"]

# NCam web interface default port
EXPOSE 8888

ENV PUID=2000 \
    PGID=2000 \
    TZ=UTC

ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
