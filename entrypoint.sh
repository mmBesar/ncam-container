#!/bin/sh
set -e

# ─────────────────────────────────────────────────────────────────────────────
# PUID / PGID remapping
# ─────────────────────────────────────────────────────────────────────────────
PUID=${PUID:-2000}
PGID=${PGID:-2000}

echo "[ncam] UID=${PUID} GID=${PGID} TZ=${TZ}"

# Remap group
if getent group ncam > /dev/null 2>&1; then
    groupmod -g "${PGID}" ncam 2>/dev/null || true
else
    addgroup -g "${PGID}" ncam
fi

# Remap user
if getent passwd ncam > /dev/null 2>&1; then
    usermod -u "${PUID}" -g "${PGID}" ncam 2>/dev/null || true
else
    adduser -D -u "${PUID}" -G ncam -s /sbin/nologin ncam
fi

# Fix ownership of writable dirs
chown -R ncam:ncam /etc/ncam /var/log/ncam

# ─────────────────────────────────────────────────────────────────────────────
# Launch NCam as remapped user
#   -c  config directory
#   -t  temp/log directory
#   -r 0  log rotation off — let Docker capture stdout
# ─────────────────────────────────────────────────────────────────────────────
exec su-exec ncam:ncam ncam \
    -c /etc/ncam \
    -t /var/log/ncam \
    -r 0 \
    "$@"
