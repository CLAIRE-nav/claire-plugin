---
name: MULTI_REPO
description: "JSF multi-repo interactions — how jsf_service, jsf_gateway, jsf_web, jsf_deployment interconnect"
type: technical
keywords: [multi-repo, monorepo, dependencies, api, contracts, jsf_service, jsf_gateway, jsf_web, jsf_deployment, navair]
updated: 2026-04-10
---

# JSF Multi-Repo Interaction Map

The 4 JSF repositories have distinct responsibilities and well-defined integration points.
This document describes how they interact at runtime, build time, and during deployment.

---

## Runtime Request Flow

```
Browser / Client
     │
     ▼
jsf_web (Vue 3 / nginx)
     │  HTTPS to VITE_API_URL
     ▼
jsf_gateway (Spring Cloud Gateway :8090)
     │  JWT validation + routing
     │  internal HTTP to :8080/api/v1/**
     ▼
jsf_service (Spring Boot :8080)
     │
     ├──── Oracle 19c (JPA / Flyway)
     │
     └──── IBM MQ (async events)
```

### Key integration rules

1. **jsf_web → jsf_gateway only** — the frontend never calls `jsf_service` directly.
2. **jsf_gateway → jsf_service only** — gateway routes to `jsf_service`; it has no business logic.
3. **jsf_service owns the database** — `jsf_gateway` never writes to Oracle directly.
4. **Events via MQ** — inter-service async communication uses IBM MQ, not REST callbacks.

---

## Build-Time Dependencies

### Shared DTO Contract Artifact

`jsf_service` publishes `jsf-api-contracts-{version}.jar` to Nexus after every CI build.
`jsf_gateway` imports this artifact to share request/response DTOs.

```
jsf_service ──(mvn deploy)──▶ Nexus jsf-api-contracts
                                     │
jsf_gateway ──(mvn dependency:get)───┘
```

**Consequence:** `jsf_gateway` cannot build until `jsf_service` CI has published the latest artifact.
If `jsf_gateway` CI fails with "artifact not found", run `jsf-ci-service` pipeline first.

### jsf_web — No Java dependency

`jsf_web` is a pure JavaScript build. It only needs:
- The OpenAPI spec from `jsf_gateway` (documented, not auto-imported)
- The `VITE_API_URL` env var pointing to the gateway

When the gateway API changes:
1. Update OpenAPI spec (`jsf_gateway/docs/openapi.yaml`)
2. Review `jsf_web/src/api/` — update Axios call parameters if needed
3. Always test the full flow locally before creating a PR

---

## Cross-Repo Change Protocol

### Backend-only change (jsf_service)
1. Develop + test in `jsf_service`
2. If API contract changed → update `jsf-api-contracts` version in `pom.xml`
3. PR to `jsf_service` → CI publishes artifact
4. PR to `jsf_gateway` → bump contract version, update routes if new endpoints
5. Deployment team updates `jsf_deployment` Jenkinsfile if env vars changed

### Frontend-only change (jsf_web)
1. Develop + test in `jsf_web` using `VITE_API_URL` pointing to local gateway
2. PR to `jsf_web`
3. CI builds and tests → deploy dev

### Gateway config change (jsf_gateway)
- Routing changes, security rules, CORS — PR to `jsf_gateway` only
- Does NOT require `jsf_service` or `jsf_web` PRs (unless API contract changed)

### Infrastructure change (jsf_deployment)
- Jenkinsfile changes, Ansible playbook changes, env var additions
- PR to `jsf_deployment`
- Requires deployment team review (separate CODEOWNERS)

---

## Environment Variable Propagation

Variables flow from Jenkins → Ansible → Docker Compose → Spring Boot JVM args:

```
Jenkins Credentials
      │  withCredentials([])
      ▼
Ansible inventory vars
      │  template: application.yml.j2
      ▼
application.yml (on target host)
      │  spring.config.location
      ▼
Spring Boot process
```

New environment variables must be added at ALL layers:
1. Jenkins Credentials Store
2. Ansible role vars (`jsf_deployment/ansible/group_vars/`)
3. Ansible template (`*.yml.j2`)
4. Spring Boot `application.yml`
5. Update `ENVIRONMENT.md` in this plugin

---

## Database Schema Ownership

`jsf_service` owns and migrates the Oracle schema via Flyway.

- Migrations: `jsf_service/src/main/resources/db/migration/`
- Convention: `V{version}__{description}.sql`
- On service start: Flyway auto-applies pending migrations

**jsf_gateway never touches Oracle directly.**

If a schema migration breaks `jsf_gateway` (e.g., a DTO field changed), the fix sequence is:
1. Fix migration in `jsf_service`
2. Update `jsf-api-contracts` artifact
3. Update `jsf_gateway` to use new contract version
4. Deploy service first, gateway second

---

## MQ Message Contracts

IBM MQ queues are owned by `jsf_service`. External consumers read from:

| Queue | Message format | When published |
|-------|----------------|----------------|
| `JSF.SERVICE.EVENTS` | JSON — `ServiceEvent` type | After any significant state change |
| `JSF.DLQ` | Original message + error | Failed processing |

Message schema is in `jsf-api-contracts`:
```java
// mil.navair.jsf.contracts.ServiceEvent
public record ServiceEvent(
    String eventType,
    String entityId,
    Instant timestamp,
    Map<String, Object> payload
) {}
```

---

## Branching Convention

All 4 repos follow the same convention:

```
main                — stable, auto-deploys to dev
issue-{N}           — feature/fix branch (one per GitHub issue)
release/{version}   — release candidate
hotfix/{N}          — emergency fix from main
```

Cross-repo changes that must land together:
1. Open linked issues in both repos
2. Create `issue-{N}` branch in each
3. PRs reference each other ("Depends on CLAIRE-nav/jsf_gateway#42")
4. Merge in dependency order: service → gateway → web → deployment

---

## CODEOWNERS

| File pattern | Owner |
|-------------|-------|
| `jsf_service/**` | `@navair-backend` |
| `jsf_gateway/**` | `@navair-backend` |
| `jsf_web/**` | `@navair-frontend` |
| `jsf_deployment/**` | `@navair-devops` |
| `jsf_service/src/main/resources/db/migration/**` | `@navair-dba @navair-backend` |
