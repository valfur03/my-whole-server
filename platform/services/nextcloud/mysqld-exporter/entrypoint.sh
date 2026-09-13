#!/bin/sh
set -eu

# Render a runtime .my.cnf from the password in the environment.
# (prom/mysqld-exporter requires the password in a .my.cnf file — it has
# no PASSWORD_FILE env, and putting credentials in the DSN env var leaks
# them into `docker inspect`.)
umask 0077
printf '[client]\nuser = nextcloud\npassword = %s\nhost = database\nport = 3306\n' "${MYSQL_PASSWORD}" > /tmp/.my.cnf

exec /bin/mysqld_exporter --config.my-cnf=/tmp/.my.cnf "$@"
