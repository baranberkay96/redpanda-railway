# Single-node Redpanda for Railway with SASL/SCRAM authentication.
# Production mode (fsync on, no dev-container shortcuts), overprovisioned CPU sharing,
# bounded memory, listeners advertised under the Railway private domain and, when a
# TCP proxy is attached, under its public host/port.
FROM redpandadata/redpanda:v26.2.4

USER root
COPY --chmod=0755 railway-redpanda.sh /usr/local/bin/railway-redpanda.sh

EXPOSE 9092 9093 9644 8081 8082

# Starts as root only to fix ownership of the Railway volume, then drops to `redpanda`.
ENTRYPOINT ["/usr/local/bin/railway-redpanda.sh"]
