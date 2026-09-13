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

for i in
do
	IFS=","
	set -- $i

	if [ -f "$SOURCE_DIRECTORY/$1" ]
	then
		mkdir -p "$DEST_ROOT/$(dirname "$2")"
		cp "$SOURCE_DIRECTORY/$1" "$DEST_ROOT/$2"
	fi
done
