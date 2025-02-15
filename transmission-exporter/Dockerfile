FROM golang:1.21.5-alpine3.17@sha256:92cb87af996ec6befc85f0aec27e12ead2fab396695fa8a7abff79e021e58195

RUN set -eux; \
	apk add \
		git \
		make

RUN set -eux; \
	git clone https://github.com/metalmatze/transmission-exporter; \
	make -C transmission-exporter; \
	cp bin/transmission-exporter /usr/bin/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/usr/bin/transmission-exporter"]
