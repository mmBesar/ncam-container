#!/bin/sh
set -e

# ─────────────────────────────────────────────────────────────────────────────
# PUID / PGID remapping
# ─────────────────────────────────────────────────────────────────────────────
PUID=${PUID:-2000}
PGID=${PGID:-2000}

echo "[ncam] Starting with UID=${PUID}, GID=${PGID}, TZ=${TZ}"

# Remap group
if ! getent group ncam > /dev/null 2>&1; then
    addgroup -g "${PGID}" ncam
else
    groupmod -g "${PGID}" ncam 2>/dev/null || true
fi

# Remap user
if ! getent passwd ncam > /dev/null 2>&1; then
    adduser -D -u "${PUID}" -G ncam -s /sbin/nologin ncam
else
    usermod -u "${PUID}" -g "${PGID}" ncam 2>/dev/null || true
fi

# Fix ownership of writable dirs
chown -R ncam:ncam /etc/ncam /var/log/ncam

# ─────────────────────────────────────────────────────────────────────────────
# Launch NCam as remapped user
# -b  run in background (disabled — let tini/Docker manage the process)
# -r 0  log to stdout (Docker-native logging)
# -c  config dir
# -t  temp/log dir
# ─────────────────────────────────────────────────────────────────────────────
exec su-exec ncam ncam \
    -c /etc/ncam \
    -t /var/log/ncam \
    -r 0 \
    "$@"
