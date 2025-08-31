FROM jaegertracing/all-in-one:1.72.0@sha256:144b7028db6045b28b50c4728dd3bea14fa76ab024b64afeccec51c8cb1edd63

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
