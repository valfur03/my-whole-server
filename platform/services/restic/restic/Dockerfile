FROM creativeprojects/resticprofile:0.33.1@sha256:b919f7ae7adfa4b0900ac87ab5314fb88229698b0a8d38ebc3882a27ac9e73d1

RUN apk add --no-cache docker-cli
COPY crontab /etc/crontabs/root

ENTRYPOINT ["crond", "-f", "-L", "/dev/stdout"]
