#!/bin/sh

set -eux

cd $(dirname $0)

. utils/docker/start.sh

VAULTWARDEN_CONTAINER_NAME="my-whole-server-vaultwarden-1"

set_vaultwarden_maintenance()
{
	MODE=$1
	if [ "$MODE" == "off" ]
	then
		docker_start $VAULTWARDEN_CONTAINER_NAME
	else
		docker_stop $VAULTWARDEN_CONTAINER_NAME
	fi
}

if [ $# -ge 1 ] && [ "$1" == "off" ]
then
	printf "Starting up Vaultwarden...\n"
	set_vaultwarden_maintenance off
else
	printf "Shutting down Vaultwarden...\n"
	set_vaultwarden_maintenance on
fi

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]
then
	printf "Unable to manage the container... Command returned code %s" "$EXIT_CODE"
	exit 1
fi

printf "Done!\n"
exit 0
