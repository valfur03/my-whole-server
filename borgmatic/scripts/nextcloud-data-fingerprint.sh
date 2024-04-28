#!/bin/sh

cd $(dirname $0)

. utils/docker/exec.sh

NEXTCLOUD_CONTAINER_NAME="my-whole-server-nextcloud-app-1"

update_data_fingerprint()
{
    docker_exec $NEXTCLOUD_CONTAINER_NAME www-data php occ maintenance:data-fingerprint
}

update_data_fingerprint

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]
then
	printf "Unable to update data fingerprint... Command returned code %s" "$EXIT_CODE"
	exit 1
fi

printf "Done!\n"
exit 0
