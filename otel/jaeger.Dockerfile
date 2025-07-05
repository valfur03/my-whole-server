FROM jaegertracing/all-in-one:1.71.0@sha256:beb31282a9c5d0d10cb78dd168945dab9887acebb42fcc0bd738b08c36b68bc0

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
