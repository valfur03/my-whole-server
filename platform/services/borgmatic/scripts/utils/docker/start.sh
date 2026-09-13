#!/bin/sh

. utils/docker/socket.sh

docker_start()
{
    CONTAINER=$1
    START_RESPONSE=$(docker_socket POST "/containers/$CONTAINER/start")
    if [[ $? -ne 0 ]]; then
        printf "Unable to complete docker start\n"
        return 1
    fi
}
