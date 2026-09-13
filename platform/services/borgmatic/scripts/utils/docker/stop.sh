#!/bin/sh

. utils/docker/socket.sh

docker_stop()
{
    CONTAINER=$1
    STOP_RESPONSE=$(docker_socket POST "/containers/$CONTAINER/stop")
    if [[ $? -ne 0 ]]; then
        printf "Unable to complete docker stop\n"
        return 1
    fi
}
