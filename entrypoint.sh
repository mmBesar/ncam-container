#!/bin/sh
set -e

# ─────────────────────────────────────────────────────────────────────────────
# entrypoint.sh — NCam container startup script
#
# Remaps the internal 'ncam' user/group to match the host PUID/PGID,
# fixes directory ownership, then launches NCam as that user.
#
# Environment variables:
#   PUID  — host user ID to run NCam as (default: 1000)
#   PGID  — host group ID to run NCam as (default: 1000)
#   TZ    — timezone (default: UTC)
# ─────────────────────────────────────────────────────────────────────────────

PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "[ncam] Starting as UID=${PUID} GID=${PGID} TZ=${TZ}"

# ── Remap group ───────────────────────────────────────────────────────────────
# If the ncam group already exists, update its GID.
# Otherwise create it fresh with the desired GID.
if getent group ncam > /dev/null 2>&1; then
    groupmod -g "${PGID}" ncam 2>/dev/null || true
else
    addgroup -g "${PGID}" ncam
fi

# ── Remap user ────────────────────────────────────────────────────────────────
# Same logic for the ncam user — update UID/GID if exists, create if not.
if getent passwd ncam > /dev/null 2>&1; then
    usermod -u "${PUID}" -g "${PGID}" ncam 2>/dev/null || true
else
    adduser -D -u "${PUID}" -G ncam -s /sbin/nologin ncam
fi

# ── Fix ownership ─────────────────────────────────────────────────────────────
# Use numeric PUID/PGID directly — NOT 'ncam:ncam' — so ownership is always
# correct regardless of remap timing. This prevents the config dir from being
# owned by the wrong UID on the host after container restart.
chown -R "${PUID}:${PGID}" /etc/ncam /var/log/ncam

# ── Launch NCam ───────────────────────────────────────────────────────────────
# su-exec drops root and runs NCam as the remapped ncam user.
#   -c  config directory (mounted volume)
#   -t  temp/log directory
#   -r 0  disable log rotation — Docker handles log capture via stdout
exec su-exec ncam:ncam ncam \
    -c /etc/ncam \
    -t /var/log/ncam \
    -r 0 \
    "$@"
