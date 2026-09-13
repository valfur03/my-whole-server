#!/bin/sh

. utils/docker/socket.sh

docker_exec()
{
    CONTAINER=$1
    USER=$2
    shift 2
    ARGS=$@
    COMMAND=$(echo $ARGS | sed 's/\ /", "/g')
    [ $USER != '--' ] && USER_PARAM=", \"User\": \"$USER\""
    EXEC_RESPONSE=$(docker_socket POST "/containers/$CONTAINER/exec" "{\"AttachStdout\": true, \"Tty\": true, \"Cmd\": [\"$COMMAND\"]${USER_PARAM:-}}")
    if [[ $? -ne 0 ]]; then
        printf "Unable to complete docker exec with command: %s \n" "$ARGS"
        return 1
    fi
    EXEC_ID=$(echo $EXEC_RESPONSE | python -c 'import json, sys; print(json.loads(sys.stdin.read())["Id"]);')
    docker_socket POST "/exec/$EXEC_ID/start" '{"Detach": false, "Tty": true}'
    EXEC_JSON_RESPONSE=$(docker_socket GET "/exec/$EXEC_ID/json")
    if [[ $? -ne 0 ]]; then
        printf "Unable to read response from docker exec with command: %s" "$ARGS"
        return 1
    fi
    EXIT_CODE=$(echo $EXEC_JSON_RESPONSE | python -c 'import json, sys; print(json.loads(sys.stdin.read())["ExitCode"]);')
    return $EXIT_CODE
}
