#!/bin/sh

cd $(dirname $0)

. utils/docker/exec.sh

NEXTCLOUD_CONTAINER_NAME="my-whole-server-nextcloud-app-1"

set_nextcloud_maintenance()
{
	MODE=$1
    docker_exec $NEXTCLOUD_CONTAINER_NAME www-data php occ maintenance:mode --$MODE
}

if [ $# -ge 1 ] && [ "$1" == "off" ]
then
    printf "Disabling Nextcloud maintenance mode...\n"
	set_nextcloud_maintenance off
else
    printf "Enabling Nextcloud maintenance mode...\n"
	set_nextcloud_maintenance on
fi

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]
then
	printf "Unable to set maintenance mode... Command returned code %s" "$EXIT_CODE"
	exit 1
fi

printf "Done!\n"
exit 0
