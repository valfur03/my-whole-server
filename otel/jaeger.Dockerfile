FROM jaegertracing/all-in-one:1.76.0@sha256:ab6f1a1f0fb49ea08bcd19f6b84f6081d0d44b364b6de148e1798eb5816bacac

USER root
RUN set -eux; \
	mkdir -p /badger; \
	chown -R 10001:10001 /badger

USER 10001
