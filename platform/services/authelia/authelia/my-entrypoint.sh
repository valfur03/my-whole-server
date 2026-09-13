#!/bin/sh
set -eu

# Templated ACL: substitute the two required vars with busybox sed.
# (The upstream Authelia image dropped envsubst when it switched to a
# busybox-based base in v4.39.x.)
sed \
	-e "s|\${BASE_DOMAIN}|${BASE_DOMAIN}|g" \
	-e "s|\${HOST_IP}|${HOST_IP}|g" \
	/config/configuration.acl.template.yml \
	> /config/configuration.acl.yml

exec "$@"
