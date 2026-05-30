FROM ghcr.io/stuffanthings/qbit_manage:v4.7.1@sha256:56e1eeec5582e202e82479b42b588e3807ececca25716f91c7a29f5c597c55d0

COPY config.yml /defaults/config.yml
COPY init.sh /init.sh
RUN chmod 0755 /init.sh

ENTRYPOINT ["/sbin/tini", "-s", "/init.sh"]
CMD ["python3", "qbit_manage.py"]
