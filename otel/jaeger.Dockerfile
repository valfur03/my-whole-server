FROM jaegertracing/all-in-one:1.58.0

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
