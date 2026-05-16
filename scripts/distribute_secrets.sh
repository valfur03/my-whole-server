#!/bin/sh

# Copy a flat directory of secret files into the per-service layout expected
# by compose.yaml's `secrets:` block.
#
# Usage: distribute_secrets.sh <source_dir> [<dest_root>]
#
# - <source_dir> is interpreted relative to the current working directory.
# - <dest_root> defaults to the repo root (parent of this script's directory).
#   In prod with doco-cd, set this to /etc/my-whole-server/ so files land in
#   the host-managed dir referenced by ${SECRETS_DIR} in compose.yaml.
#
# Source-side filenames are flat (e.g. AUTHELIA_JWT_SECRET); destination paths
# match what compose.yaml's `secrets: file:` references resolve to.

set -eu

if [ $# -lt 1 ] || [ $# -gt 2 ]
then
	printf 'usage: %s <source_dir> [<dest_root>]\n' "$0" >&2
	exit 1
fi

SOURCE_DIRECTORY=$1
DEST_ROOT=${2:-$(dirname "$(dirname "$(realpath "$0")")")}

for i in \
	AUTHELIA_JWT_SECRET,authelia/secrets/JWT_SECRET \
	AUTHELIA_SESSION_SECRET,authelia/secrets/SESSION_SECRET \
	AUTHELIA_STORAGE_ENCRYPTION_KEY,authelia/secrets/STORAGE_ENCRYPTION_KEY \
	AUTHELIA_STORAGE_PASSWORD,authelia/secrets/STORAGE_PASSWORD \
	BORGMATIC_ENCRYPTION_PASSPHRASE,borgmatic/secrets/ENCRYPTION_PASSPHRASE \
	LDAP_ADMIN_PASSWORD,ldap/secrets/ADMIN_PASSWORD \
	NEXTCLOUD_STORAGE_PASSWORD,nextcloud/secrets/STORAGE_PASSWORD \
	SMTP_PASSWORD,secrets/SMTP_PASSWORD \
	SYNAPSE_STORAGE_PASSWORD,synapse/secrets/STORAGE_PASSWORD \
	VAULTWARDEN_ADMIN_TOKEN,vaultwarden/secrets/ADMIN_TOKEN \
	OVH_APPLICATION_KEY,ovh/secrets/APPLICATION_KEY \
	OVH_APPLICATION_SECRET,ovh/secrets/APPLICATION_SECRET \
	OVH_CONSUMER_KEY,ovh/secrets/CONSUMER_KEY \
	DOCO_CD_GIT_ACCESS_TOKEN,doco-cd/secrets/GIT_ACCESS_TOKEN \
	DOCO_CD_WEBHOOK_SECRET,doco-cd/secrets/WEBHOOK_SECRET \
	DOCO_CD_SOPS_AGE_KEY,doco-cd/secrets/SOPS_AGE_KEY \
	DOCO_CD_DOCKER_CONFIG,doco-cd/secrets/DOCKER_CONFIG \
	SEEDBOX_OPENVPN_CONFIG,seedbox/secrets/OPENVPN_CONFIG \
	BORGMATIC_SSH_PRIVATE_KEY,borgmatic/secrets/SSH_PRIVATE_KEY \
	BORGMATIC_SSH_KNOWN_HOSTS,borgmatic/secrets/SSH_KNOWN_HOSTS
do
	IFS=","
	set -- $i

	if [ -f "$SOURCE_DIRECTORY/$1" ]
	then
		mkdir -p "$DEST_ROOT/$(dirname "$2")"
		cp "$SOURCE_DIRECTORY/$1" "$DEST_ROOT/$2"
	fi
done
