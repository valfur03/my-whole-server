#!/bin/sh

# One-shot wrapper around icloudpd to download iCloud photos.
#
# Usage: icloud_photos_download.sh --user <apple-id> --dest <dir>
#                                  [--months N] [--until-found N]
#
# Pulls and runs `icloudpd/icloudpd:latest`. The auth cookie/session is
# persisted in ${XDG_CONFIG_HOME:-$HOME/.config}/icloudpd so 2FA is only
# required on the first run (Apple's trust token lasts ~30 days).
#
# --months N        download only assets created in the last N months
#                   (passed to icloudpd as --skip-created-before $((N*30))d)
# --until-found N   stop once N consecutive already-downloaded assets are
#                   seen, for fast incremental runs

set -eu

USERNAME=
DEST=
MONTHS=
UNTIL_FOUND=

usage() {
	printf 'usage: %s --user <apple-id> --dest <dir> [--months N] [--until-found N]\n' "$0" >&2
	exit 1
}

while [ $# -gt 0 ]
do
	case $1 in
		--user) USERNAME=$2; shift 2 ;;
		--dest) DEST=$2; shift 2 ;;
		--months) MONTHS=$2; shift 2 ;;
		--until-found) UNTIL_FOUND=$2; shift 2 ;;
		-h|--help) usage ;;
		*) usage ;;
	esac
done

[ -n "$USERNAME" ] || usage
[ -n "$DEST" ] || usage

mkdir -p "$DEST"
DEST=$(realpath "$DEST")

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/icloudpd
mkdir -p "$CONFIG_DIR"
chmod 700 "$CONFIG_DIR"

set -- \
	--directory /data \
	--username "$USERNAME" \
	--cookie-directory /config

if [ -n "$MONTHS" ]
then
	set -- "$@" --skip-created-before "$((MONTHS * 30))d"
fi

if [ -n "$UNTIL_FOUND" ]
then
	set -- "$@" --until-found "$UNTIL_FOUND"
fi

docker pull icloudpd/icloudpd:latest

exec docker run --rm -it \
	-v "$DEST:/data" \
	-v "$CONFIG_DIR:/config" \
	-e TZ="${TZ:-UTC}" \
	icloudpd/icloudpd:latest \
	icloudpd "$@"
