FROM creativeprojects/resticprofile:0.33.1@sha256:4c235a1448bea30d69375033fb5c6eb37724e2b155f6ab10fbf8d18c8cf4a347

RUN apk add --no-cache docker-cli
COPY crontab /etc/crontabs/root

ENTRYPOINT ["crond", "-f", "-L", "/dev/stdout"]
