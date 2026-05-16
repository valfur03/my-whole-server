#!/bin/sh
set -eu

# Render a runtime .my.cnf from the password mounted at /run/secrets/.
# (prom/mysqld-exporter requires the password in a .my.cnf file — it has
# no PASSWORD_FILE env, and putting credentials in the DSN env var leaks
# them into `docker inspect`.)
PASSWORD="$(cat /run/secrets/NEXTCLOUD_STORAGE_PASSWORD)"
umask 0077
printf '[client]\nuser = nextcloud\npassword = %s\nhost = nextcloud-database\nport = 3306\n' "${PASSWORD}" > /tmp/.my.cnf

exec /bin/mysqld_exporter --config.my-cnf=/tmp/.my.cnf "$@"
