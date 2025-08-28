FROM jaegertracing/all-in-one:1.58.0@sha256:1f6ee90a3f487dfd5e7430aaace16a83b55251d2c5493b14c1744d29f933fedd

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
