# Redpanda v26 Kafka-Compatible Streaming — Railway template spec

## Listing

- **Name:** Redpanda v26 Kafka-Compatible Streaming (LISTINGS_ROUND2 base name with the pinned major, Redpanda's own `v` convention: `v26.2.4`).
- **Description (64 chars):** Kafka API streaming with Redpanda Console. No ZooKeeper, no JVM.
- **Category:** Queues
- **Tags:** redpanda, kafka, streaming, event-streaming, message-queue, schema-registry, console
- **Template repo:** `baranberkay96/redpanda-railway` (this folder)

## Base market template

There is no Redpanda template on the marketplace; the three top results are Apache Kafka templates:

| Code | What it is | Taken |
|---|---|---|
| `K5vWpm` "Kafka" (104 active) | Kafka + ZooKeeper + demo producer/consumer from `oussamajabnouni/railway-kafka` (no license) | Nothing (ZooKeeper-era Kafka, demo apps, no auth, no volume) |
| `NyB5Jd` "Simple Kafka" (37 active) | `apache/kafka:latest` KRaft, internal + TCP-proxy listener, no auth, no volume | The listener pattern: an internal listener advertised under the private domain and a second listener advertised under `RAILWAY_TCP_PROXY_DOMAIN:RAILWAY_TCP_PROXY_PORT` |
| `kafka` "Apache Kafka — ..." (12 active) | `apache/kafka:latest` KRaft with a volume and a TCP proxy on a PLAINTEXT listener | Same listener idea; `lost+found` cleanup |

All three expose Kafka without authentication (two of them through a public TCP proxy) and use floating `latest` tags. Ideas only; no files or text copied.

## Pinned versions

| Service | Image | Tag | Released |
|---|---|---|---|
| redpanda (`services/redpanda`) | `redpandadata/redpanda` | `v26.2.4` | 2026-10-06 |
| console | `redpandadata/console` | `v3.12.0` | 2026-09-16 |
| console-gateway (`services/console-gateway`) | `caddy` | `2.11.7-alpine` | 2026 |

Checked 2026-10-11.

## Architecture

```
 Apps on Railway ── SASL/SCRAM ──> redpanda:9092  (Kafka API, advertised as redpanda.railway.internal:9092)
 Apps elsewhere ─── SASL/SCRAM ──> [TCP proxy, optional] ──> redpanda:9093 (advertised as the proxy host:port)
 Browser ── HTTPS + Basic auth ──> [console-gateway :8080] ──> [console :8080] ──> redpanda (Kafka 9092, Schema Registry 8081, Admin API 9644)
```

### Advertised listeners (how clients find the broker)

Kafka clients connect to a bootstrap address, then reconnect to the address the broker *advertises* for that listener. Redpanda therefore runs two Kafka listeners:

| Listener | Port | Advertised as | Use |
|---|---|---|---|
| `internal` | 9092 | `${RAILWAY_PRIVATE_DOMAIN}:9092` | Services in the same Railway project/environment (bootstrap `${{redpanda.KAFKA_BOOTSTRAP_SERVERS}}`) |
| `external` | 9093 | `${RAILWAY_TCP_PROXY_DOMAIN}:${RAILWAY_TCP_PROXY_PORT}` if a TCP proxy exists, otherwise the private domain | Clients outside Railway, through a Railway TCP proxy |

The template does **not** create a TCP proxy, so the broker is private by default. To connect from outside Railway: on the `redpanda` service open Settings → Networking → TCP Proxy, target port **9093**, then redeploy the service. Railway then injects `RAILWAY_TCP_PROXY_DOMAIN`/`RAILWAY_TCP_PROXY_PORT`, the start script advertises them on the external listener, and clients bootstrap with `{proxy-domain}:{proxy-port}`. Both listeners require SASL/SCRAM; the TCP proxy does not add TLS, so public traffic is authenticated but not encrypted (see Open questions).

## Services

<!-- BEGIN SERVICES -->

### redpanda

Single-node Redpanda broker in production mode (fsync on, overprovisioned CPU sharing, bounded memory). Kafka API with SASL/SCRAM on 9092 (private) and 9093 (for an optional TCP proxy), Schema Registry on 8081 and HTTP Proxy on 8082 with HTTP Basic auth, Admin API on 9644 with auth. The superuser is created on first start from the variables below.

- Source: repo `baranberkay96/redpanda-railway`, root directory `/services/redpanda` (Dockerfile build)
- Start command: image default
- Pre-deploy command: none
- Healthcheck: `/v1/status/ready` (timeout 300 s)
- Public domain: no (private network only)
- TCP proxy: none
- Volume: `/var/lib/redpanda/data`
- Restart policy: ON_FAILURE (max 10 retries); replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `PORT` | `9644` | Admin API port; /v1/status/ready (unauthenticated) is the healthcheck. |
| `KAFKA_SASL_USERNAME` | `admin` | SASL/SCRAM superuser created on first start (also Schema Registry / HTTP Proxy / Admin API login). |
| `KAFKA_SASL_PASSWORD` | `${{secret(32, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Password of the superuser. Used only when the cluster is created; change it later with rpk (see README). |
| `KAFKA_SASL_MECHANISM` | `SCRAM-SHA-256` | SCRAM-SHA-256 or SCRAM-SHA-512. |
| `KAFKA_BOOTSTRAP_SERVERS` | `${{RAILWAY_PRIVATE_DOMAIN}}:9092` | Bootstrap address for clients on the private network; reference it as ${{redpanda.KAFKA_BOOTSTRAP_SERVERS}}. |
| `SCHEMA_REGISTRY_URL` | `http://${{RAILWAY_PRIVATE_DOMAIN}}:8081` | Schema Registry URL on the private network (HTTP Basic auth with the SASL user). |
| `REDPANDA_SMP` | `1` | CPU cores Redpanda uses (seastar shards). |
| `REDPANDA_MEMORY` | `1G` | Memory Redpanda reserves for itself. Size it to your throughput; the container needs a little more than this. |
| `KAFKA_AUTO_CREATE_TOPICS` | `false` | Create topics automatically on first produce. Applied when the cluster is created. |
| `KAFKA_LOG_RETENTION_MS` | `604800000` | Default topic retention (7 days). Applied when the cluster is created; per-topic retention can be set any time. |
| `REDPANDA_LOG_LEVEL` | `info` | Broker log level. |
| `RAILWAY_DEPLOYMENT_DRAINING_SECONDS` | `60` | Let Redpanda flush and stop cleanly on redeploy. |

### console

Redpanda Console (topics, messages, consumer groups, schemas, ACLs/users via the Admin API). Private: Console's own login is an enterprise feature, so it is published through `console-gateway`.

- Source: image `redpandadata/console:v3.12.0`
- Start command: image default
- Pre-deploy command: none
- Healthcheck: `/admin/health` (timeout 600 s)
- Public domain: no (private network only)
- TCP proxy: none
- Volume: none
- Restart policy: ALWAYS; replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `PORT` | `8080` | Console HTTP port; /admin/health is the healthcheck. |
| `SERVER_LISTENPORT` | `8080` | Console HTTP port. |
| `KAFKA_BROKERS` | `${{redpanda.KAFKA_BOOTSTRAP_SERVERS}}` | Kafka bootstrap server (private network). |
| `KAFKA_SASL_ENABLED` | `true` | Authenticate to Kafka with SASL. |
| `KAFKA_SASL_MECHANISM` | `${{redpanda.KAFKA_SASL_MECHANISM}}` | SCRAM mechanism (reference). |
| `KAFKA_SASL_USERNAME` | `${{redpanda.KAFKA_SASL_USERNAME}}` | SASL user (reference). |
| `KAFKA_SASL_PASSWORD` | `${{redpanda.KAFKA_SASL_PASSWORD}}` | SASL password (reference). |
| `KAFKA_SASL_IMPERSONATEUSER` | `false` | Use the static credentials above (no Console login). |
| `SCHEMAREGISTRY_ENABLED` | `true` | Show schemas and decode Avro/Protobuf messages. |
| `SCHEMAREGISTRY_URLS` | `${{redpanda.SCHEMA_REGISTRY_URL}}` | Schema Registry URL (reference). |
| `SCHEMAREGISTRY_AUTHENTICATION_BASIC_USERNAME` | `${{redpanda.KAFKA_SASL_USERNAME}}` | Schema Registry user (reference). |
| `SCHEMAREGISTRY_AUTHENTICATION_BASIC_PASSWORD` | `${{redpanda.KAFKA_SASL_PASSWORD}}` | Schema Registry password (reference). |
| `SCHEMAREGISTRY_AUTHENTICATION_IMPERSONATEUSER` | `false` | Use the static credentials above. |
| `REDPANDA_ADMINAPI_ENABLED` | `true` | Manage users, ACLs and cluster settings through the Admin API. |
| `REDPANDA_ADMINAPI_URLS` | `http://${{redpanda.RAILWAY_PRIVATE_DOMAIN}}:9644` | Admin API URL (private network). |
| `REDPANDA_ADMINAPI_AUTHENTICATION_BASIC_USERNAME` | `${{redpanda.KAFKA_SASL_USERNAME}}` | Admin API user (reference). |
| `REDPANDA_ADMINAPI_AUTHENTICATION_BASIC_PASSWORD` | `${{redpanda.KAFKA_SASL_PASSWORD}}` | Admin API password (reference). |
| `REDPANDA_ADMINAPI_AUTHENTICATION_IMPERSONATEUSER` | `false` | Use the static credentials above. |

### console-gateway

Caddy with HTTP Basic auth in front of Console; the only public service. The password is hashed with bcrypt at start.

- Source: repo `baranberkay96/redpanda-railway`, root directory `/services/console-gateway` (Dockerfile build)
- Start command: image default
- Pre-deploy command: none
- Healthcheck: `/healthz` (timeout 120 s)
- Public domain: yes, target port `8080`
- TCP proxy: none
- Volume: none
- Restart policy: ALWAYS; replicas: 1; cron: none

| Variable | Value | Description |
|---|---|---|
| `PORT` | `8080` | Gateway port (public domain target); /healthz is unauthenticated. |
| `BASIC_AUTH_USERNAME` | `admin` | Login for Redpanda Console. |
| `BASIC_AUTH_PASSWORD` | `${{secret(24, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")}}` | Password for Redpanda Console. Generated; read it here. |
| `CONSOLE_UPSTREAM` | `${{console.RAILWAY_PRIVATE_DOMAIN}}:8080` | Console on the private network. |

<!-- END SERVICES -->

## Improvements over market templates

1. **Authentication everywhere.** SASL/SCRAM on both Kafka listeners with a generated superuser password; HTTP Basic auth on Schema Registry and HTTP Proxy; Admin API requires auth (`admin_api_require_auth`). Market templates run PLAINTEXT, two of them on a public TCP proxy.
2. **Private by default, public on demand.** No TCP proxy is created; adding one later is picked up automatically on the next deploy (external listener advertisement).
3. **Production mode instead of developer settings:** fsync on (no `dev-container` mode), `auto_create_topics_enabled=false`, bounded memory (`--memory`, `--reserve-memory 0M`) and `--overprovisioned` for shared CPUs.
4. **Persistent volume** for the log segments (two of three market templates have none).
5. **Redpanda Console** for topics, messages, consumer groups, schemas, users and ACLs, behind a Basic-auth gateway (Console's own login is an enterprise feature).
6. **Schema Registry and HTTP Proxy** built into the broker, no extra services.
7. **Pinned versions** instead of `latest`; healthchecks on every service.
8. **Ready-made reference variables** (`KAFKA_BOOTSTRAP_SERVERS`, `SCHEMA_REGISTRY_URL`, `KAFKA_SASL_*`) for wiring other services.

## Resource estimate

Measured locally (idle): broker 0.2 GB, Console 45 MB, gateway 11 MB.

| Service | Idle RAM | Typical RAM | Typical vCPU | Volume |
|---|---|---|---|---|
| redpanda (`REDPANDA_MEMORY=1G`) | 0.2 GB | 1.1 GB | 0.3 | 1–50 GB |
| console | 0.05 GB | 0.15 GB | 0.02 | – |
| console-gateway | 0.01 GB | 0.02 GB | 0.01 | – |
| **Total** | **~0.3 GB** | **~1.3 GB** | **~0.35** | **1–50 GB** |

Railway prices: RAM $10/GB-month, vCPU $20/vCPU-month, volume $0.15/GB-month.

- **Idle:** 0.3 GB × $10 + ~0.03 vCPU × $20 + 1 GB × $0.15 ≈ **$4/month**.
- **Typical (a few MB/s of events, 7-day retention):** 1.3 GB × $10 + 0.35 vCPU × $20 + 20 GB × $0.15 ≈ **$23/month**.
- Raise `REDPANDA_MEMORY` and `REDPANDA_SMP` for higher throughput; disk grows with retention × throughput.

**Minimum plan: Hobby.** Trial's 1 GB per service only fits with `REDPANDA_MEMORY=512M`. Pro for volumes above 5 GB.

## Verification checklist

1. All three services deploy; `redpanda` logs show `railway: starting Redpanda (internal ...:9092, external ...)` and the healthcheck `/v1/status/ready` passes.
2. Open the `console-gateway` domain, log in with `BASIC_AUTH_USERNAME` / `BASIC_AUTH_PASSWORD`: Console lists the cluster, broker 0 and the `_schemas` topic.
3. From another service in the project (or `railway shell` on `redpanda`): `rpk topic create test -X brokers=redpanda.railway.internal:9092 -X user=admin -X pass={password} -X sasl.mechanism=SCRAM-SHA-256`, produce and consume a message; it appears in Console.
4. Without credentials the same command fails with an authentication error.
5. Optional: add a TCP proxy to port 9093, redeploy `redpanda`, run `rpk cluster info` against `{proxy-domain}:{proxy-port}` from your machine; the broker list shows the proxy host and port.
6. Redeploy `redpanda`: topics and messages survive.

## Open questions

- **Not deploy-tested on Railway.** Verified locally (same Dockerfiles, arm64): production-mode start in a container, SASL enforced (no credentials and wrong password rejected), superuser bootstrap, Admin API 403 without auth, Schema Registry 401 without auth, HTTP Proxy with auth, produce/consume on both listeners, external listener advertising a TCP proxy host/port, data surviving a restart, Console reading topics/schemas via env configuration, gateway auth.
- **Async I/O limits:** Redpanda (Seastar) uses Linux AIO. If a Railway host ran short of `fs.aio-max-nr`, start-up would fail; not observed locally. `REDPANDA_SMP=1` keeps the requirement minimal.
- **No TLS on the public listener.** SCRAM never sends the password in clear, but message data over a TCP proxy is unencrypted. Keep sensitive traffic on the private network or terminate TLS yourself.
- **Changing the superuser password** after the first start: `rpk security user update admin --new-password {new} --mechanism SCRAM-SHA-256` (with the old credentials), then update `KAFKA_SASL_PASSWORD` so Console and the gateway keep working. Bootstrap-only settings (`KAFKA_AUTO_CREATE_TOPICS`, `KAFKA_LOG_RETENTION_MS`) are changed later with `rpk cluster config set`.
- **License:** Redpanda and Console are under the Business Source License 1.1, which allows self-hosting for your own use but not offering Redpanda as a "Streaming or Queuing Service" to third parties (the grant explicitly mentions hosting providers). Each user deploys the template into their own account for their own applications; whether a marketplace template with usage kickbacks is affected should be confirmed with counsel or Redpanda.
