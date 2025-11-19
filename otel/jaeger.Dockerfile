FROM jaegertracing/all-in-one:1.75.0@sha256:e493bff54e457ba5827f82418d744a322165cd5d46146607fb76489bfb2a8885

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
