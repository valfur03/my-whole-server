FROM authelia/authelia:4.37.5@sha256:25fc5423238b6f3a1fc967fda3f6a9212846aeb4a720327ef61c8ccff52dbbe2

RUN set -eux; \
	apk add --no-cache gettext

COPY ./my-entrypoint.sh ./my-entrypoint.sh
COPY ./config /config

CMD ["./my-entrypoint.sh", "authelia", "--config", "/config/configuration.yml,/config/configuration.acl.yml"]
