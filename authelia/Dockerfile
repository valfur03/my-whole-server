FROM authelia/authelia:4.37.5

RUN set -eux; \
	apk add --no-cache gettext

COPY ./my-entrypoint.sh ./my-entrypoint.sh
COPY ./config /config

CMD ["./my-entrypoint.sh", "authelia", "--config", "/config/configuration.yml,/config/configuration.acl.yml"]
