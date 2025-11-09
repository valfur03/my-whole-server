FROM authelia/authelia:4.39.14@sha256:88f1494b6ac1174641770f106335ab67752d66e5822b4059badca220b5d6153b

RUN set -eux; \
	apk add --no-cache gettext

COPY ./my-entrypoint.sh ./my-entrypoint.sh
COPY ./config /config

CMD ["./my-entrypoint.sh", "authelia", "--config", "/config/configuration.yml,/config/configuration.acl.yml"]
