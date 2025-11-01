FROM jaegertracing/all-in-one:1.74.0@sha256:c87fc1d9b22766284168abb2ac57ac2160dfc26484e4f965ff2dcc6b849b263a

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
