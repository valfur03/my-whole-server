#!/bin/sh
set -e

# Render ${BASE_DOMAIN} (and any other env vars referenced as ${VAR}) into the
# active prometheus.yml. busybox sh + sed are sufficient — no envsubst install
# required on the prom/prometheus base image.
sed "s|\${BASE_DOMAIN}|${BASE_DOMAIN}|g" /etc/prometheus/prometheus.template.yml > /etc/prometheus/prometheus.yml

exec /bin/prometheus "$@"
