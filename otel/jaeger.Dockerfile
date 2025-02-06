FROM jaegertracing/all-in-one:1.66.0@sha256:9864182b4e01350fcc64631bdba5f4085f87daae9d477a04c25d9cb362e787a9

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
