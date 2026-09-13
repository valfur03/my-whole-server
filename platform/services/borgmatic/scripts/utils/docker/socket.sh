#!/bin/sh

DOCKER_API_VERSION="1.41"

docker_socket()
{
	[ $# -lt 2 ] && return 1

    METHOD="$1"
    URI="$2"
	DATA=""
	[ $# -ge 3 ] && DATA="$3"
    curl -fs --unix-socket /var/run/docker.sock "http:/v$DOCKER_API_VERSION$URI" -X$METHOD \
        -H "Content-Type: application/json" \
        -d "$DATA"
}
