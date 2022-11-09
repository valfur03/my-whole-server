FROM golang:1.19.3-bullseye

RUN set -eux; \
	git clone https://github.com/metalmatze/transmission-exporter; \
	make -C transmission-exporter; \
	cp bin/transmission-exporter /usr/bin/transmission-exporter

EXPOSE 19091

ENTRYPOINT ["/usr/bin/transmission-exporter"]
