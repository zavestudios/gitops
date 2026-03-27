# Keycloak Recovery Notes

Status: recovered

## Summary

Keycloak is now healthy in-cluster and running from the prebuilt GHCR image pinned
by immutable digest.

This note captures the recovery sequence, the manual actions that were required,
and the durable fixes that were pushed into the owning repositories.

## Root Cause Chain

Recovery crossed multiple blockers in sequence:

1. Upstream Keycloak image startup failed with Quarkus runtime rebuild errors on a
   read-only filesystem.
2. The Keycloak Helm release also failed on a missing governing headless Service.
3. The cluster could not pull the custom GHCR image because the expected
   `private-registry` image pull secret did not exist in the `keycloak` namespace.
4. Mutable tag reuse caused the cluster to continue starting an older image until
   GitOps pinned Keycloak to an immutable digest.
5. The shared PostgreSQL VM `pg-01` was shut off, so the configured database host
   was unreachable.
6. After PostgreSQL was reachable, the `keycloak_app` role lacked `CREATE` on the
   `app` schema, causing Liquibase to fail.
7. After schema permissions were fixed, the `keycloak_app` role hit its connection
   limit during startup retries.

## Repo Changes

### `gitops`

- switched Keycloak to external PostgreSQL using chart-supported values
- disabled embedded PostgreSQL
- precreated the `keycloak-keycloak-headless` Service
- added `private-registry` ExternalSecret in `keycloak` from Vault path
  `platform/ghcr`
- switched Keycloak to the prebuilt GHCR image and pinned it by immutable digest

### `image-factory`

- added Keycloak build and promote workflows
- built a pre-optimized Keycloak image for the Big Bang deployment
- baked required build-time settings into the image:
  - `KC_DB=postgres`
  - `KC_HEALTH_ENABLED=true`
  - `KC_METRICS_ENABLED=true`
  - `KC_HTTP_RELATIVE_PATH=/auth`
  - `KC_HTTPS_CLIENT_AUTH=request`

### `pg`

- tenant provisioning now grants `USAGE, CREATE` on the application schema to the
  tenant role
- provisioning docs now call out Keycloak as a `--connection-limit 50` case

### `kubernetes-platform-infrastructure`

- `pg-01` and `redis-01` are now declared with `autostart = true`

## Manual Actions Taken

The following actions were required during recovery and should be treated as
incident history, not desired steady state:

- targeted Terraform apply in KPI to start and enable autostart for `pg-01` and
  `redis-01`
- manual PostgreSQL grant:
  - `GRANT USAGE, CREATE ON SCHEMA app TO keycloak_app;`
- manual PostgreSQL role tuning:
  - `ALTER ROLE keycloak_app CONNECTION LIMIT 50;`
- repeated manual reconciles of `helmrelease/bigbang` and `helmrelease/keycloak`

## Remaining Operational Follow-Up

- create public edge exposure for `sso.zavestudios.com`
- keep Keycloak itself outside Cloudflare Access so it can act as the platform IdP
- verify `pg-01` and `redis-01` come back automatically after the next hypervisor
  reboot
