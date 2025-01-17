FROM jaegertracing/all-in-one:1.65.0@sha256:12fa17a231abded2c3b5b715bd252a043678495c588cbe772173991fbdcdf7c8

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
