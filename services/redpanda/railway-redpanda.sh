#!/bin/bash
# Redpanda on Railway: renders redpanda.yaml + the first-boot cluster config from the
# environment and starts a single production-mode broker.
#
# Listeners (all SASL/SCRAM or HTTP Basic with the same users):
#   9092  Kafka API "internal"  advertised as ${RAILWAY_PRIVATE_DOMAIN}:9092
#   9093  Kafka API "external"  advertised as ${RAILWAY_TCP_PROXY_DOMAIN}:${RAILWAY_TCP_PROXY_PORT}
#                               when a TCP proxy targets port 9093, else as the private domain
#   9644  Admin API (auth required), 8081 Schema Registry, 8082 HTTP Proxy
set -euo pipefail

fail() { echo "FATAL: $*" >&2; exit 1; }

: "${KAFKA_SASL_USERNAME:?KAFKA_SASL_USERNAME must be set}"
: "${KAFKA_SASL_PASSWORD:?KAFKA_SASL_PASSWORD must be set}"
case "$KAFKA_SASL_USERNAME$KAFKA_SASL_PASSWORD" in
  *:*|*' '*) fail "KAFKA_SASL_USERNAME/PASSWORD must not contain ':' or spaces" ;;
esac
MECHANISM="${KAFKA_SASL_MECHANISM:-SCRAM-SHA-256}"
case "$MECHANISM" in SCRAM-SHA-256|SCRAM-SHA-512) ;; *) fail "KAFKA_SASL_MECHANISM must be SCRAM-SHA-256 or SCRAM-SHA-512" ;; esac

DATA_DIR=/var/lib/redpanda/data
PRIVATE_HOST="${RAILWAY_PRIVATE_DOMAIN:-$(hostname)}"
if [ -n "${RAILWAY_TCP_PROXY_DOMAIN:-}" ] && [ -n "${RAILWAY_TCP_PROXY_PORT:-}" ]; then
  EXTERNAL_HOST="$RAILWAY_TCP_PROXY_DOMAIN"
  EXTERNAL_PORT="$RAILWAY_TCP_PROXY_PORT"
else
  EXTERNAL_HOST="$PRIVATE_HOST"
  EXTERNAL_PORT=9093
fi
SMP="${REDPANDA_SMP:-1}"
MEMORY="${REDPANDA_MEMORY:-1G}"
AUTO_CREATE="${KAFKA_AUTO_CREATE_TOPICS:-false}"
RETENTION_MS="${KAFKA_LOG_RETENTION_MS:-604800000}"

mkdir -p "$DATA_DIR"
rm -rf "$DATA_DIR/lost+found" 2>/dev/null || true
if [ "$(stat -c %u "$DATA_DIR")" != "$(id -u redpanda)" ]; then
  chown -R redpanda:redpanda "$DATA_DIR"
fi

cat > /etc/redpanda/redpanda.yaml <<EOT
redpanda:
  data_directory: ${DATA_DIR}
  empty_seed_starts_cluster: true
  seed_servers: []
  rpc_server:
    address: 0.0.0.0
    port: 33145
  advertised_rpc_api:
    address: 127.0.0.1
    port: 33145
  kafka_api:
    - name: internal
      address: 0.0.0.0
      port: 9092
      authentication_method: sasl
    - name: external
      address: 0.0.0.0
      port: 9093
      authentication_method: sasl
  advertised_kafka_api:
    - name: internal
      address: ${PRIVATE_HOST}
      port: 9092
    - name: external
      address: ${EXTERNAL_HOST}
      port: ${EXTERNAL_PORT}
  admin:
    - address: 0.0.0.0
      port: 9644
pandaproxy:
  pandaproxy_api:
    - address: 0.0.0.0
      port: 8082
      authentication_method: http_basic
schema_registry:
  schema_registry_api:
    - address: 0.0.0.0
      port: 8081
      authentication_method: http_basic
rpk:
  kafka_api:
    brokers: ["127.0.0.1:9092"]
    sasl:
      user: ${KAFKA_SASL_USERNAME}
      password: ${KAFKA_SASL_PASSWORD}
      mechanism: ${MECHANISM}
  admin_api:
    addresses: ["127.0.0.1:9644"]
EOT

# Cluster properties applied when the cluster is created (first start on an empty volume).
cat > /etc/redpanda/.bootstrap.yaml <<EOT
enable_sasl: true
sasl_mechanisms: ["SCRAM"]
superusers: ["${KAFKA_SASL_USERNAME}"]
admin_api_require_auth: true
auto_create_topics_enabled: ${AUTO_CREATE}
default_topic_replications: 1
log_retention_ms: ${RETENTION_MS}
EOT
chown redpanda:redpanda /etc/redpanda/redpanda.yaml /etc/redpanda/.bootstrap.yaml
chmod 0600 /etc/redpanda/redpanda.yaml /etc/redpanda/.bootstrap.yaml

# Creates the SCRAM superuser when the cluster is bootstrapped.
export RP_BOOTSTRAP_USER="${KAFKA_SASL_USERNAME}:${KAFKA_SASL_PASSWORD}:${MECHANISM}"
export HOME=/var/lib/redpanda

echo "railway: starting Redpanda (internal ${PRIVATE_HOST}:9092, external ${EXTERNAL_HOST}:${EXTERNAL_PORT}, smp ${SMP}, memory ${MEMORY})"
exec setpriv --reuid=redpanda --regid=redpanda --init-groups \
  rpk redpanda start \
    --config /etc/redpanda/redpanda.yaml \
    --smp "$SMP" \
    --memory "$MEMORY" \
    --reserve-memory 0M \
    --overprovisioned \
    --default-log-level="${REDPANDA_LOG_LEVEL:-info}"
