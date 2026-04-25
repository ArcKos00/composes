FROM docker.elastic.co/kibana/kibana:8.13.0

USER root

COPY K2-Root-CA.crt /usr/local/share/ca-certificates/K2-Root-CA.crt
RUN chmod 644 /usr/local/share/ca-certificates/K2-Root-CA.crt \
    && update-ca-certificates

# Kibana/Node trust
RUN mkdir -p /usr/share/kibana/config/certs
COPY K2-Root-CA.crt /usr/share/kibana/config/certs/K2-Root-CA.crt
RUN chmod 644 /usr/share/kibana/config/certs/K2-Root-CA.crt

ENV NODE_EXTRA_CA_CERTS=/usr/share/kibana/config/certs/K2-Root-CA.crt

COPY setup-apm.sh /usr/local/bin/setup-apm.sh
RUN chmod +x /usr/local/bin/setup-apm.sh

USER kibana

ENTRYPOINT ["/usr/local/bin/setup-apm.sh"]