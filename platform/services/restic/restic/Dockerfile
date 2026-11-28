FROM creativeprojects/resticprofile:0.34.0@sha256:f5495831c9ebed368c4241a58752475a90cbbabd1db6c81931933881e6d231d6

RUN apk add --no-cache docker-cli
COPY crontab /etc/crontabs/root

ENTRYPOINT ["crond", "-f", "-L", "/dev/stdout"]
