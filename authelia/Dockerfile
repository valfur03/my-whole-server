FROM authelia/authelia:4.38.18@sha256:a5e6fa4b1dbdc296f80f9175157b145a0598690ec8cd4d6e105cd4498fe0c731

RUN set -eux; \
	apk add --no-cache gettext

COPY ./my-entrypoint.sh ./my-entrypoint.sh
COPY ./config /config

CMD ["./my-entrypoint.sh", "authelia", "--config", "/config/configuration.yml,/config/configuration.acl.yml"]
