# Deploy and Host Redpanda with Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/redpanda-v26-kafka-compatible-streaming?referralCode=20H68q)

Redpanda is a Kafka API-compatible streaming platform written in C++, with no ZooKeeper and no JVM. This community template deploys a single Redpanda broker with SASL authentication, a persistent volume, the built-in Schema Registry and HTTP Proxy, and Redpanda Console behind a password-protected HTTPS domain.

## About Hosting Redpanda

Redpanda runs as one binary that already includes the Kafka API, a Schema Registry and an HTTP Proxy, so a single service replaces Kafka, ZooKeeper or KRaft controllers and a separate registry. Hosting it well means persistent storage, authentication, memory limits that fit a shared container, and listeners that advertise addresses clients can actually reach. This template runs Redpanda in production mode with SASL/SCRAM on every Kafka listener, keeps the broker on Railway's private network by default, and is ready for an optional TCP proxy when clients outside Railway need access. Redpanda Console gives you a web UI for topics, messages, consumer groups, schemas, users and ACLs.

## Common Use Cases

- Event streaming and messaging between services in the same Railway project, using any Kafka client library.
- Change data capture and event sourcing pipelines with Schema Registry-managed Avro, Protobuf or JSON schemas.
- Background job and log ingestion queues that need replay and retention instead of fire-and-forget delivery.
- A lightweight Kafka-compatible broker for staging environments, prototypes and small production workloads.
- Inspecting and debugging topics and consumer lag through Redpanda Console.

## Dependencies for Redpanda Hosting

- Redpanda `v26.2.4` (`redpandadata/redpanda`), with Schema Registry and HTTP Proxy built in
- Redpanda Console `v3.12.0` (`redpandadata/console`)
- Caddy `2.11.7` (Basic-auth gateway in front of Console)
- A Railway volume for the broker's data

### Deployment Dependencies

- Redpanda documentation: https://docs.redpanda.com/current/home/
- Redpanda configuration properties: https://docs.redpanda.com/current/reference/properties/
- SASL/SCRAM authentication: https://docs.redpanda.com/current/manage/security/authentication/
- Redpanda Console configuration: https://docs.redpanda.com/current/console/config/configure-console/
- Redpanda source and licenses: https://github.com/redpanda-data/redpanda
- Railway TCP proxy: https://docs.railway.com/networking/tcp-proxy

### Implementation Details

| Service | Role | Public | Storage |
|---|---|---|---|
| redpanda | Broker: Kafka API 9092 (private) and 9093 (for a TCP proxy), Schema Registry 8081, HTTP Proxy 8082, Admin API 9644 | No (optional TCP proxy) | Volume |
| console | Redpanda Console web UI | No | – |
| console-gateway | Caddy with HTTP Basic auth; the only public HTTPS endpoint | Yes | – |

**First login**

1. Deploy the template. No input is required; all passwords are generated.
2. Open the `console-gateway` public domain and log in with `BASIC_AUTH_USERNAME` and `BASIC_AUTH_PASSWORD` from the `console-gateway` variables.
3. Create a topic in Console (automatic topic creation is off by default).

**Connecting services in the same project**

Add these variables to your app service:

- `KAFKA_BROKERS` = `${{redpanda.KAFKA_BOOTSTRAP_SERVERS}}`
- `KAFKA_SASL_MECHANISM` = `${{redpanda.KAFKA_SASL_MECHANISM}}` (SCRAM-SHA-256)
- `KAFKA_SASL_USERNAME` = `${{redpanda.KAFKA_SASL_USERNAME}}`
- `KAFKA_SASL_PASSWORD` = `${{redpanda.KAFKA_SASL_PASSWORD}}`
- `SCHEMA_REGISTRY_URL` = `${{redpanda.SCHEMA_REGISTRY_URL}}` (HTTP Basic auth with the same user)

Use security protocol `SASL_PLAINTEXT`; traffic stays on Railway's private network. For least privilege, create a separate user per application (`rpk security user create {app-user} -p {app-password} --mechanism SCRAM-SHA-256` in the `redpanda` service shell) and grant it ACLs with `rpk security acl create` instead of sharing the superuser.

**Connecting from outside Railway (optional)**

1. On the `redpanda` service open Settings, Networking, TCP Proxy and set the target port to `9093`.
2. Redeploy `redpanda`. The broker then advertises `{proxy-domain}:{proxy-port}` on its external listener.
3. Bootstrap your client with `{proxy-domain}:{proxy-port}`, security protocol `SASL_PLAINTEXT` and the SCRAM credentials above.

SCRAM never sends the password itself, but the TCP proxy does not add TLS, so message data travels unencrypted. Keep sensitive traffic on the private network.

**Settings worth knowing**

- `REDPANDA_MEMORY` (default `1G`) and `REDPANDA_SMP` (default `1` core) size the broker; the container uses slightly more than `REDPANDA_MEMORY`.
- `KAFKA_AUTO_CREATE_TOPICS` and `KAFKA_LOG_RETENTION_MS` (7 days) apply when the cluster is first created. Change them later with `rpk cluster config set auto_create_topics_enabled true` or per topic in Console.
- `KAFKA_SASL_PASSWORD` is used only on first start. To rotate it, run `rpk security user update admin --new-password {new-password} --mechanism SCRAM-SHA-256` in the `redpanda` service shell, then update the variable so Console keeps working.

**Scaling:** this is a single-node cluster (replication factor 1). Scale vertically by raising `REDPANDA_MEMORY`, `REDPANDA_SMP` and the service's resource limits; the volume can grow as retention and throughput require. Multi-broker clusters need stable per-broker addresses and are outside the scope of this template.

**Pinning and upgrades:** Redpanda is pinned in `services/redpanda/Dockerfile` and Console in the `console` service image tag. To upgrade, change the tags to a newer release, read the Redpanda upgrade notes for your version jump, and redeploy; data stays on the volume.

**Resources:** about 0.3 GB RAM idle (around $4/month with a small volume); a few MB/s of events with 7-day retention typically uses about 1.3 GB RAM and 20 GB of disk (around $23/month). Hobby plan works; Pro for volumes larger than 5 GB.

### Why Deploy Redpanda on Railway?

Railway gives Redpanda a persistent volume, private networking to your other services, generated credentials and an HTTPS domain for Console, all in one project with usage-based billing. You get an authenticated Kafka-compatible broker and its management UI running next to your apps without operating servers or a JVM-based cluster.
