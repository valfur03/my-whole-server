FROM jaegertracing/all-in-one:1.70.0@sha256:c73bec5e6220b91eeda2574ec6aabbb8232f531e6b0bd11819f53548eefa6424

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
