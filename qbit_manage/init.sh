#!/bin/bash
set -euo pipefail

cp /defaults/config.yml /config/config.yml
chown -R "${PUID:-1000}:${PGID:-1000}" /config

exec /app/entrypoint.sh "$@"
