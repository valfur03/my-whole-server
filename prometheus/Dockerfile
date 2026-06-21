FROM prom/prometheus:v2.55.1@sha256:2659f4c2ebb718e7695cb9b25ffa7d6be64db013daba13e05c875451cf51b0d3

USER root
COPY prometheus.yml /etc/prometheus/prometheus.template.yml
COPY rules/ /etc/prometheus/rules/
COPY entrypoint.sh /entrypoint.sh
RUN chmod 0755 /entrypoint.sh
USER nobody

ENTRYPOINT ["/entrypoint.sh"]
