# Notice

This is a community template. It is not affiliated with or endorsed by Redpanda Data, Inc.

## Upstream software

| Component | License | Images used |
|---|---|---|
| Redpanda | Redpanda Business Source License 1.1 for the core (Licensor Redpanda Data, Inc.; each version changes to Apache-2.0 four years after its release). Enterprise features are under the Redpanda Community License and need a Redpanda license key; this template enables none of them (SASL/SCRAM, ACLs, Schema Registry and HTTP Proxy are core features). | `redpandadata/redpanda:v26.2.4` |
| Redpanda Console | Business Source License 1.1 for the core, Redpanda Community License for enterprise features (such as login/SSO and RBAC; not enabled). | `redpandadata/console:v3.12.0` |
| Caddy | Apache-2.0 | `caddy:2.11.7-alpine` |

### Business Source License: what it means for this template

The Additional Use Grant in Redpanda's BSL allows production use except for a "Streaming or Queuing Service": a commercial offering that lets third parties (other than your employees and contractors) cause topics to be created in Redpanda, explicitly including hosting and cloud providers that offer Redpanda as part of their service. A user deploying this template into their own Railway account to run their own applications is the self-hosted use the grant is written for. Offering a Redpanda-backed streaming service to your own customers is not covered and needs a commercial license from Redpanda.

Whether publishing this template on a marketplace that pays the template author a share of usage is affected has not been confirmed. Get legal advice, or ask Redpanda Data, before publishing. This section is a summary, not legal advice; the license text in the Redpanda repository (`licenses/bsl.md`, `licenses/rcl.md`) governs.

## Verified against

| What | Source | Version / ref | Checked |
|---|---|---|---|
| Image tags and release dates | Docker Hub `redpandadata/redpanda` (`v26.2.4`, pushed 2026-10-06, current `latest`; the GitHub releases page still lists v26.2.2 as latest) and `redpandadata/console`; https://github.com/redpanda-data/console/releases (v3.12.0, 2026-09-16) | v26.2.4, v3.12.0 | 2026-10-11 |
| Node configuration (`redpanda.yaml` listeners, advertised addresses, `authentication_method`, `rpk` section) | https://docs.redpanda.com/current/reference/properties/broker-properties/ and https://docs.redpanda.com/current/manage/security/authentication/ | current docs | 2026-10-11 |
| First-boot cluster properties (`.bootstrap.yaml`) and superuser bootstrap (`RP_BOOTSTRAP_USER`) | https://docs.redpanda.com/current/deploy/redpanda/manual/production/production-deployment/ and the `rpk` sources in https://github.com/redpanda-data/redpanda (`src/go/rpk`) | v26.2.4 | 2026-10-11 |
| `rpk redpanda start` flags (`--smp`, `--memory`, `--reserve-memory`, `--overprovisioned`) | https://docs.redpanda.com/current/reference/rpk/rpk-redpanda/rpk-redpanda-start/ | current docs | 2026-10-11 |
| Console environment configuration (`KAFKA_*`, `SCHEMAREGISTRY_*`, `REDPANDA_ADMINAPI_*`) | https://docs.redpanda.com/current/console/config/configure-console/ | Console v3 | 2026-10-11 |
| Licenses | https://github.com/redpanda-data/redpanda/tree/dev/licenses and https://github.com/redpanda-data/console/tree/master/licenses | dev / master | 2026-10-11 |
| Railway TCP proxy variables (`RAILWAY_TCP_PROXY_DOMAIN`, `RAILWAY_TCP_PROXY_PORT`) | https://docs.railway.com/networking/tcp-proxy | docs | 2026-10-11 |

## Adapted code

None. `services/redpanda/railway-redpanda.sh`, `services/console-gateway/Caddyfile` and `entrypoint.sh` were written for this template from the Redpanda and Caddy documentation.

## Reference only (not copied)

- Railway marketplace templates `K5vWpm` (Kafka + ZooKeeper, from `oussamajabnouni/railway-kafka`, no license), `NyB5Jd` and `kafka` (Apache Kafka KRaft): read for the private-domain / TCP-proxy advertised-listener pattern. No files or text copied.

## Trademarks

Redpanda is a trademark of Redpanda Data, Inc. Kafka and Apache Kafka are trademarks of The Apache Software Foundation. Caddy belongs to its respective owner.
