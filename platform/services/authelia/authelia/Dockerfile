FROM authelia/authelia:4.39.19@sha256:0c824dcab1ae97c56bf673c5e77fe8cc6bcd400564555140cc8002a12c6b6463

COPY ./my-entrypoint.sh ./my-entrypoint.sh
COPY ./config /config

CMD ["./my-entrypoint.sh", "authelia", "--config", "/config/configuration.yml,/config/configuration.acl.yml"]
