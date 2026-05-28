#!/bin/sh
set -e

# ─────────────────────────────────────────────────────────────────────────────
# entrypoint.sh — NCam container startup script
#
# Creates/remaps the ncam user to match host PUID/PGID, fixes directory
# ownership, then launches NCam as that user via su-exec.
#
# Environment variables (set in docker-compose.yml):
#   PUID  — host user ID  (default: 1000)
#   PGID  — host group ID (default: 1000)
#   TZ    — timezone      (default: UTC)
# ─────────────────────────────────────────────────────────────────────────────

PUID=${PUID:-1000}
PGID=${PGID:-1000}

echo "[ncam] Starting as UID=${PUID} GID=${PGID} TZ=${TZ}"

# ── Remap user ────────────────────────────────────────────────────────────────
# Delete existing ncam user and group, then recreate with correct UID/GID.
# Must delete user before group (group can't be deleted while it has a member).
if getent passwd ncam > /dev/null 2>&1; then
    deluser ncam 2>/dev/null || true
fi
if getent group ncam > /dev/null 2>&1; then
    delgroup ncam 2>/dev/null || true
fi
addgroup -g "${PGID}" ncam
adduser -D -u "${PUID}" -G ncam -s /sbin/nologin ncam

# ── Fix ownership ─────────────────────────────────────────────────────────────
# Run as root here so we can always fix ownership regardless of previous state.
# Uses numeric PUID/PGID — not 'ncam:ncam' — to guarantee correct values.
chown -R "${PUID}:${PGID}" /etc/ncam /var/log/ncam

# ── Launch NCam ───────────────────────────────────────────────────────────────
# su-exec uses numeric UID/GID directly — bypasses any username resolution.
# -c  config directory (mounted volume)
# -t  temp/log directory
# -r 0  log to stdout — Docker handles log capture
exec su-exec "${PUID}:${PGID}" ncam \
    -c /etc/ncam \
    -t /var/log/ncam \
    -r 0 \
    "$@"
